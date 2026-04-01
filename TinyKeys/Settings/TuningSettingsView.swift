import SwiftUI

private let tuningAccent = Color(red: 0.137, green: 0.431, blue: 0.773)

struct TuningSettingsView: View {
    @ObservedObject var viewModel: TinyKeysViewModel

    private let keyColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Tuning")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.tuningSummaryText)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Temperament")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Temperament", selection: temperamentBinding) {
                        ForEach(TemperamentPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(viewModel.tuningSelection.temperament.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Key Center")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: keyColumns, spacing: 8) {
                        ForEach(PitchClass.allCases) { keyCenter in
                            Button {
                                viewModel.updateTuningKeyCenter(keyCenter)
                            } label: {
                                Text(keyCenter.title)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(keyBackground(for: keyCenter))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(keyStroke(for: keyCenter), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.hasNonEqualTemperament)
                            .opacity(viewModel.hasNonEqualTemperament ? 1 : 0.45)
                        }
                    }

                    Text(viewModel.hasNonEqualTemperament ? "The chosen tonic rotates the temperament across the keyboard." : "Equal temperament ignores key center.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Instrument Support")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.isPianoAvailableForCurrentTuning ? "All sounds are available in Equal temperament." : "Unequal temperaments currently retune Sine, Triangle, and Square. Piano is temporarily unavailable and falls back to Sine.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Tuning")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var temperamentBinding: Binding<TemperamentPreset> {
        Binding(
            get: { viewModel.tuningSelection.temperament },
            set: { viewModel.updateTemperament($0) }
        )
    }

    private func keyBackground(for keyCenter: PitchClass) -> Color {
        if keyCenter == viewModel.tuningSelection.keyCenter, viewModel.hasNonEqualTemperament {
            return tuningAccent.opacity(0.18)
        }

        return Color(uiColor: .secondarySystemBackground)
    }

    private func keyStroke(for keyCenter: PitchClass) -> Color {
        if keyCenter == viewModel.tuningSelection.keyCenter, viewModel.hasNonEqualTemperament {
            return tuningAccent
        }

        return Color(uiColor: .separator)
    }
}
