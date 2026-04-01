import Foundation
import UIKit

@MainActor
final class TinyKeysViewModel: ObservableObject {
    let keyboardLayout = PianoKeyboardLayout()
    let audioSessionManager: AudioSessionManager
    let orientationController = OrientationController.shared

    @Published private(set) var visibleSpan: VisibleKeySpan = .oneAndHalf
    @Published private(set) var visibleWhiteStart: CGFloat
    @Published private(set) var volume: Double = 0.8
    @Published private(set) var selectedSound: SoundPreset = .piano
    @Published private(set) var concertAFrequency: Double = 440
    @Published private(set) var pitchOffsetCents: Double = 0
    @Published private(set) var tuningSelection: TuningSelection
    @Published private(set) var savedCustomTunings: [SavedCustomTuning] = []
    @Published private(set) var isDroneModeEnabled: Bool
    @Published private(set) var keyboardOrientation: KeyboardOrientationMode
    @Published private(set) var latchedDroneNotes: [Int] = []
    @Published private(set) var settingsNavigationPath: [SettingsNavigationDestination] = []
    @Published var isSettingsPresented = false

    private let synthEngine: SynthEngine
    private let tuningPresetStore = TuningPresetStore()
    private let defaults = UserDefaults.standard
    private let keyboardOrientationKey = "tinykeys.keyboardOrientation"
    private let droneModeEnabledKey = "tinykeys.droneModeEnabled"
    private let concertAFrequencyKey = "tinykeys.concertAFrequency"
    private let tuningSelectionDataKey = "tinykeys.tuningSelectionData"
    private let temperamentKey = "tinykeys.temperament"
    private let tuningKeyCenterKey = "tinykeys.tuningKeyCenter"
    private var hasStoredKeyboardOrientation = false
    @Published private(set) var clearDronesGeneration = 0

    init() {
        let synthEngine = SynthEngine()
        let defaults = UserDefaults.standard
        let tuningPresetStore = TuningPresetStore()
        let savedCustomTunings = tuningPresetStore.load().sorted(by: Self.savedTuningSort)
        let storedTemperament = defaults.string(forKey: temperamentKey).flatMap(TemperamentPreset.init(rawValue:)) ?? .equal
        let storedKeyCenter = defaults.object(forKey: tuningKeyCenterKey)
            .flatMap { $0 as? Int }
            .flatMap(PitchClass.init(rawValue:)) ?? .c
        var initialTuningSelection: TuningSelection

        if
            let data = defaults.data(forKey: tuningSelectionDataKey),
            let decodedSelection = try? JSONDecoder().decode(TuningSelection.self, from: data)
        {
            initialTuningSelection = decodedSelection
        } else {
            initialTuningSelection = TuningSelection(temperament: storedTemperament, keyCenter: storedKeyCenter)
        }
        initialTuningSelection.customOffsetsCents = initialTuningSelection.normalizedCustomOffsetsCents
        if let selectedID = initialTuningSelection.selectedCustomTuningID,
           let savedTuning = savedCustomTunings.first(where: { $0.id == selectedID }),
           initialTuningSelection.customName == nil {
            initialTuningSelection.customName = savedTuning.name
        }

        let selectedSound: SoundPreset = initialTuningSelection.supportsPiano ? .piano : .sine
        let isDroneModeEnabled = defaults.bool(forKey: droneModeEnabledKey)
        let concertAFrequency = Self.clampedConcertAFrequency(defaults.object(forKey: concertAFrequencyKey) as? Double ?? 440)
        let initialKeyboardOrientation: KeyboardOrientationMode

        if let storedOrientation = defaults.string(forKey: keyboardOrientationKey).flatMap(KeyboardOrientationMode.init(rawValue:)) {
            initialKeyboardOrientation = storedOrientation
        } else {
            initialKeyboardOrientation = .landscapeRight
            defaults.set(KeyboardOrientationMode.landscapeRight.rawValue, forKey: keyboardOrientationKey)
        }

        let audioSessionManager = AudioSessionManager {
            synthEngine.ensureRunning()
        }

        self.synthEngine = synthEngine
        self.audioSessionManager = audioSessionManager
        self.visibleWhiteStart = PianoKeyboardLayout().defaultVisibleStart(for: .oneAndHalf)
        self.savedCustomTunings = savedCustomTunings
        self.tuningSelection = initialTuningSelection
        self.selectedSound = selectedSound
        self.concertAFrequency = concertAFrequency
        self.isDroneModeEnabled = isDroneModeEnabled
        self.keyboardOrientation = initialKeyboardOrientation
        self.hasStoredKeyboardOrientation = true

        audioSessionManager.configureForMixingPlayback()
        synthEngine.start()
        synthEngine.setVolume(Float(volume))
        synthEngine.setPreset(selectedSound)
        synthEngine.setGlobalTuningCents(Float(Self.totalGlobalTuningCents(concertAFrequency: concertAFrequency, pitchOffsetCents: 0)))
        synthEngine.setPitchClassOffsets(TuningEngine(selection: initialTuningSelection).pitchClassOffsetsCents())
        persistTuningSelection()
    }

