import SwiftUI

struct MainKeyboardScreen: View {
    @ObservedObject var viewModel: TinyKeysViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    KeyboardNavigationStrip(
                        layout: viewModel.keyboardLayout,
                        visibleWhiteStart: Binding(
                            get: { viewModel.visibleWhiteStart },
                            set: { viewModel.updateVisibleStart($0) }
                        ),
                        visibleWhiteCount: viewModel.visibleSpan.whiteKeyCount
                    )
                    .frame(height: min(max(geometry.size.height * 0.09, 20), 28))

                    Button {
                        viewModel.isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }

                PianoKeyboardView(
                    layout: viewModel.keyboardLayout,
                    visibleWhiteStart: viewModel.visibleWhiteStart,
                    visibleWhiteCount: viewModel.visibleSpan.whiteKeyCount,
                    noteOn: viewModel.noteOn(token:midiNote:),
                    noteOff: viewModel.noteOff(token:)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
    }
}
