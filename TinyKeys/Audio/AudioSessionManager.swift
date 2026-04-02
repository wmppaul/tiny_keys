import AVFAudio
import Foundation

struct AudioSessionDebugState {
    let category: String
    let mode: String
    let options: [String]
    let errorMessage: String?

    static let empty = AudioSessionDebugState(category: "unknown", mode: "unknown", options: ["none"], errorMessage: nil)

    var lines: [String] {
        var formatted = [
            "Category: \(category)",
            "Mode: \(mode)",
            "Options: \(options.joined(separator: ", "))"
        ]

        if let errorMessage {
            formatted.append("Error: \(errorMessage)")
        }

        return formatted
    }
}

@MainActor
final class AudioSessionManager: ObservableObject {
    @Published private(set) var debugState: AudioSessionDebugState = .empty

    private let session = AVAudioSession.sharedInstance()
    private let onInterruptionEnded: () -> Void
    private var observers: [NSObjectProtocol] = []

    init(onInterruptionEnded: @escaping () -> Void) {
        self.onInterruptionEnded = onInterruptionEnded
        registerObservers()
    }

    static func configureIdleLaunchSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            // Preload the intended playback category early, but do not activate it yet.
            // This avoids a category swap on first note while still deferring ownership of
            // the audio session until the user actually plays.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            print("Tiny Keys failed to configure idle launch audio session: \(error.localizedDescription)")
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func prepareForMixingPlayback() {
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            refreshDebugState()
        } catch {
            refreshDebugState(errorMessage: error.localizedDescription)
        }
    }

    func configureForMixingPlayback() {
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            refreshDebugState()
        } catch {
            refreshDebugState(errorMessage: error.localizedDescription)
        }
    }

    func reactivateIfNeeded() {
        do {
            try session.setActive(true)
            refreshDebugState()
        } catch {
            refreshDebugState(errorMessage: error.localizedDescription)
        }
    }

    private func registerObservers() {
        let notificationCenter = NotificationCenter.default

        observers.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleInterruption(notification)
                }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleRouteChange(notification)
                }
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawValue)
        else {
            refreshDebugState()
            return
        }

        switch type {
        case .began:
            refreshDebugState()
        case .ended:
            configureForMixingPlayback()
            onInterruptionEnded()
        @unknown default:
            refreshDebugState()
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        _ = notification
        refreshDebugState()
    }

    private func refreshDebugState(errorMessage: String? = nil) {
        debugState = AudioSessionDebugState(
            category: session.category.debugName,
            mode: session.mode.debugName,
            options: session.categoryOptions.debugNames,
            errorMessage: errorMessage
        )
    }
}

private extension AVAudioSession.Category {
    var debugName: String {
        switch self {
        case .ambient:
            return "ambient"
        case .soloAmbient:
            return "soloAmbient"
        case .playback:
            return "playback"
        case .record:
            return "record"
        case .playAndRecord:
            return "playAndRecord"
        case .multiRoute:
            return "multiRoute"
        default:
            return rawValue
        }
    }
}

private extension AVAudioSession.Mode {
    var debugName: String {
        switch self {
        case .default:
            return "default"
        case .voiceChat:
            return "voiceChat"
        case .videoChat:
            return "videoChat"
        case .gameChat:
            return "gameChat"
        case .videoRecording:
            return "videoRecording"
        case .measurement:
            return "measurement"
        case .moviePlayback:
            return "moviePlayback"
        case .spokenAudio:
            return "spokenAudio"
        case .voicePrompt:
            return "voicePrompt"
        default:
            return rawValue
        }
    }
}

private extension AVAudioSession.CategoryOptions {
    var debugNames: [String] {
        var names: [String] = []

        if contains(.mixWithOthers) { names.append("mixWithOthers") }
        if contains(.duckOthers) { names.append("duckOthers") }
        if contains(.interruptSpokenAudioAndMixWithOthers) { names.append("interruptSpokenAudioAndMixWithOthers") }
        if contains(.allowBluetoothHFP) { names.append("allowBluetoothHFP") }
        if contains(.allowBluetoothA2DP) { names.append("allowBluetoothA2DP") }
        if contains(.defaultToSpeaker) { names.append("defaultToSpeaker") }
        if contains(.allowAirPlay) { names.append("allowAirPlay") }
        if contains(.overrideMutedMicrophoneInterruption) { names.append("overrideMutedMicrophoneInterruption") }

        return names.isEmpty ? ["none"] : names
    }
}
