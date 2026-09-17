import SwiftUI
import SwiftData
import UIKit

struct ExercisesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allSets: [ExerciseSet]

    @State private var selectedGroup: MuscleGroup?
    @State private var searchText = ""
    @State private var showingAddExerciseSheet = false
    @State private var exerciseToDelete: Exercise?
    @State private var showingDeleteAlert = false

    private var filteredExercises: [Exercise] {
        exercises.filter { exercise in
            let matchesGroup = selectedGroup == nil || exercise.muscleGroup == selectedGroup
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText) || exercise.category.localizedCaseInsensitiveContains(searchText)
            return matchesGroup && matchesSearch
        }
    }

    private var groupedExercises: [(group: MuscleGroup, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises, by: \.muscleGroup)
        let relevantGroups = selectedGroup == nil ? MuscleGroup.allCases : [selectedGroup!]
        return relevantGroups.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Muscle Group Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All",
                                icon: "square.grid.2x2.fill",
                                isSelected: selectedGroup == nil
                            ) {
                                withAnimation(.snappy) { selectedGroup = nil }
                            }

                            ForEach(MuscleGroup.allCases) { group in
                                FilterChip(
                                    title: group.rawValue,
                                    icon: group.systemImage,
                                    isSelected: selectedGroup == group
                                ) {
                                    withAnimation(.snappy) {
                                        selectedGroup = selectedGroup == group ? nil : group
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }

                    // MARK: - Exercises List / Empty State
                    if exercises.isEmpty {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.top, 40)

                            VStack(spacing: 6) {
                                Text("No Exercises Added Yet")
                                    .font(.title3.bold())
                                Text("Add exercises you perform to start tracking your sets, max weight, and progress photos.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }

                            Button {
                                showingAddExerciseSheet = true
                            } label: {
                                Label("Add Your First Exercise", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: 260)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                    } else if filteredExercises.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 18) {
                            ForEach(groupedExercises, id: \.group) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Section Header
                                    HStack(spacing: 6) {
                                        Image(systemName: entry.group.systemImage)
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.accentColor)
                                        Text(entry.group.rawValue.uppercased())
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(entry.exercises.count)")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal)

                                    // Exercise Cards
                                    ForEach(entry.exercises) { exercise in
                                        NavigationLink(value: exercise) {
                                            ExerciseCard(
                                                exercise: exercise,
                                                maxWeight: maxWeight(for: exercise),
                                                totalSets: totalSetsCount(for: exercise)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                exerciseToDelete = exercise
                                                showingDeleteAlert = true
                                            } label: {
                                                Label("Delete Exercise", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search exercises or muscle groups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddExerciseSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddExerciseSheet) {
                AddCustomExerciseView(preselectedGroup: selectedGroup ?? .other)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .confirmationDialog(
                "Delete \(exerciseToDelete?.name ?? "this exercise")?",
                isPresented: $showingDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("Delete Exercise", role: .destructive) {
                    if let ex = exerciseToDelete {
                        context.delete(ex)
                        try? context.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func maxWeight(for exercise: Exercise) -> Double? {
        let sets = allSets.filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
        return sets.map(\.weight).max()
    }

    private func totalSetsCount(for exercise: Exercise) -> Int {
        allSets.filter { $0.exercise?.persistentModelID == exercise.persistentModelID }.count
    }
}

// MARK: - Exercise Card
private struct ExerciseCard: View {
    let exercise: Exercise
    let maxWeight: Double?
    let totalSets: Int

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail / Icon
            ZStack {
                if let photo = exercise.photos.max(by: { $0.date < $1.date }),
                   let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: exercise.muscleGroup.systemImage)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(exercise.muscleGroup.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if exercise.photos.count > 0 {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Label("\(exercise.photos.count)", systemImage: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let max = maxWeight, max > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(max, specifier: "%.1f") kg")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("PR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Filter Chip
private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Custom Exercise Sheet
private struct AddCustomExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: MuscleGroup

    init(preselectedGroup: MuscleGroup) {
        _category = State(initialValue: preselectedGroup)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name (e.g. Incline DB Press)", text: $name)

                    Picker("Muscle Group", selection: $category) {
                        ForEach(MuscleGroup.allCases) { group in
                            Label(group.rawValue, systemImage: group.systemImage).tag(group)
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        context.insert(Exercise(name: trimmed, category: category.rawValue))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
