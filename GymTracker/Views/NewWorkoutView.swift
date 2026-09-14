import SwiftUI
import SwiftData

struct NewWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var date = Date.now
    @State private var notes = ""
    @State private var draftSets: [DraftSet] = []
    @State private var showingAddSet = false

    struct DraftSet: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var reps: Int
        var weight: Double
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    DatePicker("Date", selection: $date)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Sets") {
                    ForEach(draftSets) { set in
                        HStack {
                            Text(set.exercise.name)
                            Spacer()
                            Text("\(set.reps) x \(set.weight, specifier: "%.1f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { draftSets.remove(atOffsets: $0) }

                    if exercises.isEmpty {
                        Text("Add an exercise first in the Exercises tab.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            showingAddSet = true
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("New Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draftSets.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSet) {
                AddSetView(exercises: exercises) { exercise, reps, weight in
                    draftSets.append(DraftSet(exercise: exercise, reps: reps, weight: weight))
                }
            }
        }
    }

    private func save() {
        let session = WorkoutSession(date: date, notes: notes)
        context.insert(session)
        for (index, draft) in draftSets.enumerated() {
            let set = ExerciseSet(reps: draft.reps, weight: draft.weight, order: index, exercise: draft.exercise)
            set.session = session
            context.insert(set)
        }
        dismiss()
    }
}

struct AddSetView: View {
    let exercises: [Exercise]
    var onAdd: (Exercise, Int, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise: Exercise?
    @State private var reps = 10
    @State private var weight = 20.0

    var body: some View {
        NavigationStack {
            Form {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(exercises) { exercise in
                        Text(exercise.name).tag(Optional(exercise))
                    }
                }
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            .navigationTitle("Add Set")
            .onAppear {
                if selectedExercise == nil { selectedExercise = exercises.first }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let selectedExercise {
                            onAdd(selectedExercise, reps, weight)
                        }
                        dismiss()
                    }
                    .disabled(selectedExercise == nil)
                }
            }
        }
    }
}
