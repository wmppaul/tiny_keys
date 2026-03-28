import Foundation
import UIKit

@MainActor
final class OrientationController: ObservableObject {
    static let shared = OrientationController()

    @Published private(set) var appOrientation: AppOrientationMode
    @Published private(set) var currentInterfaceOrientation: UIInterfaceOrientation
    @Published private(set) var lastErrorMessage: String?

    private let defaults = UserDefaults.standard
    private let appOrientationKey = "tinykeys.appOrientation"

    private init() {
        let storedMode = defaults.string(forKey: appOrientationKey).flatMap(AppOrientationMode.init(rawValue:))
        let appOrientation = storedMode ?? .portrait
        self.appOrientation = appOrientation
        self.currentInterfaceOrientation = appOrientation.defaultInterfaceOrientation
    }

    var supportedMask: UIInterfaceOrientationMask {
        appOrientation.supportedMask
    }

    func updateAppOrientation(_ orientation: AppOrientationMode) {
        guard appOrientation != orientation else {
            applyCurrentOrientation()
            return
        }

        appOrientation = orientation
        defaults.set(orientation.rawValue, forKey: appOrientationKey)
        applyCurrentOrientation()
    }

    func applyCurrentOrientation() {
        guard let windowScene = activeWindowScene else {
            return
        }

        if let sceneOrientation = nonUnknownOrientation(from: windowScene.interfaceOrientation) {
            currentInterfaceOrientation = sceneOrientation
        }

        lastErrorMessage = nil

        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            window.rootViewController?.presentedViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        if #available(iOS 16.0, *) {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: appOrientation.supportedMask)) { [weak self] error in
                Task { @MainActor in
                    self?.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func updateCurrentInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        guard let orientation = nonUnknownOrientation(from: orientation) else {
            return
        }

        currentInterfaceOrientation = orientation
    }

    private var activeWindowScene: UIWindowScene? {
        let connectedScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        return connectedScenes.first(where: { $0.activationState == .foregroundActive }) ??
            connectedScenes.first(where: { $0.activationState == .foregroundInactive }) ??
            connectedScenes.first
    }

    private func nonUnknownOrientation(from orientation: UIInterfaceOrientation) -> UIInterfaceOrientation? {
        switch orientation {
        case .portrait, .landscapeLeft, .landscapeRight:
            return orientation
        default:
            return nil
        }
    }
}
