import SwiftUI
import UIKit

struct MainKeyboardScreen: View {
    @ObservedObject var viewModel: TinyKeysViewModel
    @ObservedObject private var orientationController = OrientationController.shared

    var body: some View {
        GeometryReader { _ in
            ZStack {
                KeyboardSurfaceView(
                    layout: viewModel.keyboardLayout,
                    visibleWhiteStart: Binding(
                        get: { viewModel.visibleWhiteStart },
                        set: { viewModel.updateVisibleStart($0) }
                    ),
                    visibleWhiteCount: viewModel.visibleSpan.whiteKeyCount,
                    droneModeEnabled: viewModel.isDroneModeEnabled,
                    clearDronesGeneration: viewModel.clearDronesGeneration,
                    keyboardOrientation: viewModel.keyboardOrientation,
                    interfaceOrientation: orientationController.currentInterfaceOrientation,
                    latchedNotesChanged: viewModel.updateLatchedDroneNotes(_:),
                    noteOn: viewModel.noteOn(token:midiNote:),
                    noteOff: viewModel.noteOff(token:)
                )
                .padding(8)

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.shouldShowTuningOverlay {
                                Button {
                                    viewModel.presentTuningSettings()
                                } label: {
                                    SimpleBlueOverlay(
                                        title: "Tuning",
                                        detail: viewModel.tuningSummaryText
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if viewModel.hasConcertAFrequencyOffset {
                                Button {
                                    viewModel.presentSettings()
                                } label: {
                                    SimpleBlueOverlay(
                                        title: "Concert A",
                                        detail: viewModel.concertAFrequencyDisplayText
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if viewModel.hasPitchOffset {
                                Button {
                                    viewModel.presentSettings()
                                } label: {
                                    SimpleBlueOverlay(
                                        title: "Cents",
                                        detail: viewModel.pitchOffsetDisplayText
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)

                        if viewModel.hasLatchedDrones {
                            ClearDronesButton {
                                viewModel.clearDrones()
                            }
                            .padding(.top, (viewModel.hasPitchOffset || viewModel.hasConcertAFrequencyOffset || viewModel.shouldShowTuningOverlay) ? 0 : 10)
                            .padding(.leading, 10)
                        }

                        Spacer()

                        Button {
                            viewModel.presentSettings()
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

                    Spacer()
                }
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .background(
            InterfaceOrientationReaderView { interfaceOrientation in
                viewModel.updateInterfaceOrientation(interfaceOrientation)
            }
            .allowsHitTesting(false)
        )
        .sheet(isPresented: $viewModel.isSettingsPresented, onDismiss: {
            viewModel.updateSettingsNavigationPath([])
        }) {
            SettingsSheetView(viewModel: viewModel)
        }
    }
}

private let settingsAccent = Color(red: 0.137, green: 0.431, blue: 0.773)

private struct SimpleBlueOverlay: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .opacity(0.85)

            Text(detail)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(settingsAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(settingsAccent.opacity(0.85), lineWidth: 1.1)
        )
        .shadow(color: settingsAccent.opacity(0.08), radius: 8, y: 2)
    }
}

private struct ClearDronesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Clear Drones")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(settingsAccent)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(settingsAccent.opacity(0.85), lineWidth: 1.1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct KeyboardSurfaceView: View {
    let layout: PianoKeyboardLayout
    @Binding var visibleWhiteStart: CGFloat
    let visibleWhiteCount: CGFloat
    let droneModeEnabled: Bool
    let clearDronesGeneration: Int
    let keyboardOrientation: KeyboardOrientationMode
    let interfaceOrientation: UIInterfaceOrientation
    let latchedNotesChanged: ([Int]) -> Void
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
                    droneModeEnabled: droneModeEnabled,
                    clearDronesGeneration: clearDronesGeneration,
                    latchedNotesChanged: latchedNotesChanged,
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
