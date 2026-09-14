import SwiftUI

struct WorkoutDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            if !session.notes.isEmpty {
                Section("Notes") {
                    Text(session.notes)
                }
            }
            Section("Sets") {
                ForEach(session.sets.sorted(by: { $0.order < $1.order })) { set in
                    HStack {
                        Text(set.exercise?.name ?? "Unknown")
                        Spacer()
                        Text("\(set.reps) reps @ \(set.weight, specifier: "%.1f")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
    }
}
