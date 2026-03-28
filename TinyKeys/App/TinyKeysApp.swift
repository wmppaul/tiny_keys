import SwiftUI

@main
struct TinyKeysApp: App {
    @UIApplicationDelegateAdaptor(TinyKeysAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TinyKeysViewModel()

    var body: some Scene {
        WindowGroup {
            MainKeyboardScreen(viewModel: viewModel)
                .statusBarHidden(true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.activateAudioIfNeeded()
            case .background:
                viewModel.stopAllNotes()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
