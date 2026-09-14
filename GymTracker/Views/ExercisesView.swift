import SwiftUI
import SwiftData
import UIKit

struct ExercisesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var newExerciseName = ""
    @State private var newExerciseGroup: MuscleGroup = .other

    private var groupedExercises: [(group: MuscleGroup, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: exercises, by: \.muscleGroup)
        return MuscleGroup.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("New exercise name", text: $newExerciseName)
                    Picker("Muscle Group", selection: $newExerciseGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Label(group.rawValue, systemImage: group.systemImage).tag(group)
                        }
                    }
                    Button("Add Exercise") { addExercise() }
                        .frame(maxWidth: .infinity)
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if exercises.isEmpty {
                    Section("Your Exercises") {
                        Text("No exercises yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(groupedExercises, id: \.group) { entry in
                        Section {
                            ForEach(entry.exercises) { exercise in
                                NavigationLink(value: exercise) {
                                    HStack(spacing: 12) {
                                        ExerciseThumbnail(exercise: exercise)
                                        Text(exercise.name)
                                    }
                                }
                            }
                            .onDelete { offsets in deleteExercises(entry.exercises, at: offsets) }
                        } header: {
                            Label(entry.group.rawValue, systemImage: entry.group.systemImage)
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
    }

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        context.insert(Exercise(name: trimmed, category: newExerciseGroup.rawValue))
        try? context.save()
        newExerciseName = ""
    }

    private func deleteExercises(_ groupExercises: [Exercise], at offsets: IndexSet) {
        for index in offsets {
            context.delete(groupExercises[index])
        }
        try? context.save()
    }
}

private struct ExerciseThumbnail: View {
    let exercise: Exercise

    var body: some View {
        Group {
            if let latestPhoto = exercise.photos.max(by: { $0.date < $1.date }),
               let uiImage = UIImage(data: latestPhoto.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
