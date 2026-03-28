import AVFAudio
import Foundation

final class SynthEngine {
    private enum Event {
        case noteOn(token: Int, midiNote: Int, velocity: Float)
        case noteOff(token: Int)
        case setVolume(Float)
        case setPreset(SoundPreset)
        case stopAll
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
        var frequency: Float = 0
        var velocity: Float = 0
        var phase: Float = 0
        var modPhase: Float = 0
        var stage: VoiceStage = .inactive
        var amplitude: Float = 0
        var attackStep: Float = 0
        var decayStep: Float = 0
        var releaseStep: Float = 0
        var sustainLevel: Float = 0
        var phaseIncrement: Float = 0
        var modPhaseIncrement: Float = 0
        var preset: SoundPreset = .piano
        var ageInSamples: Int = 0

        var isActive: Bool {
            stage != .inactive
        }

        mutating func configure(
            token: Int,
            midiNote: Int,
            velocity: Float,
            sampleRate: Float,
            preset: SoundPreset
        ) {
            self.token = token
            self.midiNote = midiNote
            self.velocity = velocity
            self.frequency = 440 * pow(2, Float(midiNote - 69) / 12)
            self.phase = 0
            self.modPhase = 0
            self.stage = .attack
            self.amplitude = 0
            self.preset = preset
            self.ageInSamples = 0

            let envelope = preset.envelope
            self.sustainLevel = envelope.sustain
            self.attackStep = 1 / max(envelope.attack * sampleRate, 1)
            self.decayStep = (1 - envelope.sustain) / max(envelope.decay * sampleRate, 1)
            self.releaseStep = 0
            self.phaseIncrement = (2 * .pi * frequency) / sampleRate
            self.modPhaseIncrement = phaseIncrement * preset.modulatorRatio
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

            ageInSamples += 1

            let carrier = sin(phase)
            let modulator = sin(modPhase)

            let rawSample: Float
            switch preset {
            case .sine:
                rawSample = carrier
            case .electricPiano:
                let tineTransient = max(0, 1 - (Float(ageInSamples) / 4_200))
                let bellTransient = max(0, 1 - (Float(ageInSamples) / 1_200))
                let gentleFM = sin(phase + (0.26 * modulator))
                rawSample =
                    (0.64 * gentleFM) +
                    (0.18 * sin(phase * 2.0 + (0.08 * modulator))) +
                    (0.10 * tineTransient * sin(phase * 3.01)) +
                    (0.06 * bellTransient * sin(phase * 5.03)) +
                    (0.05 * sin(phase * 0.5))
            case .piano:
                let transient = max(0, 1 - (Float(ageInSamples) / 900))
                rawSample =
                    (0.78 * carrier) +
                    (0.20 * sin(phase * 2.01)) +
                    (0.10 * sin(phase * 4.02)) +
                    (0.05 * transient * sin(modPhase * 5.4))
            }

            phase += phaseIncrement
            modPhase += modPhaseIncrement

            if phase > 2 * .pi {
                phase -= 2 * .pi
            }

            if modPhase > 2 * .pi {
                modPhase -= 2 * .pi
            }

            return rawSample * amplitude * velocity * preset.envelope.gain
        }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private let eventLock = NSLock()
    private var pendingEvents: [Event] = []
    private var voices = Array(repeating: Voice(), count: 24)
    private var currentPreset: SoundPreset = .piano
    private var masterVolume: Float = 0.8
    private var renderSampleRate: Float = 48_000
    private var configurationObserver: NSObjectProtocol?

    init() {
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else {
                return noErr
            }

            return self.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
        }

        engine.attach(sourceNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1

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
            renderSampleRate = Float(engine.mainMixerNode.outputFormat(forBus: 0).sampleRate)
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
        enqueue(.noteOn(token: token, midiNote: midiNote, velocity: velocity))
    }

    func noteOff(token: Int) {
        enqueue(.noteOff(token: token))
    }

    func setVolume(_ volume: Float) {
        enqueue(.setVolume(max(0, min(volume, 1))))
    }

    func setPreset(_ preset: SoundPreset) {
        enqueue(.setPreset(preset))
    }

    func stopAllNotes() {
        enqueue(.stopAll)
    }

    private func enqueue(_ event: Event) {
        eventLock.lock()
        pendingEvents.append(event)
        eventLock.unlock()
    }

    private func drainEvents() -> [Event] {
        eventLock.lock()
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        eventLock.unlock()
        return events
    }

    private func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        applyPendingEvents()

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let floatBuffers: [UnsafeMutableBufferPointer<Float>] = buffers.compactMap { audioBuffer in
            guard let channelData = audioBuffer.mData?.assumingMemoryBound(to: Float.self) else {
                return nil
            }

            return UnsafeMutableBufferPointer(start: channelData, count: frameCount)
        }

        guard !floatBuffers.isEmpty else {
            return noErr
        }

        for frame in 0..<frameCount {
            var mixedSample: Float = 0

            for index in voices.indices {
                voices[index].advanceEnvelope()
                mixedSample += voices[index].nextSample()
            }

            let outputSample = tanh(mixedSample * masterVolume)

            for buffer in floatBuffers {
                buffer[frame] = outputSample
            }
        }

        return noErr
    }

    private func applyPendingEvents() {
        for event in drainEvents() {
            switch event {
            case let .noteOn(token, midiNote, velocity):
                startVoice(token: token, midiNote: midiNote, velocity: velocity)
            case let .noteOff(token):
                stopVoice(token: token)
            case let .setVolume(volume):
                masterVolume = volume
            case let .setPreset(preset):
                currentPreset = preset
            case .stopAll:
                for index in voices.indices {
                    voices[index].stopImmediately()
                }
            }
        }
    }

    private func startVoice(token: Int, midiNote: Int, velocity: Float) {
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
            preset: currentPreset
        )
    }

    private func stopVoice(token: Int) {
        for index in voices.indices where voices[index].token == token && voices[index].isActive {
            voices[index].startRelease(sampleRate: renderSampleRate)
        }
    }
}

private extension SoundPreset {
    var envelope: SynthEngine.Envelope {
        switch self {
        case .piano:
            return .init(attack: 0.003, decay: 0.24, sustain: 0.52, release: 0.11, gain: 0.22)
        case .electricPiano:
            return .init(attack: 0.005, decay: 0.42, sustain: 0.72, release: 0.26, gain: 0.16)
        case .sine:
            return .init(attack: 0.002, decay: 0.08, sustain: 0.92, release: 0.08, gain: 0.17)
        }
    }

    var modulatorRatio: Float {
        switch self {
        case .piano:
            return 2.1
        case .electricPiano:
            return 1.1
        case .sine:
            return 1
        }
    }
}
