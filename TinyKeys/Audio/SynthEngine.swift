import AudioToolbox
import AVFAudio
import Foundation

final class SynthEngine {
    private enum EventKind {
        case noteOn
        case noteOff
        case stopAllWaveforms
        case updatePitchOffset
    }

    private struct Event {
        var kind: EventKind = .stopAllWaveforms
        var token: Int = 0
        var midiNote: Int = 0
        var velocity: Float = 0
        var preset: SoundPreset = .sine
        var pitchOffsetCents: Float = 0
    }

    private enum VoiceStage {
        case inactive
        case attack
        case decay
        case sustain
        case release
    }

    fileprivate struct Envelope {
        let attack: Float
        let decay: Float
        let sustain: Float
        let release: Float
        let gain: Float
    }

    private struct Voice {
        var token: Int = 0
        var midiNote: Int = 0
        var velocity: Float = 0
        var phase: Float = 0
        var stage: VoiceStage = .inactive
        var amplitude: Float = 0
        var attackStep: Float = 0
        var decayStep: Float = 0
        var releaseStep: Float = 0
        var sustainLevel: Float = 0
        var phaseIncrement: Float = 0
        var preset: SoundPreset = .sine

        var isActive: Bool {
            stage != .inactive
        }

        mutating func configure(
            token: Int,
            midiNote: Int,
            velocity: Float,
            sampleRate: Float,
            preset: SoundPreset,
            pitchOffsetCents: Float
        ) {
            self.token = token
            self.midiNote = midiNote
            self.velocity = velocity
            self.phase = 0
            self.stage = .attack
            self.amplitude = 0
            self.preset = preset

            let envelope = preset.envelope

            self.sustainLevel = envelope.sustain
            self.attackStep = 1 / max(envelope.attack * sampleRate, 1)
            self.decayStep = (1 - envelope.sustain) / max(envelope.decay * sampleRate, 1)
            self.releaseStep = 0
            self.phaseIncrement = Self.phaseIncrement(
                midiNote: midiNote,
                sampleRate: sampleRate,
                pitchOffsetCents: pitchOffsetCents
            )
        }

        mutating func retune(sampleRate: Float, pitchOffsetCents: Float) {
            guard isActive else {
                return
            }

            phaseIncrement = Self.phaseIncrement(
                midiNote: midiNote,
                sampleRate: sampleRate,
                pitchOffsetCents: pitchOffsetCents
            )
        }

        mutating func startRelease(sampleRate: Float) {
            guard stage != .inactive, stage != .release else {
                return
            }

            stage = .release
            releaseStep = amplitude / max(preset.envelope.release * sampleRate, 1)
        }

        mutating func stopImmediately() {
            stage = .inactive
            amplitude = 0
        }

        mutating func advanceEnvelope() {
            switch stage {
            case .inactive:
                break
            case .attack:
                amplitude += attackStep
                if amplitude >= 1 {
                    amplitude = 1
                    stage = .decay
                }
            case .decay:
                amplitude -= decayStep
                if amplitude <= sustainLevel {
                    amplitude = sustainLevel
                    stage = .sustain
                }
            case .sustain:
                break
            case .release:
                amplitude -= releaseStep
                if amplitude <= 0.0001 {
                    stopImmediately()
                }
            }
        }

        mutating func nextSample() -> Float {
            guard isActive else {
                return 0
            }

            let carrier = sin(phase)
            let rawSample: Float

            switch preset {
            case .sine:
                rawSample = carrier
            case .square:
                rawSample = carrier >= 0 ? 1 : -1
            case .triangle:
                rawSample = (2 / .pi) * asin(carrier)
            case .piano:
                rawSample = carrier
            }

            phase += phaseIncrement
            if phase > 2 * .pi {
                phase -= 2 * .pi
            }

            return rawSample * amplitude * velocity * preset.envelope.gain
        }

        private static func phaseIncrement(midiNote: Int, sampleRate: Float, pitchOffsetCents: Float) -> Float {
            let frequency = 440 * pow(2, (Float(midiNote - 69) / 12) + (pitchOffsetCents / 1200))
            return (2 * .pi * frequency) / sampleRate
        }
    }

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let instrumentMixer = AVAudioMixerNode()
    private let eventLock = NSLock()
    private let pianoLock = NSLock()
    private var voices = Array(repeating: Voice(), count: 24)
    private var sourceNode: AVAudioSourceNode!
    private var activePianoTokens: [Int: UInt8] = [:]
    private var activePianoNoteCounts: [UInt8: Int] = [:]
    private var currentPreset: SoundPreset = .piano
    private var waveformPitchOffsetCents: Float = 0
    private var renderSampleRate: Float = 48_000
    private var configurationObserver: NSObjectProtocol?
    private let eventBufferCapacity = 256
    private var eventBuffer: [Event]
    private var eventReadIndex = 0
    private var eventWriteIndex = 0
    private var eventCount = 0