    func activateAudioIfNeeded() {
        audioSessionManager.configureForMixingPlayback()
        synthEngine.ensureRunning()
        orientationController.applyCurrentOrientation()
    }

    func noteOn(token: Int, midiNote: Int) {
        synthEngine.noteOn(token: token, midiNote: midiNote)
    }

    func noteOff(token: Int) {
        synthEngine.noteOff(token: token)
    }

    func stopAllNotes() {
        synthEngine.stopAllNotes()
        clearDrones()
    }

    func updateVisibleStart(_ start: CGFloat) {
        visibleWhiteStart = keyboardLayout.clampVisibleStart(start, visibleWhiteCount: visibleSpan.whiteKeyCount)
    }

    func updateVisibleSpan(_ span: VisibleKeySpan) {
        let oldVisibleCount = visibleSpan.whiteKeyCount
        let center = visibleWhiteStart + (oldVisibleCount / 2)
        visibleSpan = span
        let proposedStart = center - (span.whiteKeyCount / 2)
        visibleWhiteStart = keyboardLayout.clampVisibleStart(proposedStart, visibleWhiteCount: span.whiteKeyCount)
    }

    func updateVolume(_ volume: Double) {
        self.volume = min(max(volume, 0), 1)
        synthEngine.setVolume(Float(self.volume))
    }

    func updateSound(_ sound: SoundPreset) {
        let resolvedSound = sound == .piano && !isPianoAvailableForCurrentTuning ? .sine : sound
        guard selectedSound != resolvedSound else {
            return
        }

        selectedSound = resolvedSound
        synthEngine.setPreset(resolvedSound)
        clearDrones()
    }

    func updateConcertAFrequency(_ frequency: Double) {
        let clamped = Self.clampedConcertAFrequency(frequency)
        guard concertAFrequency != clamped else {
            return
        }

        concertAFrequency = clamped
        defaults.set(clamped, forKey: concertAFrequencyKey)
        applyGlobalTuning()
    }

    func resetConcertAFrequency() {
        updateConcertAFrequency(440)
    }

    func updatePitchOffsetCents(_ cents: Double) {
        let clamped = min(max(cents, -50), 50).rounded()
        guard pitchOffsetCents != clamped else {
            return
        }

        pitchOffsetCents = clamped
        applyGlobalTuning()
    }

    func resetPitchOffset() {
        updatePitchOffsetCents(0)
    }

    func updateDroneModeEnabled(_ isEnabled: Bool) {
        guard isDroneModeEnabled != isEnabled else {
            return
        }

        isDroneModeEnabled = isEnabled
        defaults.set(isEnabled, forKey: droneModeEnabledKey)
    }

    func presentSettings() {
        settingsNavigationPath = []
        isSettingsPresented = true
    }

