import SwiftUI
import UIKit

struct MainKeyboardScreen: View {
    @ObservedObject var viewModel: TinyKeysViewModel
    @ObservedObject private var orientationController = OrientationController.shared

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topTrailing) {
                KeyboardSurfaceView(
                    layout: viewModel.keyboardLayout,
                    visibleWhiteStart: Binding(
                        get: { viewModel.visibleWhiteStart },
                        set: { viewModel.updateVisibleStart($0) }
                    ),
                    visibleWhiteCount: viewModel.visibleSpan.whiteKeyCount,
                    keyboardOrientation: viewModel.keyboardOrientation,
                    interfaceOrientation: orientationController.currentInterfaceOrientation,
                    noteOn: viewModel.noteOn(token:midiNote:),
                    noteOff: viewModel.noteOff(token:)
                )
                .padding(8)

                Button {
                    viewModel.isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(settingsAccent, lineWidth: 1.25)
                        )
                        .foregroundStyle(settingsAccent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .padding(10)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .background(
            InterfaceOrientationReaderView { interfaceOrientation in
                viewModel.updateInterfaceOrientation(interfaceOrientation)
            }
            .allowsHitTesting(false)
        )
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
    }
}

private let settingsAccent = Color(red: 0.137, green: 0.431, blue: 0.773)

private struct KeyboardSurfaceView: View {
    let layout: PianoKeyboardLayout
    @Binding var visibleWhiteStart: CGFloat
    let visibleWhiteCount: CGFloat
    let keyboardOrientation: KeyboardOrientationMode
    let interfaceOrientation: UIInterfaceOrientation
    let noteOn: (Int, Int) -> Void
    let noteOff: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let outerSize = geometry.size
            let swapsAxes = keyboardOrientation.swapsAxes(from: interfaceOrientation)
            let contentSize = CGSize(
                width: swapsAxes ? outerSize.height : outerSize.width,
                height: swapsAxes ? outerSize.width : outerSize.height
            )
            let navigationHeight = min(max(contentSize.height * 0.09, 20), 28)

            VStack(spacing: 6) {
                KeyboardNavigationStrip(
                    layout: layout,
                    visibleWhiteStart: $visibleWhiteStart,
                    visibleWhiteCount: visibleWhiteCount
                )
                .frame(height: navigationHeight)

                PianoKeyboardView(
                    layout: layout,
                    visibleWhiteStart: visibleWhiteStart,
                    visibleWhiteCount: visibleWhiteCount,
                    noteOn: noteOn,
                    noteOff: noteOff
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: contentSize.width, height: contentSize.height)
            .rotationEffect(.degrees(keyboardOrientation.rotationDegrees(from: interfaceOrientation)))
            .position(x: outerSize.width / 2, y: outerSize.height / 2)
        }
    }
}

private struct InterfaceOrientationReaderView: UIViewRepresentable {
    let onChange: (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> OrientationReporterView {
        let view = OrientationReporterView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: OrientationReporterView, context: Context) {
        uiView.onChange = onChange
        uiView.reportIfNeeded()
    }
}

private final class OrientationReporterView: UIView {
    var onChange: ((UIInterfaceOrientation) -> Void)?
    private var lastReportedOrientation: UIInterfaceOrientation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportIfNeeded()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        reportIfNeeded()
    }

    func reportIfNeeded() {
        guard
            let orientation = window?.windowScene?.interfaceOrientation,
            orientation != .unknown,
            orientation != lastReportedOrientation
        else {
            return
        }

        lastReportedOrientation = orientation
        onChange?(orientation)
    }
}
