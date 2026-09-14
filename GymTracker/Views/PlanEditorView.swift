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
                                .frame(width: 90, alignment: .leading)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.title)
                                Text(day.exercises.isEmpty ? "Rest day" : "\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Weekly Plan")
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
                TextField("e.g. Push Day, Rest Day", text: $day.title)
                    .onSubmit { try? context.save() }
            }

            Section("Exercises") {
                if day.exercises.isEmpty {
                    Text("No exercises for this day.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedExercises) { exercise in
                        NavigationLink {
                            PlanExerciseEditorView(planExercise: exercise)
                        } label: {
                            HStack {
                                Image(systemName: exercise.muscleGroup.systemImage)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text("\(exercise.muscleGroup.rawValue) • \(exercise.suggestion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                }

                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(day.title.isEmpty ? "Edit Day" : day.title)
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
            Section {
                TextField("Exercise Name", text: $planExercise.name)
                Picker("Muscle Group", selection: muscleGroupBinding) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.systemImage).tag(group)
                    }
                }
                TextField("Suggestion (e.g. 3x8-10)", text: $planExercise.suggestion)
            }

            Section {
                Button("Delete Exercise", role: .destructive) {
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

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .other
    @State private var suggestion = "3x10"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise Name", text: $name)
                Picker("Muscle Group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.rawValue, systemImage: group.systemImage).tag(group)
                    }
                }
                TextField("Suggestion (e.g. 3x8-10)", text: $suggestion)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addExercise() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let order = day.exercises.count
        let exercise = PlanExercise(name: trimmed, suggestion: suggestion, order: order, muscleGroup: muscleGroup, day: day)
        context.insert(exercise)
        try? context.save()
        dismiss()
    }
}
