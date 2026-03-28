import Foundation

@MainActor
final class TinyKeysViewModel: ObservableObject {
    let keyboardLayout = PianoKeyboardLayout()
    let audioSessionManager: AudioSessionManager

    @Published private(set) var visibleSpan: VisibleKeySpan = .oneAndHalf
    @Published private(set) var visibleWhiteStart: CGFloat
    @Published private(set) var volume: Double = 0.8
    @Published private(set) var selectedSound: SoundPreset = .piano
    @Published var isSettingsPresented = false

    private let synthEngine: SynthEngine

    init() {
        let synthEngine = SynthEngine()
        self.synthEngine = synthEngine
        self.visibleWhiteStart = keyboardLayout.defaultVisibleStart(for: .oneAndHalf)
        self.audioSessionManager = AudioSessionManager {
            synthEngine.ensureRunning()
        }

        audioSessionManager.configureForMixingPlayback()
        synthEngine.start()
        synthEngine.setVolume(Float(volume))
        synthEngine.setPreset(selectedSound)
    }

    func activateAudioIfNeeded() {
        audioSessionManager.configureForMixingPlayback()
        synthEngine.ensureRunning()
    }

    func noteOn(token: Int, midiNote: Int) {
        synthEngine.noteOn(token: token, midiNote: midiNote)
    }

    func noteOff(token: Int) {
        synthEngine.noteOff(token: token)
    }

    func stopAllNotes() {
        synthEngine.stopAllNotes()
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
}
