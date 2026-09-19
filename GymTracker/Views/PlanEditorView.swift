import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var planDays: [PlanDay]

    private var orderedDays: [PlanDay] {
        planDays.sorted { $0.weekday < $1.weekday }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedDays) { day in
                    NavigationLink {
                        PlanDayEditorView(day: day)
                    } label: {
                        HStack {
                            Text(weekdaySymbol(day.weekday))
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 95, alignment: .leading)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.title)
                                    .font(.body.weight(.medium))
                                Text(day.exercises.isEmpty ? "Rest / No exercises" : "\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Weekly Plan")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "Day \(weekday)" }
        return symbols[weekday - 1]
    }
}

struct PlanDayEditorView: View {
    @Bindable var day: PlanDay
    @Environment(\.modelContext) private var context
    @State private var showingAddExercise = false

    private var sortedExercises: [PlanExercise] {
        day.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        Form {
            Section("Day Title") {
                TextField("e.g. Upper Body, Push, Legs", text: $day.title)
                    .onSubmit { try? context.save() }
            }

            Section {
                if day.exercises.isEmpty {
                    Text("No exercises added for this day yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedExercises) { exercise in
                        NavigationLink {
                            PlanExerciseEditorView(planExercise: exercise)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: exercise.muscleGroup.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.body.weight(.medium))
                                    Text("\(exercise.muscleGroup.rawValue) • \(exercise.suggestion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                    .onMove(perform: moveExercises)
                }

                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise to \(day.title)", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
            } header: {
                HStack {
                    Text("Exercises (\(day.exercises.count))")
                    Spacer()
                    if !day.exercises.isEmpty {
                        EditButton()
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(day.title.isEmpty ? "Edit Routine" : day.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddExercise) {
            PlanExerciseFormView(day: day)
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let items = sortedExercises
        for index in offsets {
            context.delete(items[index])
        }
        try? context.save()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var items = sortedExercises
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
        try? context.save()
    }
}

struct PlanExerciseEditorView: View {
    @Bindable var planExercise: PlanExercise
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    private var muscleGroupBinding: Binding<MuscleGroup> {
        Binding(
            get: { planExercise.muscleGroup },
            set: { planExercise.muscleGroup = $0 }
        )
    }

    var body: some View {
        Form {
            Section("Exercise Details") {
                TextField("Exercise Name", text: $planExercise.name)
                Picker("Muscle Group", selection: muscleGroupBinding) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.systemImage).tag(group)
                    }
                }
                TextField("Target Suggestion (e.g. 3x8-10 reps)", text: $planExercise.suggestion)
            }

            Section {
                Button("Delete Exercise from Day", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    try? context.save()
                    dismiss()
                }
            }
        }
        .confirmationDialog("Delete this exercise from the plan?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(planExercise)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct PlanExerciseFormView: View {
    let day: PlanDay
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var catalogExercises: [Exercise]

    @State private var selectedTab: Int = 0 // 0 = Catalog, 1 = Custom
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var customName = ""
    @State private var customGroup: MuscleGroup = .other
    @State private var suggestion = "3 sets • 8-10 reps"

    private var filteredCatalog: [Exercise] {
        catalogExercises.filter { ex in
            let matchesGroup = selectedMuscleGroup == nil || ex.muscleGroup == selectedMuscleGroup
            let matchesSearch = searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText)
            return matchesGroup && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $selectedTab) {
                    Text("Exercise Library").tag(0)
                    Text("New Custom Exercise").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if selectedTab == 0 {
                    catalogPickerView
                } else {
                    customExerciseView
                }
            }
            .navigationTitle("Add to \(day.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Catalog Picker View
    private var catalogPickerView: some View {
        VStack(spacing: 8) {
            // Muscle Group Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        selectedMuscleGroup = nil
                    } label: {
                        Text("All")
                            .font(.caption.weight(selectedMuscleGroup == nil ? .bold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedMuscleGroup == nil ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(selectedMuscleGroup == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(MuscleGroup.allCases) { group in
                        Button {
                            selectedMuscleGroup = selectedMuscleGroup == group ? nil : group
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: group.systemImage)
                                Text(group.rawValue)
                            }
                            .font(.caption.weight(selectedMuscleGroup == group ? .bold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedMuscleGroup == group ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(selectedMuscleGroup == group ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)

            // Suggestion Bar
            HStack {
                Text("Target:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("e.g. 3 sets • 8-10 reps", text: $suggestion)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if catalogExercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                    Text("Your library is empty")
                        .font(.headline)
                    Text("Switch to \"New Custom Exercise\" tab above to create your first exercise.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            } else if filteredCatalog.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .padding(.top, 30)
                Spacer()
            } else {
                List(filteredCatalog) { ex in
                    Button {
                        addFromCatalog(ex)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: ex.muscleGroup.systemImage)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(ex.muscleGroup.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search exercise library")
            }
        }
    }

    // MARK: - Custom Exercise Form View
    private var customExerciseView: some View {
        Form {
            Section("New Exercise") {
                TextField("Exercise Name (e.g. Incline Smith Press)", text: $customName)
                Picker("Muscle Group", selection: $customGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.systemImage).tag(group)
                    }
                }
                TextField("Target Suggestion", text: $suggestion)
            }

            Section {
                Button {
                    addCustomExercise()
                } label: {
                    Label("Add & Save to Routine", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addFromCatalog(_ exercise: Exercise) {
        let order = day.exercises.count
        let planExercise = PlanExercise(
            name: exercise.name,
            suggestion: suggestion.isEmpty ? "3 sets • 8-10 reps" : suggestion,
            order: order,
            muscleGroup: exercise.muscleGroup,
            day: day
        )
        context.insert(planExercise)
        try? context.save()
        dismiss()
    }

    private func addCustomExercise() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Also register into catalog so it appears in library
        let exists = catalogExercises.contains { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        if !exists {
            let newEx = Exercise(name: trimmed, category: customGroup.rawValue)
            context.insert(newEx)
        }

        let order = day.exercises.count
        let planExercise = PlanExercise(
            name: trimmed,
            suggestion: suggestion.isEmpty ? "3 sets • 8-10 reps" : suggestion,
            order: order,
            muscleGroup: customGroup,
            day: day
        )
        context.insert(planExercise)
        try? context.save()
        dismiss()
    }
}
