import SwiftUI
import SwiftData

struct EditWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var date: Date
    @State private var notes: String
    @State private var draftSets: [EditableSet] = []
    @State private var showingAddSet = false
    @State private var setBeingEdited: EditableSet?

    struct EditableSet: Identifiable, Equatable {
        let id: UUID
        var existingSet: ExerciseSet?
        var exercise: Exercise
        var reps: Int
        var weight: Double

        init(existingSet: ExerciseSet) {
            self.id = UUID()
            self.existingSet = existingSet
            self.exercise = existingSet.exercise ?? Exercise(name: "Unknown")
            self.reps = existingSet.reps
            self.weight = existingSet.weight
        }

        init(exercise: Exercise, reps: Int, weight: Double) {
            self.id = UUID()
            self.existingSet = nil
            self.exercise = exercise
            self.reps = reps
            self.weight = weight
        }

        static func == (lhs: EditableSet, rhs: EditableSet) -> Bool {
            lhs.id == rhs.id && lhs.reps == rhs.reps && lhs.weight == rhs.weight && lhs.exercise.name == rhs.exercise.name
        }
    }

    init(session: WorkoutSession) {
        self.session = session
        _date = State(initialValue: session.date)
        _notes = State(initialValue: session.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    DatePicker("Date & Time", selection: $date)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    if draftSets.isEmpty {
                        Text("No sets in this workout. Tap \"Add Set\" below.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(draftSets) { draft in
                            Button {
                                setBeingEdited = draft
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(draft.exercise.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(draft.exercise.category)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(draft.reps) reps @ \(draft.weight, specifier: "%.1f") kg")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteDraftSets)
                        .onMove(perform: moveDraftSets)
                    }

                    Button {
                        showingAddSet = true
                    } label: {
                        Label("Add Set", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Sets (\(draftSets.count))")
                        Spacer()
                        if !draftSets.isEmpty {
                            EditButton()
                                .font(.caption)
                        }
                    }
                } footer: {
                    if !draftSets.isEmpty {
                        Text("Tap any set to edit reps, weight, or exercise. Swipe to delete.")
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
            }
            .onAppear {
                loadSessionData()
            }
            .sheet(isPresented: $showingAddSet) {
                AddSetView(exercises: exercises) { exercise, reps, weight in
                    draftSets.append(EditableSet(exercise: exercise, reps: reps, weight: weight))
                }
            }
            .sheet(item: $setBeingEdited) { set in
                EditSingleSetView(draftSet: set, exercises: exercises) { updated in
                    if let index = draftSets.firstIndex(where: { $0.id == updated.id }) {
                        draftSets[index] = updated
                    }
                }
            }
        }
    }

    private func loadSessionData() {
        let sorted = session.sets.sorted(by: { $0.order < $1.order })
        draftSets = sorted.map { EditableSet(existingSet: $0) }
    }

    private func deleteDraftSets(at offsets: IndexSet) {
        draftSets.remove(atOffsets: offsets)
    }

    private func moveDraftSets(from source: IndexSet, to destination: Int) {
        draftSets.move(fromOffsets: source, toOffset: destination)
    }

    private func saveChanges() {
        session.date = date
        session.notes = notes

        // Delete all old sets and recreate with new configuration to guarantee consistent ordering and bindings
        for oldSet in session.sets {
            context.delete(oldSet)
        }
        session.sets.removeAll()

        for (index, draft) in draftSets.enumerated() {
            let newSet = ExerciseSet(
                reps: draft.reps,
                weight: draft.weight,
                order: index,
                exercise: draft.exercise
            )
            newSet.session = session
            context.insert(newSet)
            session.sets.append(newSet)
        }

        try? context.save()
        dismiss()
    }
}

private struct EditSingleSetView: View {
    @State var draftSet: EditWorkoutView.EditableSet
    let exercises: [Exercise]
    var onSave: (EditWorkoutView.EditableSet) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise: Exercise?
    @State private var reps: Int
    @State private var weight: Double

    init(draftSet: EditWorkoutView.EditableSet, exercises: [Exercise], onSave: @escaping (EditWorkoutView.EditableSet) -> Void) {
        self.draftSet = draftSet
        self.exercises = exercises
        self.onSave = onSave
        _reps = State(initialValue: draftSet.reps)
        _weight = State(initialValue: draftSet.weight)
        _selectedExercise = State(initialValue: draftSet.exercise)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(exercises) { exercise in
                        Text(exercise.name).tag(Optional(exercise))
                    }
                }

                Stepper("Reps: \(reps)", value: $reps, in: 1...200)

                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let exercise = selectedExercise {
                            var updated = draftSet
                            updated.exercise = exercise
                            updated.reps = reps
                            updated.weight = weight
                            onSave(updated)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
