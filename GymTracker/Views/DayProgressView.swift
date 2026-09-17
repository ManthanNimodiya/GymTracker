import SwiftUI
import SwiftData

struct DayProgressView: View {
    let date: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var planDays: [PlanDay]
    @Query private var checkIns: [DayCheckIn]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]

    @State private var showingNewWorkoutForDay = false
    @State private var sessionToEdit: WorkoutSession?
    @State private var showingSkipAlert = false
    @State private var skipReason = ""

    private var calendar: Calendar { .current }
    private var isToday: Bool { calendar.isDateInToday(date) }

    private var weekday: Int {
        calendar.component(.weekday, from: date)
    }

    private var scheduledPlan: PlanDay? {
        planDays.first { $0.weekday == weekday }
    }

    private var checkIn: DayCheckIn? {
        checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var daySessions: [WorkoutSession] {
        allSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var totalSetsForDay: Int {
        daySessions.flatMap(\.sets).count
    }

    private var totalVolumeForDay: Double {
        daySessions.flatMap(\.sets).reduce(0) { $0 + (Double($1.reps) * $1.weight) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(date.formatted(.dateTime.weekday(.wide).month().day().year()))
                                .font(.headline)
                            Spacer()
                            if isToday {
                                Text("TODAY")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 8) {
                            statusBadge
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)

                    // Simplified Status Action (Skip / Done)
                    HStack(spacing: 12) {
                        Button {
                            if checkIn?.status == "skipped" {
                                setCheckInStatus("", reason: "")
                            } else {
                                skipReason = ""
                                showingSkipAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Skip")
                            }
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(checkIn?.status == "skipped" ? Color.red : Color.red.opacity(0.1))
                            .foregroundStyle(checkIn?.status == "skipped" ? .white : .red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.borderless)

                        Button {
                            if checkIn?.status == "done" {
                                setCheckInStatus("", reason: "")
                            } else {
                                setCheckInStatus("done", reason: "")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Done")
                            }
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(checkIn?.status == "done" ? Color.green : Color.green.opacity(0.1))
                            .foregroundStyle(checkIn?.status == "done" ? .white : .green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }

                Section("Scheduled Routine") {
                    if let scheduledPlan {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(scheduledPlan.title)
                                    .font(.headline)
                                Spacer()
                            }

                            if scheduledPlan.exercises.isEmpty {
                                Text("No specific exercises set for this day.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(scheduledPlan.exercises.sorted(by: { $0.order < $1.order })) { ex in
                                    HStack(spacing: 8) {
                                        Image(systemName: ex.muscleGroup.systemImage)
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(ex.name)
                                                .font(.subheadline.weight(.medium))
                                            if !ex.suggestion.isEmpty {
                                                Text("\(ex.muscleGroup.rawValue) • \(ex.suggestion)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    } else {
                        Text("No workout plan set for this weekday.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if daySessions.isEmpty {
                        VStack(spacing: 12) {
                            Text("No workouts recorded on this day.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                showingNewWorkoutForDay = true
                            } label: {
                                Label("Log Workout for this Date", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Volume")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(totalVolumeForDay, specifier: "%.1f") kg")
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Total Sets")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(totalSetsForDay)")
                                    .font(.subheadline.bold())
                            }
                        }
                        .padding(.vertical, 2)

                        ForEach(daySessions) { session in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(session.date.formatted(date: .omitted, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button {
                                        sessionToEdit = session
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }

                                if !session.notes.isEmpty {
                                    Text(session.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                ForEach(session.sets.sorted(by: { $0.order < $1.order })) { set in
                                    HStack {
                                        Text(set.exercise?.name ?? "Exercise")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(set.reps) reps @ \(set.weight, specifier: "%.1f") kg")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            showingNewWorkoutForDay = true
                        } label: {
                            Label("Add Another Session", systemImage: "plus")
                                .font(.footnote)
                        }
                    }
                } header: {
                    Text("Logged Workouts (\(daySessions.count))")
                }
            }
            .navigationTitle("Day Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reason for skipping?", isPresented: $showingSkipAlert) {
                TextField("e.g. Rest day, busy, feeling sick", text: $skipReason)
                Button("Save") {
                    setCheckInStatus("skipped", reason: skipReason)
                    skipReason = ""
                }
                Button("Cancel", role: .cancel) { skipReason = "" }
            }
            .sheet(isPresented: $showingNewWorkoutForDay) {
                NewWorkoutForDateView(initialDate: date)
            }
            .sheet(item: $sessionToEdit) { session in
                EditWorkoutView(session: session)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let checkIn, !checkIn.status.isEmpty {
            switch checkIn.status {
            case "done":
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Completed Workout")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            case "skipped":
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Skipped for the day")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    if !checkIn.reason.isEmpty {
                        Text("Reason: \(checkIn.reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            default:
                Label("No check-in", systemImage: "circle.dashed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("No check-in recorded", systemImage: "circle.dashed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func setCheckInStatus(_ status: String, reason: String) {
        if let existing = checkIn {
            existing.status = status
            existing.reason = reason
        } else {
            let newCheckIn = DayCheckIn(date: date, status: status, reason: reason)
            context.insert(newCheckIn)
        }
        try? context.save()
    }
}

private struct NewWorkoutForDateView: View {
    let initialDate: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var date: Date
    @State private var notes = ""
    @State private var draftSets: [NewWorkoutView.DraftSet] = []
    @State private var showingAddSet = false

    init(initialDate: Date) {
        self.initialDate = initialDate
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    DatePicker("Date & Time", selection: $date)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Sets") {
                    ForEach(draftSets) { set in
                        HStack {
                            Text(set.exercise.name)
                            Spacer()
                            Text("\(set.reps) reps @ \(set.weight, specifier: "%.1f") kg")
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
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
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
                    draftSets.append(NewWorkoutView.DraftSet(exercise: exercise, reps: reps, weight: weight))
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
        try? context.save()
        dismiss()
    }
}