    func presentTuningSettings() {
        settingsNavigationPath = [.tuning]
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    func updateSettingsNavigationPath(_ path: [SettingsNavigationDestination]) {
        settingsNavigationPath = path
    }

    func startCustomTuningFromCurrentSelection() {
        guard tuningSelection.temperament != .custom else {
            return
        }

        let sourceTemperament = tuningSelection.temperament
        tuningSelection.temperament = .custom
        tuningSelection.customOffsetsCents = sourceTemperament.tonicRelativeOffsetsCents
        tuningSelection.selectedCustomTuningID = nil
        tuningSelection.customName = nil
        applyTuningSelection()
    }

    func updateTemperament(_ temperament: TemperamentPreset) {
        guard tuningSelection.temperament != temperament else {
            return
        }

        tuningSelection.temperament = temperament
        applyTuningSelection()
    }

    func updateTuningKeyCenter(_ keyCenter: PitchClass) {
        guard tuningSelection.keyCenter != keyCenter else {
            return
        }

        tuningSelection.keyCenter = keyCenter
        applyTuningSelection()
    }

    func customOffset(for degree: Int) -> Double {
        guard (0..<12).contains(degree) else {
            return 0
        }

        return tuningSelection.normalizedCustomOffsetsCents[degree]
    }

    func updateCustomOffset(_ cents: Double, at degree: Int) {
        guard (0..<12).contains(degree) else {
            return
        }

        let clamped = min(max(cents, -100), 100)
        let rounded = (clamped * 10).rounded() / 10
        var offsets = tuningSelection.normalizedCustomOffsetsCents

        guard offsets[degree] != rounded else {
            return
        }

        offsets[degree] = rounded
        tuningSelection.temperament = .custom
        tuningSelection.customOffsetsCents = offsets
        applyTuningSelection()
    }

    func nudgeCustomOffset(at degree: Int, by delta: Double) {
        updateCustomOffset(customOffset(for: degree) + delta, at: degree)
    }

    func resetCustomOffsetsToEqual() {
        tuningSelection.temperament = .custom
        tuningSelection.customOffsetsCents = Array(repeating: 0, count: 12)
        applyTuningSelection()
    }

    func applySavedCustomTuning(_ preset: SavedCustomTuning) {
        tuningSelection.temperament = .custom
        tuningSelection.keyCenter = preset.keyCenter
        tuningSelection.customOffsetsCents = preset.offsetsCents
        tuningSelection.selectedCustomTuningID = preset.id
        tuningSelection.customName = preset.name
        applyTuningSelection()
    }

    func saveCurrentCustomTuning(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        tuningSelection.temperament = .custom
        let preset = SavedCustomTuning(
            name: trimmedName,
            keyCenter: tuningSelection.keyCenter,
            offsetsCents: tuningSelection.normalizedCustomOffsetsCents
        )

        savedCustomTunings.append(preset)
        savedCustomTunings.sort(by: Self.savedTuningSort)
        tuningSelection.selectedCustomTuningID = preset.id
        tuningSelection.customName = preset.name
        persistSavedCustomTunings()
        persistTuningSelection()
    }

    func updateCurrentCustomTuning() {
        guard let selectedID = tuningSelection.selectedCustomTuningID,
              let index = savedCustomTunings.firstIndex(where: { $0.id == selectedID }) else {
            return
        }

        let existing = savedCustomTunings[index]
        let updated = SavedCustomTuning(
            id: existing.id,
            name: tuningSelection.customName ?? existing.name,
            keyCenter: tuningSelection.keyCenter,
            offsetsCents: tuningSelection.normalizedCustomOffsetsCents,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )

        savedCustomTunings[index] = updated
        savedCustomTunings.sort(by: Self.savedTuningSort)
        tuningSelection.customName = updated.name
        persistSavedCustomTunings()
        persistTuningSelection()
    }

    func renameCustomTuning(id: UUID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = savedCustomTunings.firstIndex(where: { $0.id == id }) else {
            return
        }

        let existing = savedCustomTunings[index]
        let updated = SavedCustomTuning(
            id: existing.id,
            name: trimmedName,
            keyCenter: existing.keyCenter,
            offsetsCents: existing.offsetsCents,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )

        savedCustomTunings[index] = updated
        savedCustomTunings.sort(by: Self.savedTuningSort)

        if tuningSelection.selectedCustomTuningID == id {
            tuningSelection.customName = trimmedName
            persistTuningSelection()
        }

        persistSavedCustomTunings()
    }

    func duplicateCustomTuning(id: UUID, named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let existing = savedCustomTunings.first(where: { $0.id == id }) else {
            return
        }

        let duplicated = SavedCustomTuning(
            name: trimmedName,
            keyCenter: existing.keyCenter,
            offsetsCents: existing.offsetsCents
        )

        savedCustomTunings.append(duplicated)
        savedCustomTunings.sort(by: Self.savedTuningSort)
        persistSavedCustomTunings()
    }

    func deleteCustomTuning(id: UUID) {
        savedCustomTunings.removeAll { $0.id == id }

        if tuningSelection.selectedCustomTuningID == id {
            tuningSelection.selectedCustomTuningID = nil
            tuningSelection.customName = nil
            persistTuningSelection()
        }

        persistSavedCustomTunings()
    }

    func updateLatchedDroneNotes(_ midiNotes: [Int]) {
        let sortedNotes = midiNotes.sorted()
        guard latchedDroneNotes != sortedNotes else {
            return
        }

        latchedDroneNotes = sortedNotes
    }

    func clearDrones() {
        clearDronesGeneration += 1
        latchedDroneNotes = []
    }

    func updateAppOrientation(_ orientation: AppOrientationMode) {
        orientationController.updateAppOrientation(orientation)
    }

    func updateKeyboardOrientation(_ orientation: KeyboardOrientationMode) {
        guard keyboardOrientation != orientation else {
            return
        }

        keyboardOrientation = orientation
        hasStoredKeyboardOrientation = true
        defaults.set(orientation.rawValue, forKey: keyboardOrientationKey)
    }

    func updateInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        orientationController.updateCurrentInterfaceOrientation(orientation)
    }

    var pitchOffsetDisplayText: String {
        let rounded = Int(pitchOffsetCents.rounded())
        if rounded > 0 {
            return String(format: "+%d¢", rounded)
        } else if rounded < 0 {
            return String(format: "%d¢", rounded)
        } else {
            return "0¢"
        }
    }

