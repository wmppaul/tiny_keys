import SwiftUI

private let tuningAccent = Color(red: 0.137, green: 0.431, blue: 0.773)

private enum TuningNamePrompt: Identifiable {
    case saveNew
    case rename(UUID)
    case duplicate(UUID)

    var id: String {
        switch self {
        case .saveNew:
            return "saveNew"
        case let .rename(id):
            return "rename-\(id.uuidString)"
        case let .duplicate(id):
            return "duplicate-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .saveNew:
            return "Save Custom Tuning"
        case .rename:
            return "Rename Tuning"
        case .duplicate:
            return "Duplicate Tuning"
        }
    }

    var actionTitle: String {
        switch self {
        case .saveNew:
            return "Save"
        case .rename:
            return "Rename"
        case .duplicate:
            return "Duplicate"
        }
    }
}

struct TuningSettingsView: View {
    @ObservedObject var viewModel: TinyKeysViewModel

    @State private var isCustomEditorPresented = false
    @State private var namingPrompt: TuningNamePrompt?
    @State private var pendingDeletePreset: SavedCustomTuning?
    @State private var tuningNameDraft = ""

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

                customTuningSection

                savedTuningsSection

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
        .navigationDestination(isPresented: $isCustomEditorPresented) {
            CustomTuningEditorView(viewModel: viewModel)
        }
        .alert(activeNamingPromptTitle, isPresented: isNamingPromptPresented) {
            TextField("Name", text: $tuningNameDraft)

            Button("Cancel", role: .cancel) {
                namingPrompt = nil
            }

            Button(activeNamingPromptActionTitle) {
                submitNamingPrompt()
            }
            .disabled(tuningNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(activeNamingPromptMessage)
        }
        .confirmationDialog("Delete Tuning?", isPresented: isDeletePromptPresented, presenting: pendingDeletePreset) { preset in
            Button("Delete \(preset.name)", role: .destructive) {
                viewModel.deleteCustomTuning(id: preset.id)
                pendingDeletePreset = nil
            }

            Button("Cancel", role: .cancel) {
                pendingDeletePreset = nil
            }
        } message: { preset in
            Text("This removes \(preset.name) from this device. The current custom tuning will stay active until you change it.")
        }
    }

    private var customTuningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Tuning")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if viewModel.isCustomTuningSelected {
                Button {
                    isCustomEditorPresented = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Edit 12 Offsets")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("Rows follow the selected tonic and store cents offsets locally.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tuningAccent)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Text(viewModel.customTuningStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Save as New") {
                        presentNamingPrompt(.saveNew, suggestedName: viewModel.suggestedCustomTuningName)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tuningAccent)

                    Button("Update") {
                        viewModel.updateCurrentCustomTuning()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canUpdateSelectedCustomTuning || !viewModel.isSelectedCustomTuningModified)
                }
            } else {
                Button {
                    viewModel.startCustomTuningFromCurrentSelection()
                    isCustomEditorPresented = true
                } label: {
                    Text("Make Custom Copy")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(tuningAccent)

                Text(viewModel.customTuningStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var savedTuningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Tunings")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if viewModel.hasSavedCustomTunings {
                VStack(spacing: 10) {
                    ForEach(viewModel.savedCustomTunings) { tuning in
                        HStack(spacing: 10) {
                            Button {
                                viewModel.applySavedCustomTuning(tuning)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(tuning.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        if isSavedTuningActive(tuning) {
                                            Text(viewModel.isSelectedCustomTuningModified ? "Edited" : "Active")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(tuningAccent.opacity(0.18), in: Capsule())
                                                .foregroundStyle(tuningAccent)
                                        }
                                    }

                                    Text(tuning.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(savedTuningBackground(for: tuning))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(savedTuningStroke(for: tuning), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button("Rename") {
                                    presentNamingPrompt(.rename(tuning.id), suggestedName: tuning.name)
                                }

                                Button("Duplicate") {
                                    presentNamingPrompt(.duplicate(tuning.id), suggestedName: "\(tuning.name) Copy")
                                }

                                Button("Delete", role: .destructive) {
                                    pendingDeletePreset = tuning
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(tuningAccent)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("Saved custom tunings live only on this device. Create one from the current tuning, then save it here for quick recall.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var temperamentBinding: Binding<TemperamentPreset> {
        Binding(
            get: { viewModel.tuningSelection.temperament },
            set: { viewModel.updateTemperament($0) }
        )
    }

    private var isNamingPromptPresented: Binding<Bool> {
        Binding(
            get: { namingPrompt != nil },
            set: { newValue in
                if !newValue {
                    namingPrompt = nil
                }
            }
        )
    }

    private var isDeletePromptPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletePreset != nil },
            set: { newValue in
                if !newValue {
                    pendingDeletePreset = nil
                }
            }
        )
    }

    private var activeNamingPromptTitle: String {
        namingPrompt?.title ?? ""
    }

    private var activeNamingPromptActionTitle: String {
        namingPrompt?.actionTitle ?? "Save"
    }

    private var activeNamingPromptMessage: String {
        switch namingPrompt {
        case .saveNew:
            return "Give this tuning a name so you can recall it later on this device."
        case .rename:
            return "Update the saved name for this custom tuning."
        case .duplicate:
            return "Create a second saved copy with a new name."
        case nil:
            return ""
        }
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

    private func savedTuningBackground(for tuning: SavedCustomTuning) -> Color {
        if isSavedTuningActive(tuning) {
            return tuningAccent.opacity(0.14)
        }

        return Color(uiColor: .secondarySystemBackground)
    }

    private func savedTuningStroke(for tuning: SavedCustomTuning) -> Color {
        if isSavedTuningActive(tuning) {
            return tuningAccent
        }

        return Color(uiColor: .separator)
    }

    private func presentNamingPrompt(_ prompt: TuningNamePrompt, suggestedName: String) {
        tuningNameDraft = suggestedName
        namingPrompt = prompt
    }

    private func isSavedTuningActive(_ tuning: SavedCustomTuning) -> Bool {
        viewModel.isCustomTuningSelected && viewModel.selectedSavedCustomTuning?.id == tuning.id
    }

    private func submitNamingPrompt() {
        guard let namingPrompt else {
            return
        }

        switch namingPrompt {
        case .saveNew:
            viewModel.saveCurrentCustomTuning(named: tuningNameDraft)
        case let .rename(id):
            viewModel.renameCustomTuning(id: id, to: tuningNameDraft)
        case let .duplicate(id):
            viewModel.duplicateCustomTuning(id: id, named: tuningNameDraft)
        }

        self.namingPrompt = nil
    }
}
