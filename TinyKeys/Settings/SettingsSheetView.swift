import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: TinyKeysViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Visible Keys")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Visible Keys", selection: visibleSpanBinding) {
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
                    Text("Audio Session")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.audioSessionManager.debugState.lines.joined(separator: "\n"))
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer(minLength: 0)
            }
            .padding(20)
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
        .presentationDetents([.medium])
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
}