    var concertAFrequencyDisplayText: String {
        String(format: "A%.1f", concertAFrequency)
    }

    var hasPitchOffset: Bool {
        abs(pitchOffsetCents) >= 0.5
    }

    var hasConcertAFrequencyOffset: Bool {
        abs(concertAFrequency - 440) >= 0.05
    }

    var hasLatchedDrones: Bool {
        !latchedDroneNotes.isEmpty
    }

    var hasNonEqualTemperament: Bool {
        tuningSelection.hasUnequalTemperament
    }

    var isCustomTuningSelected: Bool {
        tuningSelection.isCustom
    }

    var isPianoAvailableForCurrentTuning: Bool {
        tuningSelection.supportsPiano
    }

    var availableSoundPresets: [SoundPreset] {
        if isPianoAvailableForCurrentTuning {
            return SoundPreset.allCases
        }

        return SoundPreset.allCases.filter { $0 != .piano }
    }

    var tuningSummaryText: String {
        tuningSelection.title
    }

    var shouldShowTuningOverlay: Bool {
        hasNonEqualTemperament
    }

    var selectedSavedCustomTuning: SavedCustomTuning? {
        guard let selectedID = tuningSelection.selectedCustomTuningID else {
            return nil
        }

        return savedCustomTunings.first(where: { $0.id == selectedID })
    }

    var hasSavedCustomTunings: Bool {
        !savedCustomTunings.isEmpty
    }

    var canUpdateSelectedCustomTuning: Bool {
        selectedSavedCustomTuning != nil
    }

    var isSelectedCustomTuningModified: Bool {
        guard let selectedPreset = selectedSavedCustomTuning else {
            return false
        }

        return selectedPreset.keyCenter != tuningSelection.keyCenter
            || selectedPreset.offsetsCents != tuningSelection.normalizedCustomOffsetsCents
    }

    var customTuningStatusText: String {
        guard tuningSelection.temperament == .custom else {
            return "Copy any built-in temperament into an editable 12-note custom tuning."
        }

        if let selectedPreset = selectedSavedCustomTuning {
            if isSelectedCustomTuningModified {
                return "Editing \(selectedPreset.name) with unsaved changes."
            }

            return "Loaded from \(selectedPreset.name)."
        }

        return "Unsaved custom tuning stored only in the current session until you save it."
    }

    var suggestedCustomTuningName: String {
        if let customName = tuningSelection.customName, !customName.isEmpty {
            return customName
        }

        if tuningSelection.temperament == .custom {
            return "Custom · \(tuningSelection.keyCenter.title)"
        }

        return "\(tuningSelection.temperament.title) · \(tuningSelection.keyCenter.title)"
    }

    var customEditorPitchClasses: [PitchClass] {
        PitchClass.orderedStarting(at: tuningSelection.keyCenter)
    }

    private func applyTuningSelection() {
        clearDronesForRetune()
        let offsets = TuningEngine(selection: tuningSelection).pitchClassOffsetsCents()
        synthEngine.setPitchClassOffsets(offsets)

        if !isPianoAvailableForCurrentTuning, selectedSound == .piano {
            updateSound(.sine)
        }

        defaults.set(tuningSelection.temperament.rawValue, forKey: temperamentKey)
        defaults.set(tuningSelection.keyCenter.rawValue, forKey: tuningKeyCenterKey)
        persistTuningSelection()
    }

    private func applyGlobalTuning() {
        clearDronesForRetune()
        let totalCents = Self.totalGlobalTuningCents(
            concertAFrequency: concertAFrequency,
            pitchOffsetCents: pitchOffsetCents
        )
        synthEngine.setGlobalTuningCents(Float(totalCents))
    }

    private func clearDronesForRetune() {
        guard hasLatchedDrones else {
            return
        }

        clearDrones()
    }

    private func persistSavedCustomTunings() {
        do {
            try tuningPresetStore.save(savedCustomTunings)
        } catch {
            assertionFailure("Failed to save custom tunings: \(error)")
        }
    }

    private func persistTuningSelection() {
        if let data = try? JSONEncoder().encode(tuningSelection) {
            defaults.set(data, forKey: tuningSelectionDataKey)
        }
    }

    private static func savedTuningSort(lhs: SavedCustomTuning, rhs: SavedCustomTuning) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func clampedConcertAFrequency(_ frequency: Double) -> Double {
        let clamped = min(max(frequency, 392), 460)
        return (clamped * 10).rounded() / 10
    }

    private static func totalGlobalTuningCents(concertAFrequency: Double, pitchOffsetCents: Double) -> Double {
        (1200 * log2(concertAFrequency / 440)) + pitchOffsetCents
    }
}
