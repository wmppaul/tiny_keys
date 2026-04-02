import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: TinyKeysViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isResetConfirmationPresented = false
    @State private var pendingOrientationChange: AppOrientationMode?

    var body: some View {
        NavigationStack(path: settingsPathBinding) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsGroupCard(title: "Playback") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Volume")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Slider(value: volumeBinding, in: 0...1)
                        }

                        Divider()

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

                        Divider()

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

                    SettingsGroupCard(title: "Tuning") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Concert A")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Text("Set the base tuning standard from A392.0 to A460.0.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    viewModel.resetConcertAFrequency()
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 28, height: 28)
                                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.hasConcertAFrequencyOffset)
                                .opacity(viewModel.hasConcertAFrequencyOffset ? 1 : 0.45)
                                .accessibilityLabel("Reset concert A")
                            }

                            HStack(spacing: 10) {
                                Text("A")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)

                                TextField(
                                    "440.0",
                                    value: concertAFrequencyBinding,
                                    format: .number.precision(.fractionLength(1))
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .frame(width: 92)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                                Text("Hz")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cents Shift")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Text(viewModel.pitchOffsetDisplayText)
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

                        Divider()

                        NavigationLink(value: SettingsNavigationDestination.tuning) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Temperament")
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
                    }

                    SettingsGroupCard(title: "Look & Feel") {
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

                            if viewModel.isZoomModeEnabled {
                                Text("Use a pinch gesture on the navigation strip above the keyboard to resize the visible range continuously.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

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

                        Divider()

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
                    }

                    Button(role: .destructive) {
                        isResetConfirmationPresented = true
                    } label: {
                        Text("Reset to Defaults")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
                    .confirmationDialog("Reset all settings?", isPresented: $isResetConfirmationPresented, titleVisibility: .visible) {
                        Button("Reset to Defaults", role: .destructive) {
                            viewModel.resetAllSettingsToDefaults()
                        }

                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This resets the current settings and tuning selection, but keeps your saved custom tunings on the device.")
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
        .onChange(of: pendingOrientationChange) { _, newValue in
            guard let newValue else {
                return
            }

            pendingOrientationChange = nil
            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.updateAppOrientation(newValue)
            }
        }
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

    private var concertAFrequencyBinding: Binding<Double> {
        Binding(
            get: { viewModel.concertAFrequency },
            set: { viewModel.updateConcertAFrequency($0) }
        )
    }

    private var appOrientationBinding: Binding<AppOrientationMode> {
        Binding(
            get: { viewModel.orientationController.appOrientation },
            set: { pendingOrientationChange = $0 }
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

private struct SettingsGroupCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
