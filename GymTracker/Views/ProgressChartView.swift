import SwiftUI
import SwiftData
import Charts

private struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
}

struct ProgressChartView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allSets: [ExerciseSet]
    @State private var selectedExercise: Exercise?

    var body: some View {
        NavigationStack {
            VStack {
                if exercises.isEmpty {
                    ContentUnavailableView("No Exercises Yet", systemImage: "chart.line.uptrend.xyaxis",
                                            description: Text("Add exercises and log workouts to see progress."))
                } else {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(exercises) { exercise in
                            Text(exercise.name).tag(Optional(exercise))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)

                    if let selectedExercise, !points(for: selectedExercise).isEmpty {
                        Chart(points(for: selectedExercise)) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Max Weight", point.maxWeight))
                            PointMark(x: .value("Date", point.date), y: .value("Max Weight", point.maxWeight))
                        }
                        .frame(height: 260)
                        .padding()
                    } else {
                        ContentUnavailableView("No Data Yet", systemImage: "chart.line.uptrend.xyaxis",
                                                description: Text("Log a workout with this exercise to see progress."))
                    }
                    Spacer()
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                if selectedExercise == nil { selectedExercise = exercises.first }
            }
        }
    }

    private func points(for exercise: Exercise) -> [ProgressPoint] {
        let filtered = allSets.filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
        let grouped = Dictionary(grouping: filtered) { $0.session?.date ?? .distantPast }
        return grouped
            .map { date, sets in ProgressPoint(date: date, maxWeight: sets.map(\.weight).max() ?? 0) }
            .sorted { $0.date < $1.date }
    }
}
