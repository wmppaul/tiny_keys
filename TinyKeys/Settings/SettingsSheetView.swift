import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: TinyKeysViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: settingsPathBinding) {
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

                    NavigationLink(value: SettingsNavigationDestination.tuning) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Tuning")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(viewModel.tuningSummaryText)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: droneModeBinding) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Drone Mode")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text("Swipe along a key to latch or unlatch a sustained drone.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pitch Correction")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text("\(viewModel.pitchOffsetDisplayText) (\(viewModel.tuningStandardDisplayText))")
                                    .font(.footnote)
                                    .monospacedDigit()
                            }

                            Spacer()

                            Button {
                                viewModel.resetPitchOffset()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 28, height: 28)
                                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.hasPitchOffset)
                            .opacity(viewModel.hasPitchOffset ? 1 : 0.45)
                            .accessibilityLabel("Reset pitch correction")
                        }

                        Slider(value: pitchOffsetBinding, in: -50...50, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sound")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Sound", selection: soundBinding) {
                            ForEach(viewModel.availableSoundPresets) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)

                        if !viewModel.isPianoAvailableForCurrentTuning {
                            Text("Piano is available only in Equal temperament during this phase.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
            .navigationDestination(for: SettingsNavigationDestination.self) { destination in
                switch destination {
                case .tuning:
                    TuningSettingsView(viewModel: viewModel)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var settingsPathBinding: Binding<[SettingsNavigationDestination]> {
        Binding(
            get: { viewModel.settingsNavigationPath },
            set: { viewModel.updateSettingsNavigationPath($0) }
        )
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
            get: {
                if viewModel.availableSoundPresets.contains(viewModel.selectedSound) {
                    return viewModel.selectedSound
                }

                return viewModel.availableSoundPresets.first ?? .sine
            },
            set: { viewModel.updateSound($0) }
        )
    }

    private var pitchOffsetBinding: Binding<Double> {
        Binding(
            get: { viewModel.pitchOffsetCents },
            set: { viewModel.updatePitchOffsetCents($0) }
        )
    }

    private var appOrientationBinding: Binding<AppOrientationMode> {
        Binding(
            get: { viewModel.orientationController.appOrientation },
            set: { viewModel.updateAppOrientation($0) }
        )
    }

    private var keyboardOrientationBinding: Binding<KeyboardOrientationMode> {
        Binding(
            get: { viewModel.keyboardOrientation },
            set: { viewModel.updateKeyboardOrientation($0) }
        )
    }

    private var droneModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isDroneModeEnabled },
            set: { viewModel.updateDroneModeEnabled($0) }
        )
    }
}
