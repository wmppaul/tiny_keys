import SwiftUI

private let customTuningAccent = Color(red: 0.137, green: 0.431, blue: 0.773)

private let customTuningIntervalLabels = [
    "Tonic", "m2", "M2", "m3", "M3", "P4",
    "TT", "P5", "m6", "M6", "m7", "M7",
]

struct CustomTuningEditorView: View {
    @ObservedObject var viewModel: TinyKeysViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Editing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.suggestedCustomTuningName)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Selected Key")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.tuningSelection.keyCenter.title)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }

                Text("Each row is the cents offset from equal temperament for one step above the selected tonic. Changing the key center rotates these 12 values across the keyboard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.resetCustomOffsetsToEqual()
                } label: {
                    Text("Reset Offsets to Equal")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                VStack(spacing: 10) {
                    ForEach(Array(viewModel.customEditorPitchClasses.enumerated()), id: \.offset) { degree, pitchClass in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pitchClass.enharmonicTitle)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                                Text(customTuningIntervalLabels[degree])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            Button {
                                viewModel.nudgeCustomOffset(at: degree, by: -1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(customTuningAccent)

                            HStack(spacing: 4) {
                                TextField(
                                    "0.0",
                                    value: customOffsetBinding(for: degree),
                                    format: .number.precision(.fractionLength(1))
                                )
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .frame(width: 72)

                                Text("¢")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                            Button {
                                viewModel.nudgeCustomOffset(at: degree, by: 1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(customTuningAccent)
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Custom Offsets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func customOffsetBinding(for degree: Int) -> Binding<Double> {
        Binding(
            get: { viewModel.customOffset(for: degree) },
            set: { viewModel.updateCustomOffset($0, at: degree) }
        )
    }
}
