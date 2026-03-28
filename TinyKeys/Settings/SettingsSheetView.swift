import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: TinyKeysViewModel
    @ObservedObject private var orientationController = OrientationController.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("App Orientation")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("App Orientation", selection: appOrientationBinding) {
                            ForEach(AppOrientationMode.allCases) { orientation in
                                Text(orientation.title).tag(orientation)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Keyboard Direction")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Keyboard Direction", selection: keyboardOrientationBinding) {
                            ForEach(KeyboardOrientationMode.allCases) { orientation in
                                Text(orientation.title).tag(orientation)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Visible Octaves")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Visible Octaves", selection: visibleSpanBinding) {
                            ForEach(VisibleKeySpan.allCases) { span in
                                Text(span.title).tag(span)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Volume")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Slider(value: volumeBinding, in: 0...1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sound")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Sound", selection: soundBinding) {
                            ForEach(SoundPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interface")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(interfaceDebugLines.joined(separator: "\n"))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Session")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(viewModel.audioSessionManager.debugState.lines.joined(separator: "\n"))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var visibleSpanBinding: Binding<VisibleKeySpan> {
        Binding(
            get: { viewModel.visibleSpan },
            set: { viewModel.updateVisibleSpan($0) }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { viewModel.volume },
            set: { viewModel.updateVolume($0) }
        )
    }

    private var soundBinding: Binding<SoundPreset> {
        Binding(
            get: { viewModel.selectedSound },
            set: { viewModel.updateSound($0) }
        )
    }

    private var appOrientationBinding: Binding<AppOrientationMode> {
        Binding(
            get: { orientationController.appOrientation },
            set: { viewModel.updateAppOrientation($0) }
        )
    }

    private var keyboardOrientationBinding: Binding<KeyboardOrientationMode> {
        Binding(
            get: { viewModel.keyboardOrientation },
            set: { viewModel.updateKeyboardOrientation($0) }
        )
    }

    private var interfaceDebugLines: [String] {
        var lines = [
            "App Mode: \(orientationController.appOrientation.title)",
            "Scene: \(orientationController.currentInterfaceOrientation.tinyKeysDebugName)",
            "Keyboard: \(viewModel.keyboardOrientation.rawValue)"
        ]

        if let lastErrorMessage = orientationController.lastErrorMessage {
            lines.append("Rotation Error: \(lastErrorMessage)")
        }

        return lines
    }
}
