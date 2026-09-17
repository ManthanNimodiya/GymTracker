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
    @State private var showingNewWorkout = false
    @State private var showingAddExerciseToDay = false
    @State private var selectedDateForDetail: Date?

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: .now) }
    private var todayWeekday: Int { calendar.component(.weekday, from: .now) }

    private var todaysPlan: PlanDay? {
        planDays.first { $0.weekday == todayWeekday }
    }

    private var isRestDay: Bool {
        guard let title = todaysPlan?.title.lowercased() else { return false }
        return title.contains("rest") || title.contains("off")
    }

    private var tomorrowsPlan: PlanDay? {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let weekday = calendar.component(.weekday, from: tomorrow)
        return planDays.first { $0.weekday == weekday }
    }

    private var todaysCheckIn: DayCheckIn? {
        checkIn(for: today)
    }

    private var todaysSessions: [WorkoutSession] {
        sessions.filter { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var todaysCompletedSetsCount: Int {
        todaysSessions.flatMap(\.sets).count
    }

    private var last7Days: [Date] {
        (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: 1. Top Section - Dates Carousel / Strip
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(last7Days, id: \.self) { date in
                                    Button {
                                        selectedDateForDetail = date
                                    } label: {
                                        DayChip(
                                            date: date,
                                            checkIn: checkIn(for: date),
                                            isToday: calendar.isDate(date, inSameDayAs: today),
                                            hasWorkout: sessions.contains { calendar.isDate($0.date, inSameDayAs: date) }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }

                        // Compact Auto Step Bar
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 24, height: 24)
                                Image(systemName: "figure.walk")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.accentColor)
                            }

                            if let steps = stepTracker.todaySteps {
                                Text("\(steps.formatted()) steps today")
                                    .font(.caption.weight(.semibold))
                            } else if stepTracker.isAvailable {
                                Text("Live step sync active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Step counter active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if todaysCompletedSetsCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "dumbbell.fill")
                                    Text("\(todaysCompletedSetsCount) sets logged")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // MARK: 2. Heading of the Day with Tick / Cross Status Actions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Text(todaysPlan?.title ?? "No Routine Set")
                                    .font(.title2.bold())
                            }

                            Spacer()

                            // Status Actions: Tick (Done) and Cross (Skip)
                            HStack(spacing: 12) {
                                // Skip Button (✕)
                                Button {
                                    handleSkipTap()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(todaysCheckIn?.status == "skipped" ? Color.red : Color.red.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "xmark")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(todaysCheckIn?.status == "skipped" ? .white : .red)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Skip Today's Workout")

                                // Done Button (✓)
                                Button {
                                    handleDoneTap()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(todaysCheckIn?.status == "done" ? Color.green : Color.green.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(todaysCheckIn?.status == "done" ? .white : .green)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Mark Today as Done")
                            }
                        }

                        // Status Banner
                        if let checkIn = todaysCheckIn, !checkIn.status.isEmpty {
                            statusBanner(for: checkIn)
                        }
                    }
                    .padding(16)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // MARK: 3. Exercises Listed Below Heading
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today's Exercises")
                                .font(.headline)
                            Spacer()

                            if let plan = todaysPlan {
                                Button {
                                    showingAddExerciseToDay = true
                                } label: {
                                    Label("Add", systemImage: "plus.circle.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if isRestDay {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Rest & Recovery", systemImage: "bed.double.fill")
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                                Text("Scheduled rest day. Prioritize hydration, mobility, and nutrition for muscle rebuilding.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        } else if let todaysPlan, !todaysPlan.exercises.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(todaysPlan.exercises.sorted(by: { $0.order < $1.order })) { planExercise in
                                    let completedSets = setsLoggedToday(for: planExercise.name)
                                    PlanExerciseRow(
                                        planExercise: planExercise,
                                        completedCountToday: completedSets
                                    ) { reps, weight in
                                        logSet(exerciseName: planExercise.name, group: planExercise.muscleGroup, reps: reps, weight: weight)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Clean Empty State Card
                            VStack(spacing: 12) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.accentColor.opacity(0.8))
                                    .padding(.top, 6)

                                VStack(spacing: 4) {
                                    Text("No Exercises Added for \(todaysPlan?.title ?? "Today")")
                                        .font(.subheadline.bold())
                                    Text("Tap below to add the exercises you want to perform in this workout.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }

                                Button {
                                    showingAddExerciseToDay = true
                                } label: {
                                    Label("Add Exercise", systemImage: "plus.circle.fill")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 6)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }

                    // MARK: 4. Quick Workout Logger
                    Button {
                        showingNewWorkout = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Log Freeform Workout")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.08))
                        .foregroundStyle(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // MARK: 5. Tomorrow's Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tomorrow's Split")
                            .font(.headline)
                            .padding(.horizontal)

                        if let tomorrowsPlan {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tomorrowsPlan.title)
                                    .font(.subheadline.bold())
                                if tomorrowsPlan.exercises.isEmpty {
                                    Text("No exercises added yet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(tomorrowsPlan.exercises.sorted(by: { $0.order < $1.order })) { ex in
                                        HStack {
                                            Text("• \(ex.name)")
                                                .font(.caption)
                                            Spacer()
                                            if !ex.suggestion.isEmpty {
                                                Text(ex.suggestion)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        } else {
                            Text("No plan set for tomorrow.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical)
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPlanEditor = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .animation(.snappy, value: todaysCheckIn?.status)
            .sensoryFeedback(.selection, trigger: todaysCheckIn?.status)
            .task {
                seedDefaultPlanIfNeeded()
                stepTracker.start()
            }
            .alert("Reason for skipping today?", isPresented: $showingSkipReasonPrompt) {
                TextField("e.g. Rest day, busy, sick", text: $skipReasonDraft)
                Button("Save") { confirmSkip() }
                Button("Cancel", role: .cancel) { skipReasonDraft = "" }
            }
            .sheet(isPresented: $showingPlanEditor) {
                PlanEditorView()
            }
            .sheet(isPresented: $showingNewWorkout) {
                NewWorkoutView()
            }
            .sheet(isPresented: $showingAddExerciseToDay) {
                if let todaysPlan {
                    PlanExerciseFormView(day: todaysPlan)
                }
            }
            .sheet(item: Binding(
                get: { selectedDateForDetail.map { IdentifiableDate(date: $0) } },
                set: { selectedDateForDetail = $0?.date }
            )) { identifiable in
                DayProgressView(date: identifiable.date)
            }
        }
    }

    // MARK: - Status Banner View
    @ViewBuilder
    private func statusBanner(for checkIn: DayCheckIn) -> some View {
        if checkIn.status == "done" {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                Text("Workout Done! Great work today.")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Spacer()
                Button("Clear") {
                    setStatus("", reason: "")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if checkIn.status == "skipped" {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Skipped for today")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    if !checkIn.reason.isEmpty {
                        Text("Reason: \(checkIn.reason)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Clear") {
                    setStatus("", reason: "")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func handleDoneTap() {
        if todaysCheckIn?.status == "done" {
            setStatus("", reason: "")
        } else {
            setStatus("done", reason: "")
        }
    }

    private func handleSkipTap() {
        if todaysCheckIn?.status == "skipped" {
            setStatus("", reason: "")
        } else {
            skipReasonDraft = ""
            showingSkipReasonPrompt = true
        }
    }

    private func confirmSkip() {
        setStatus("skipped", reason: skipReasonDraft.trimmingCharacters(in: .whitespaces))
        skipReasonDraft = ""
    }

    private func setStatus(_ status: String, reason: String) {
        if let existing = todaysCheckIn {
            existing.status = status
            existing.reason = reason
        } else {
            context.insert(DayCheckIn(date: today, status: status, reason: reason))
        }
        try? context.save()
    }

    private func checkIn(for date: Date) -> DayCheckIn? {
        checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func setsLoggedToday(for exerciseName: String) -> Int {
        todaysSessions.flatMap(\.sets).filter {
            $0.exercise?.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame
        }.count
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
        let key = "didCleanUserExercises_v4"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            for planExercise in planDays.flatMap(\.exercises) {
                context.delete(planExercise)
            }
            for day in planDays {
                context.delete(day)
            }
            try? context.save()

            // Seed user's 7-day routine titles without forced dummy exercises
            let scheduleTitles: [(weekday: Int, title: String)] = [
                (2, "Upper Body"),
                (3, "Lower Body"),
                (4, "Deadlifts Abs"),
                (5, "Push"),
                (6, "Pull"),
                (7, "Legs"),
                (1, "Deadlifts Abs")
            ]

            for entry in scheduleTitles {
                let planDay = PlanDay(weekday: entry.weekday, title: entry.title)
                context.insert(planDay)
            }
            try? context.save()
            return
        }

        guard planDays.isEmpty else { return }
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct DayChip: View {
    let date: Date
    let checkIn: DayCheckIn?
    let isToday: Bool
    let hasWorkout: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.medium))
                .foregroundStyle(isToday ? Color.accentColor : .secondary)

            Text(date.formatted(.dateTime.day()))
                .font(.subheadline.weight(isToday ? .bold : .semibold))
                .foregroundStyle(isToday ? Color.accentColor : .primary)

            ZStack {
                if let status = checkIn?.status, !status.isEmpty {
                    if status == "done" {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                    } else if status == "skipped" {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                    }
                } else if hasWorkout {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(height: 16)
        }
        .frame(width: 48, height: 72)
        .background(isToday ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isToday ? Color.accentColor : Color.secondary.opacity(0.12), lineWidth: isToday ? 2 : 1)
        )
    }
}

private struct PlanExerciseRow: View {
    let planExercise: PlanExercise
    var completedCountToday: Int
    var onLog: (Int, Double) -> Void

    @State private var isExpanded = false
    @State private var reps = 10
    @State private var weight = 20.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: planExercise.muscleGroup.systemImage)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(planExercise.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            if completedCountToday > 0 {
                                Text("\(completedCountToday) logged")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.18))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }

                        Text("\(planExercise.muscleGroup.rawValue) • \(planExercise.suggestion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    Divider()

                    // Reps and Weight Steppers
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reps: \(reps)")
                                .font(.subheadline.bold())
                            Stepper("", value: $reps, in: 1...200)
                                .labelsHidden()
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Weight: \(weight, specifier: "%.1f") kg")
                                .font(.subheadline.bold())
                            HStack(spacing: 6) {
                                Button("-2.5") { if weight >= 2.5 { weight -= 2.5 } }
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Button("+2.5") { weight += 2.5 }
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Button("+5") { weight += 5 }
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    Button {
                        onLog(reps, weight)
                        withAnimation(.snappy) { isExpanded = false }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log Set (\(reps) reps @ \(weight, specifier: "%.1f") kg)")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