    init() {
        eventBuffer = Array(repeating: Event(), count: eventBufferCapacity)

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else {
                return noErr
            }

            return self.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
        }

        engine.attach(sourceNode)
        engine.attach(sampler)
        engine.attach(instrumentMixer)

        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        engine.connect(sourceNode, to: instrumentMixer, format: sourceFormat)
        engine.connect(sampler, to: instrumentMixer, format: nil)
        engine.connect(instrumentMixer, to: engine.mainMixerNode, format: sourceFormat)

        instrumentMixer.outputVolume = 0.8
        engine.mainMixerNode.outputVolume = 1

        loadPianoSoundFont()

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.ensureRunning()
        }
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    func start() {
        if engine.isRunning {
            return
        }

        do {
            try engine.start()
            renderSampleRate = Float(instrumentMixer.outputFormat(forBus: 0).sampleRate)
        } catch {
            print("Tiny Keys audio engine failed to start: \(error.localizedDescription)")
        }
    }

    func ensureRunning() {
        if !engine.isRunning {
            start()
        }
    }

    func noteOn(token: Int, midiNote: Int, velocity: Float = 1.0) {
        ensureRunning()

        switch currentPreset {
        case .piano:
            startPianoNote(token: token, midiNote: midiNote, velocity: velocity)
        case .sine, .square, .triangle:
            enqueue(Event(kind: .noteOn, token: token, midiNote: midiNote, velocity: velocity, preset: currentPreset))
        }
    }

    func noteOff(token: Int) {
        if stopPianoNoteIfNeeded(token: token) {
            return
        }

        enqueue(Event(kind: .noteOff, token: token))
    }

    func setVolume(_ volume: Float) {
        instrumentMixer.outputVolume = max(0, min(volume, 1))
    }

    func setPreset(_ preset: SoundPreset) {
        guard currentPreset != preset else {
            return
        }

        stopAllNotes()
        currentPreset = preset
    }

    func stopAllNotes() {
        stopAllPianoNotes()
        enqueue(Event(kind: .stopAllWaveforms))
    }

    func setPitchOffsetCents(_ cents: Float) {
        let clamped = max(-50, min(cents, 50))
        sampler.globalTuning = clamped
        enqueue(Event(kind: .updatePitchOffset, pitchOffsetCents: clamped))
    }

    private func enqueue(_ event: Event) {
        eventLock.lock()
        eventBuffer[eventWriteIndex] = event
        eventWriteIndex = (eventWriteIndex + 1) % eventBuffer.count

        if eventCount == eventBuffer.count {
            eventReadIndex = (eventReadIndex + 1) % eventBuffer.count
        } else {
            eventCount += 1
        }

        eventLock.unlock()
    }

    private func drainNextEvent() -> Event? {
        eventLock.lock()
        defer { eventLock.unlock() }

        guard eventCount > 0 else {
            return nil
        }

        let event = eventBuffer[eventReadIndex]
        eventReadIndex = (eventReadIndex + 1) % eventBuffer.count
        eventCount -= 1

        return event
    }

    private func renderMonoSample(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) -> OSStatus {
        guard frameCount > 0, !buffers.isEmpty else {
            return noErr
        }

        switch buffers.count {
        case 1:
            guard let channel0 = buffers[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            for frame in 0..<frameCount {
                channel0[frame] = nextMixedSample()
            }

        case 2:
            guard
                let channel0 = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                let channel1 = buffers[1].mData?.assumingMemoryBound(to: Float.self)
            else {
                return noErr
            }

            for frame in 0..<frameCount {
                let sample = nextMixedSample()
                channel0[frame] = sample
                channel1[frame] = sample
            }

        default:
            for frame in 0..<frameCount {
                let sample = nextMixedSample()

                for bufferIndex in buffers.indices {
                    guard let channel = buffers[bufferIndex].mData?.assumingMemoryBound(to: Float.self) else {
                        continue
                    }

                    channel[frame] = sample
                }
            }
        }

        return noErr
    }

    private func nextMixedSample() -> Float {
        var mixedSample: Float = 0

        for index in voices.indices {
            voices[index].advanceEnvelope()
            mixedSample += voices[index].nextSample()
        }

        return tanh(mixedSample)
    }

    private func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        applyPendingEvents()

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return renderMonoSample(frameCount: frameCount, into: buffers)
    }

    private func applyPendingEvents() {
        while let event = drainNextEvent() {
            switch event.kind {
            case .noteOn:
                startWaveformVoice(token: event.token, midiNote: event.midiNote, velocity: event.velocity, preset: event.preset)
            case .noteOff:
                stopWaveformVoice(token: event.token)
            case .stopAllWaveforms:
                for index in voices.indices {
                    voices[index].stopImmediately()
                }
            case .updatePitchOffset:
                waveformPitchOffsetCents = event.pitchOffsetCents
                for index in voices.indices {
                    voices[index].retune(sampleRate: renderSampleRate, pitchOffsetCents: waveformPitchOffsetCents)
                }
            }
        }
    }

    private func startWaveformVoice(token: Int, midiNote: Int, velocity: Float, preset: SoundPreset) {
        let targetIndex = voices.firstIndex(where: { $0.token == token && $0.isActive }) ??
            voices.firstIndex(where: { !$0.isActive }) ??
            voices.enumerated().min(by: { $0.element.amplitude < $1.element.amplitude })?.offset

        guard let targetIndex else {
            return
        }

        voices[targetIndex].configure(
            token: token,
            midiNote: midiNote,
            velocity: velocity,
            sampleRate: renderSampleRate,
            preset: preset,
            pitchOffsetCents: waveformPitchOffsetCents
        )
    }

    private func stopWaveformVoice(token: Int) {
        for index in voices.indices where voices[index].token == token && voices[index].isActive {
            voices[index].startRelease(sampleRate: renderSampleRate)
        }
    }

    private func loadPianoSoundFont() {
        guard
            let soundFontURL = Bundle.main.url(forResource: "UprightPianoKW-small-20190703", withExtension: "sf2") ??
                Bundle.main.url(forResource: "UprightPianoKW-small-20190703", withExtension: "sf2", subdirectory: "SoundFonts")
        else {
            print("Tiny Keys could not find UprightPianoKW-small-20190703.sf2 in the app bundle.")
            return
        }

        do {
            try sampler.loadSoundBankInstrument(
                at: soundFontURL,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: 0
            )
        } catch {
            print("Tiny Keys failed to load piano sound font: \(error.localizedDescription)")
        }
    }

    private func startPianoNote(token: Int, midiNote: Int, velocity: Float) {
        let clampedNote = UInt8(max(0, min(midiNote, 127)))
        let clampedVelocity = UInt8(max(1, min(Int(velocity * 127), 127)))
        var noteToStop: UInt8?
        var shouldStartNote = false

        pianoLock.lock()

        if let existingNote = activePianoTokens[token] {
            let remainingCount = (activePianoNoteCounts[existingNote] ?? 1) - 1
            if remainingCount <= 0 {
                activePianoNoteCounts.removeValue(forKey: existingNote)
                noteToStop = existingNote
            } else {
                activePianoNoteCounts[existingNote] = remainingCount
            }
        }

        activePianoTokens[token] = clampedNote
        let existingCount = activePianoNoteCounts[clampedNote] ?? 0
        activePianoNoteCounts[clampedNote] = existingCount + 1
        shouldStartNote = existingCount == 0

        pianoLock.unlock()

        if let noteToStop {
            sampler.stopNote(noteToStop, onChannel: 0)
        }

        if shouldStartNote {
            sampler.startNote(clampedNote, withVelocity: clampedVelocity, onChannel: 0)
        }
    }

    @discardableResult
    private func stopPianoNoteIfNeeded(token: Int) -> Bool {
        var noteToStop: UInt8?

        pianoLock.lock()

        guard let note = activePianoTokens.removeValue(forKey: token) else {
            pianoLock.unlock()
            return false
        }

        let remainingCount = (activePianoNoteCounts[note] ?? 1) - 1
        if remainingCount <= 0 {
            activePianoNoteCounts.removeValue(forKey: note)
            noteToStop = note
        } else {
            activePianoNoteCounts[note] = remainingCount
        }

        pianoLock.unlock()

        if let noteToStop {
            sampler.stopNote(noteToStop, onChannel: 0)
        }

        return true
    }

    private func stopAllPianoNotes() {
        var notesToStop: [UInt8] = []

        pianoLock.lock()
        notesToStop = Array(activePianoNoteCounts.keys)
        activePianoTokens.removeAll(keepingCapacity: true)
        activePianoNoteCounts.removeAll(keepingCapacity: true)
        pianoLock.unlock()

        for note in notesToStop {
            sampler.stopNote(note, onChannel: 0)
        }
    }
}

private extension SoundPreset {
    var envelope: SynthEngine.Envelope {
        switch self {
        case .piano:
            return .init(attack: 0.003, decay: 0.24, sustain: 0.52, release: 0.11, gain: 0.22)
        case .sine:
            return .init(attack: 0.002, decay: 0.08, sustain: 0.92, release: 0.08, gain: 0.18)
        case .square:
            return .init(attack: 0.002, decay: 0.06, sustain: 0.78, release: 0.06, gain: 0.10)
        case .triangle:
            return .init(attack: 0.002, decay: 0.08, sustain: 0.88, release: 0.08, gain: 0.15)
        }
    }
}
