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
    @Published private(set) var pitchOffsetCents: Double = 0
    @Published private(set) var isDroneModeEnabled: Bool
    @Published private(set) var keyboardOrientation: KeyboardOrientationMode
    @Published private(set) var latchedDroneNotes: [Int] = []
    @Published var isSettingsPresented = false

    private let synthEngine: SynthEngine
    private let defaults = UserDefaults.standard
    private let keyboardOrientationKey = "tinykeys.keyboardOrientation"
    private let droneModeEnabledKey = "tinykeys.droneModeEnabled"
    private var hasStoredKeyboardOrientation = false
    @Published private(set) var clearDronesGeneration = 0

    init() {
        let synthEngine = SynthEngine()
        self.synthEngine = synthEngine
        self.visibleWhiteStart = keyboardLayout.defaultVisibleStart(for: .oneAndHalf)
        self.isDroneModeEnabled = defaults.bool(forKey: droneModeEnabledKey)
        if let storedOrientation = defaults.string(forKey: keyboardOrientationKey).flatMap(KeyboardOrientationMode.init(rawValue:)) {
            self.keyboardOrientation = storedOrientation
            self.hasStoredKeyboardOrientation = true
        } else {
            self.keyboardOrientation = .landscapeRight
            self.hasStoredKeyboardOrientation = true
            defaults.set(KeyboardOrientationMode.landscapeRight.rawValue, forKey: keyboardOrientationKey)
        }
        self.audioSessionManager = AudioSessionManager {
            synthEngine.ensureRunning()
        }

        audioSessionManager.configureForMixingPlayback()
        synthEngine.start()
        synthEngine.setVolume(Float(volume))
        synthEngine.setPreset(selectedSound)
        synthEngine.setPitchOffsetCents(0)
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
        selectedSound = sound
        synthEngine.setPreset(sound)
    }

    func updatePitchOffsetCents(_ cents: Double) {
        let clamped = min(max(cents, -50), 50).rounded()
        guard pitchOffsetCents != clamped else {
            return
        }

        pitchOffsetCents = clamped
        synthEngine.setPitchOffsetCents(Float(clamped))
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

    var tuningStandardDisplayText: String {
        let frequency = 440 * pow(2, pitchOffsetCents / 1200)
        return String(format: "A%.1f", frequency)
    }

    var hasPitchOffset: Bool {
        abs(pitchOffsetCents) >= 0.5
    }

    var hasLatchedDrones: Bool {
        !latchedDroneNotes.isEmpty
    }
}
