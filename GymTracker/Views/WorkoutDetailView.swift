import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private var totalVolume: Double {
        session.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
    }

    private var totalReps: Int {
        session.sets.reduce(0) { $0 + $1.reps }
    }

    var body: some View {
        List {
            Section("Summary") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Volume")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(totalVolume, specifier: "%.1f") kg")
                            .font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 4) {
                        Text("Sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(session.sets.count)")
                            .font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(totalReps)")
                            .font(.headline)
                    }
                }
                .padding(.vertical, 4)
            }

            if !session.notes.isEmpty {
                Section("Notes") {
                    Text(session.notes)
                        .font(.body)
                }
            }

            Section {
                if session.sets.isEmpty {
                    Text("No sets logged in this session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.sets.sorted(by: { $0.order < $1.order })) { set in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(set.exercise?.name ?? "Unknown Exercise")
                                    .font(.body.weight(.medium))
                                if let group = set.exercise?.muscleGroup {
                                    Text(group.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(set.reps) reps @ \(set.weight, specifier: "%.1f") kg")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Sets (\(session.sets.count))")
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWorkoutView(session: session)
        }
        .confirmationDialog(
            "Delete this workout session?",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
