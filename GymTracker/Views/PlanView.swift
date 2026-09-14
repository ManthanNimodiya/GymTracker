import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query private var planDays: [PlanDay]
    @Query private var checkIns: [DayCheckIn]
    @Query(sort: \Exercise.name) private var catalogExercises: [Exercise]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var stepTracker = StepTracker()
    @State private var showingSkipReasonPrompt = false
    @State private var skipReasonDraft = ""
    @State private var showingPlanEditor = false
    @State private var forceShowStatusButtons = false

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: .now) }
    private var todayWeekday: Int { calendar.component(.weekday, from: .now) }

    private var todaysPlan: PlanDay? {
        planDays.first { $0.weekday == todayWeekday }
    }

    private var tomorrowsPlan: PlanDay? {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let weekday = calendar.component(.weekday, from: tomorrow)
        return planDays.first { $0.weekday == weekday }
    }

    private var todaysCheckIn: DayCheckIn? {
        checkIn(for: today)
    }

    private var last7Days: [Date] {
        (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if todaysCheckIn?.status == "done" {
                            Text("Tomorrow's Goal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(tomorrowsPlan?.title ?? "No Plan Set")
                                .font(.title2.bold())
                        } else {
                            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(todaysPlan?.title ?? "No Plan Set")
                                .font(.title2.bold())
                        }
                    }
                    .padding(.vertical, 4)

                    if shouldShowStatusButtons {
                        HStack(spacing: 8) {
                            statusButton(title: "Skip", systemImage: "xmark.circle.fill", status: "skipped")
                            statusButton(title: "On My Way", systemImage: "figure.walk", status: "onMyWay")
                            statusButton(title: "Done", systemImage: "checkmark.circle.fill", status: "done")
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            withAnimation(.snappy) { forceShowStatusButtons = true }
                        } label: {
                            HStack {
                                if let statusMessage {
                                    Text(statusMessage)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Change")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .buttonStyle(.borderless)
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk.motion")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Steps")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let steps = stepTracker.todaySteps {
                                Text(steps.formatted())
                                    .font(.title2.bold())
                            } else if stepTracker.hasStarted && !stepTracker.isAvailable {
                                Text("Not available on this device")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else if stepTracker.hasStarted {
                                Text("—")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Tap Enable to allow access")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()

                        if !stepTracker.hasStarted {
                            Button("Enable") {
                                stepTracker.start()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("This Week") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(last7Days, id: \.self) { date in
                                DayChip(
                                    date: date,
                                    checkIn: checkIn(for: date),
                                    isToday: calendar.isDate(date, inSameDayAs: today)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if let todaysPlan, !todaysPlan.exercises.isEmpty {
                    Section("Today's Exercises") {
                        ForEach(todaysPlan.exercises.sorted(by: { $0.order < $1.order })) { planExercise in
                            PlanExerciseRow(planExercise: planExercise) { reps, weight in
                                logSet(exerciseName: planExercise.name, group: planExercise.muscleGroup, reps: reps, weight: weight)
                            }
                        }
                    }
                } else {
                    Section {
                        Text(todaysPlan == nil ? "No plan set for today." : "No exercises added yet. Tap the pencil icon to add some.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tomorrow") {
                    if let tomorrowsPlan {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tomorrowsPlan.title)
                                .font(.headline)
                            if tomorrowsPlan.exercises.isEmpty {
                                Text("No exercises added yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(tomorrowsPlan.exercises.sorted(by: { $0.order < $1.order })) { ex in
                                    Text("• \(ex.name) — \(ex.suggestion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    } else {
                        Text("No plan set for tomorrow.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPlanEditor = true
                    } label: {
                        Label("Edit Plan", systemImage: "pencil")
                    }
                }
            }
            .animation(.snappy, value: todaysCheckIn?.status)
            .sensoryFeedback(.selection, trigger: todaysCheckIn?.status)
            .task {
                seedDefaultPlanIfNeeded()
            }
            .alert("Why are you skipping today?", isPresented: $showingSkipReasonPrompt) {
                TextField("Reason (optional)", text: $skipReasonDraft)
                Button("Save") { confirmSkip() }
                Button("Cancel", role: .cancel) { skipReasonDraft = "" }
            }
            .sheet(isPresented: $showingPlanEditor) {
                PlanEditorView()
            }
        }
    }

    private func checkIn(for date: Date) -> DayCheckIn? {
        checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var shouldShowStatusButtons: Bool {
        forceShowStatusButtons || todaysCheckIn == nil || todaysCheckIn?.status.isEmpty == true
    }

    private var statusMessage: String? {
        guard let todaysCheckIn, !todaysCheckIn.status.isEmpty else { return nil }
        switch todaysCheckIn.status {
        case "skipped":
            return todaysCheckIn.reason.isEmpty ? "Skipped for today." : "Skipped: \(todaysCheckIn.reason)"
        case "onMyWay":
            return "Nice — have a great session at the gym."
        case "done":
            return "Logged as done. Great work today."
        default:
            return nil
        }
    }

    private func statusButton(title: String, systemImage: String, status: String) -> some View {
        let isSelected = todaysCheckIn?.status == status
        return Button {
            handleStatusTap(status)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }

    private func handleStatusTap(_ status: String) {
        if status == "skipped" {
            if todaysCheckIn?.status == "skipped" {
                setStatus("skipped", reason: "") // tapping again toggles off
            } else {
                skipReasonDraft = ""
                showingSkipReasonPrompt = true
                return // wait for the alert's Save/Cancel before collapsing
            }
        } else {
            setStatus(status, reason: "")
        }
        forceShowStatusButtons = false
    }

    private func confirmSkip() {
        setStatus("skipped", reason: skipReasonDraft.trimmingCharacters(in: .whitespaces))
        skipReasonDraft = ""
        forceShowStatusButtons = false
    }

    private func setStatus(_ status: String, reason: String) {
        if let existing = todaysCheckIn {
            if existing.status == status {
                existing.status = ""
                existing.reason = ""
            } else {
                existing.status = status
                existing.reason = reason
            }
        } else {
            context.insert(DayCheckIn(date: today, status: status, reason: reason))
        }
        try? context.save()
    }

    private func findOrCreateExercise(named exerciseName: String, group: MuscleGroup = .other) -> Exercise {
        if let existing = catalogExercises.first(where: {
            $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame
        }) {
            return existing
        }
        let new = Exercise(name: exerciseName, category: group.rawValue)
        context.insert(new)
        return new
    }

    private func logSet(exerciseName: String, group: MuscleGroup, reps: Int, weight: Double) {
        let exercise = findOrCreateExercise(named: exerciseName, group: group)

        let session = sessions.first { calendar.isDate($0.date, inSameDayAs: today) } ?? {
            let new = WorkoutSession(date: .now)
            context.insert(new)
            return new
        }()

        let order = session.sets.count
        let set = ExerciseSet(reps: reps, weight: weight, order: order, exercise: exercise)
        set.session = session
        context.insert(set)
        try? context.save()
    }

    private func seedDefaultPlanIfNeeded() {
        clearSeedExercisesIfNeeded()
        guard planDays.isEmpty else { return }
        let template: [(weekday: Int, title: String)] = [
            (1, "Rest Day"),
            (2, "Push Day"),
            (3, "Pull Day"),
            (4, "Leg Day"),
            (5, "Push Day"),
            (6, "Pull Day"),
            (7, "Leg Day")
        ]
        for entry in template {
            context.insert(PlanDay(weekday: entry.weekday, title: entry.title))
        }
        try? context.save()
    }

    /// One-time cleanup for installs that already got the old hardcoded exercise seed data —
    /// wipes it so the user can build their own list from scratch. Runs once per install.
    private func clearSeedExercisesIfNeeded() {
        let key = "didClearSeedExercises_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        for planExercise in planDays.flatMap(\.exercises) {
            context.delete(planExercise)
        }
        for exercise in catalogExercises {
            context.delete(exercise)
        }
        try? context.save()
    }
}

private struct DayChip: View {
    let date: Date
    let checkIn: DayCheckIn?
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(date.formatted(.dateTime.day()))
                .font(.subheadline.weight(isToday ? .bold : .regular))
            Image(systemName: statusIcon)
                .font(.callout)
                .foregroundStyle(statusColor)
        }
        .frame(width: 46, height: 74)
        .background(isToday ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isToday ? Color.accentColor : .clear, lineWidth: 1.5)
        )
    }

    private var statusIcon: String {
        switch checkIn?.status {
        case "done": return "checkmark.circle.fill"
        case "skipped": return "xmark.circle.fill"
        case "onMyWay": return "figure.walk"
        default: return "circle.dashed"
        }
    }

    private var statusColor: Color {
        switch checkIn?.status {
        case "done": return .green
        case "skipped": return .red
        case "onMyWay": return .blue
        default: return .secondary
        }
    }
}

private struct PlanExerciseRow: View {
    let planExercise: PlanExercise
    var onLog: (Int, Double) -> Void

    @State private var isExpanded = false
    @State private var reps = 10
    @State private var weight = 20.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: planExercise.muscleGroup.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planExercise.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("\(planExercise.muscleGroup.rawValue) • \(planExercise.suggestion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())

            if isExpanded {
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Button {
                    onLog(reps, weight)
                    withAnimation(.snappy) { isExpanded = false }
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
        .animation(.snappy, value: isExpanded)
    }
}
