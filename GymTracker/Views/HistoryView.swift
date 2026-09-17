import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showingNewWorkout = false
    @State private var sessionToEdit: WorkoutSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No Workouts Yet", systemImage: "dumbbell",
                                            description: Text("Tap + to log your first workout."))
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                WorkoutRow(session: session)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    sessionToEdit = session
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewWorkout = true
                    } label: {
                        Label("New Workout", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewWorkout) {
                NewWorkoutView()
            }
            .sheet(item: $sessionToEdit) { session in
                EditWorkoutView(session: session)
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
        try? context.save()
    }
}

private struct WorkoutRow: View {
    let session: WorkoutSession

    private var exerciseSummary: String {
        let names = Array(Set(session.sets.compactMap { $0.exercise?.name }))
        if names.isEmpty {
            return "No exercises recorded"
        }
        return names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +\(names.count - 3) more" : "")
    }

    private var totalVolume: Double {
        session.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                if totalVolume > 0 {
                    Text("\(totalVolume, specifier: "%.0f") kg")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(exerciseSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Label("\(session.sets.count) set\(session.sets.count == 1 ? "" : "s")", systemImage: "dumbbell.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !session.notes.isEmpty {
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(session.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
