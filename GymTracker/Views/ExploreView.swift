import SwiftUI
import SwiftData

struct ExploreView: View {
    @Environment(\.modelContext) private var context
    @Query private var currentPlanDays: [PlanDay]
    @Query private var currentExercises: [PlanExercise]

    @State private var selectedSplit: NippardSplitTemplate?
    @State private var showingApplyConfirmation = false
    @State private var splitToApply: NippardSplitTemplate?
    @State private var showSuccessBanner = false
    @State private var appliedSplitTitle = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Science-Based Programs", systemImage: "sparkles")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                        }

                        Text("Jeff Nippard Split Planner")
                            .font(.title.bold())

                        Text("Evidence-based workout splits optimized for hypertrophy, progressive overload, and muscle recovery.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Success Feedback Toast
                    if showSuccessBanner {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Split Applied Successfully!")
                                    .font(.subheadline.bold())
                                Text("\(appliedSplitTitle) is now your active weekly routine.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Curated Splits List
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recommended Splits")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(NippardSplitTemplate.allSplits) { split in
                            SplitCardView(split: split) {
                                splitToApply = split
                                showingApplyConfirmation = true
                            } onInspect: {
                                selectedSplit = split
                            }
                        }
                    }

                    // Science & Training Rules
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hypertrophy Principles")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 10) {
                            PrincipleRow(
                                title: "Reps in Reserve (1-2 RIR)",
                                icon: "flame.fill",
                                color: .orange,
                                description: "Take working sets to 1-2 reps shy of technical failure for maximal motor unit recruitment with manageable fatigue."
                            )
                            PrincipleRow(
                                title: "Stretch-Mediated Hypertrophy",
                                icon: "arrow.up.and.down.and.sparkles",
                                color: .indigo,
                                description: "Emphasize loaded stretch positions (e.g. Incline DB Curls, Overhead Triceps, Deep Squats, RDLs) for enhanced growth."
                            )
                            PrincipleRow(
                                title: "Weekly Volume & Frequency",
                                icon: "calendar.badge.clock",
                                color: .blue,
                                description: "Hit each muscle 2x per week with 10-20 hard sets weekly, spread across 3-6 sessions."
                            )
                            PrincipleRow(
                                title: "Progressive Overload",
                                icon: "chart.line.uptrend.xyaxis",
                                color: .green,
                                description: "Add 1 rep or small weight increments over time. Track max weights on the Progress tab."
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("Splits")
            .sheet(item: $selectedSplit) { split in
                SplitDetailView(split: split) {
                    splitToApply = split
                    showingApplyConfirmation = true
                }
            }
            .confirmationDialog(
                "Apply \(splitToApply?.name ?? "this split") to your weekly plan? This will replace your current routine schedule.",
                isPresented: $showingApplyConfirmation,
                titleVisibility: .visible
            ) {
                Button("Apply to My Plan", role: .none) {
                    if let split = splitToApply {
                        applySplit(split)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func applySplit(_ split: NippardSplitTemplate) {
        // Clear old plan exercises and days
        for ex in currentExercises {
            context.delete(ex)
        }
        for day in currentPlanDays {
            context.delete(day)
        }

        // Insert new split schedule
        for dayTemplate in split.days {
            let planDay = PlanDay(weekday: dayTemplate.weekday, title: dayTemplate.title)
            context.insert(planDay)

            for (index, exTemplate) in dayTemplate.exercises.enumerated() {
                let planExercise = PlanExercise(
                    name: exTemplate.name,
                    suggestion: exTemplate.suggestion,
                    order: index,
                    muscleGroup: exTemplate.muscleGroup,
                    day: planDay
                )
                context.insert(planExercise)
            }
        }

        try? context.save()

        appliedSplitTitle = split.name
        withAnimation(.spring) {
            showSuccessBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation {
                showSuccessBanner = false
            }
        }
    }
}

// MARK: - Split Card View
private struct SplitCardView: View {
    let split: NippardSplitTemplate
    var onApply: () -> Void
    var onInspect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(split.name)
                        .font(.title3.bold())
                    Text(split.frequency)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Text(split.experience)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(split.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Day badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(split.days) { day in
                        HStack(spacing: 4) {
                            Text(day.weekdayShort)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Text(day.title)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    onInspect()
                } label: {
                    Text("View Routine")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    onApply()
                } label: {
                    Label("Apply to Plan", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Split Detail Modal View
private struct SplitDetailView: View {
    let split: NippardSplitTemplate
    var onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(split.name)
                            .font(.title2.bold())
                        Text(split.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Label(split.frequency, systemImage: "calendar")
                            Label(split.experience, systemImage: "figure.strengthtraining.traditional")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }

                ForEach(split.days) { day in
                    Section("\(day.weekdayName) — \(day.title)") {
                        if day.exercises.isEmpty {
                            Text("Rest & Recovery. Prioritize nutrition and active recovery walk.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(day.exercises) { ex in
                                HStack(spacing: 12) {
                                    Image(systemName: ex.muscleGroup.systemImage)
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name)
                                            .font(.subheadline.weight(.medium))
                                        Text("\(ex.muscleGroup.rawValue) • \(ex.suggestion)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Split Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                        onApply()
                    } label: {
                        Text("Apply Plan")
                            .bold()
                    }
                }
            }
        }
    }
}

// MARK: - Principle Row
private struct PrincipleRow: View {
    let title: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Nippard Split Models & Templates
struct NippardSplitTemplate: Identifiable {
    let id = UUID()
    let name: String
    let frequency: String
    let experience: String
    let summary: String
    let days: [NippardDayTemplate]

    static let allSplits: [NippardSplitTemplate] = [
        // 1. User's 7-Day Split: Custom Weekly Program
        NippardSplitTemplate(
            name: "My Custom Weekly Routine",
            frequency: "5-7 Days Split",
            experience: "Intermediate — Advanced",
            summary: "Your custom structured weekly routine featuring Incline Chest Smith Press, Pendulum Squats, Deadlifts & Abs, and targeted arm & delt isolation.",
            days: [
                NippardDayTemplate(
                    weekday: 2, // Monday
                    title: "Upper Body",
                    exercises: [
                        NippardExerciseTemplate(name: "Incline Chest Smith Press", suggestion: "3 sets • 8-10 reps (Upper chest)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Pec Fly", suggestion: "3 sets • 10-12 reps (Chest stretch)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Bicep Incline Curls", suggestion: "3 sets • 10-12 reps (Biceps stretch)", muscleGroup: .biceps),
                        NippardExerciseTemplate(name: "Seated Cable curls", suggestion: "3 sets • 10-12 reps (Peak tension)", muscleGroup: .biceps),
                        NippardExerciseTemplate(name: "Tricep Pushdown Single hand", suggestion: "3 sets • 12-15 reps (Unilateral)", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Tricep Pushdown", suggestion: "3 sets • 10-12 reps", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Pullups", suggestion: "3 sets • 6-10 reps (Lats)", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Isolateral Rows", suggestion: "3 sets • 8-10 reps (Upper back)", muscleGroup: .back)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 3, // Tuesday
                    title: "Lower Body",
                    exercises: [
                        NippardExerciseTemplate(name: "Pendulum Squats", suggestion: "3 sets • 8-10 reps (Quads)", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Curls", suggestion: "3 sets • 10-12 reps (Hamstrings)", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Extensions", suggestion: "3 sets • 12-15 reps (Quad isolation)", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Abductors", suggestion: "3 sets • 15-20 reps (Glute medius)", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Barbell Overhead", suggestion: "3 sets • 8-10 reps (Shoulders)", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Lateral Raises", suggestion: "4 sets • 12-15 reps (Side delts)", muscleGroup: .shoulders)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 4, // Wednesday
                    title: "Deadlifts and Abs",
                    exercises: [
                        NippardExerciseTemplate(name: "Deadlifts", suggestion: "3 sets • 5 reps (Posterior chain)", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Hanging Leg Raises", suggestion: "3 sets • 12-15 reps (Lower abs)", muscleGroup: .abs),
                        NippardExerciseTemplate(name: "Cable Crunches", suggestion: "3 sets • 12-15 reps (Upper abs)", muscleGroup: .abs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 5, // Thursday
                    title: "Push",
                    exercises: [
                        NippardExerciseTemplate(name: "Incline DB Press", suggestion: "3 sets • 8-10 reps (Upper chest)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Reverse Lateral Raises", suggestion: "3 sets • 12-15 reps (Rear delts)", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Chest Press", suggestion: "3 sets • 8-10 reps (Mid chest)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Reverse grip Tricep Pushdown", suggestion: "3 sets • 10-12 reps", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Tricep Pushdown Single hand", suggestion: "3 sets • 12-15 reps", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Tricep Overhead", suggestion: "3 sets • 10-12 reps (Long head)", muscleGroup: .triceps)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 6, // Friday
                    title: "Friday Workout",
                    exercises: [
                        NippardExerciseTemplate(name: "Rest or Custom Workout", suggestion: "Tap + to add exercises", muscleGroup: .other)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 7, // Saturday
                    title: "Saturday Workout",
                    exercises: [
                        NippardExerciseTemplate(name: "Rest or Custom Workout", suggestion: "Tap + to add exercises", muscleGroup: .other)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 1, // Sunday
                    title: "Deadlift and Abs",
                    exercises: [
                        NippardExerciseTemplate(name: "Deadlifts", suggestion: "3 sets • 5 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Hanging Leg Raises", suggestion: "3 sets • 12-15 reps", muscleGroup: .abs),
                        NippardExerciseTemplate(name: "Cable Crunches", suggestion: "3 sets • 12-15 reps", muscleGroup: .abs)
                    ]
                )
            ]
        ),

        // 2. PPL 6-Day Split
        NippardSplitTemplate(
            name: "Jeff Nippard 6-Day Push / Pull / Legs",
            frequency: "6 Days / Week",
            experience: "Intermediate — Advanced",
            summary: "The ultimate hypertrophy split with 2x weekly frequency per muscle group, targeting heavy compound movements followed by targeted stretch isolation exercises.",
            days: [
                NippardDayTemplate(
                    weekday: 2, // Monday
                    title: "Push (Chest / Delts / Triceps)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Bench Press", suggestion: "3 sets • 6-8 reps (Heavy compound)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Incline Dumbbell Press", suggestion: "3 sets • 8-10 reps (Upper chest stretch)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Standing Overhead Press", suggestion: "3 sets • 8-10 reps (Anterior delt)", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Cable Lateral Raises", suggestion: "4 sets • 12-15 reps (Lateral delt peak tension)", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Triceps Rope Pushdown", suggestion: "3 sets • 10-12 reps", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Overhead Cable Triceps Extension", suggestion: "3 sets • 12-15 reps (Long head stretch)", muscleGroup: .triceps)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 3, // Tuesday
                    title: "Pull (Back / Rear Delts / Biceps)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Deadlift", suggestion: "3 sets • 5 reps (Posterior chain strength)", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Neutral Grip Lat Pulldown", suggestion: "3 sets • 8-10 reps (Lat width)", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Seated Cable Row", suggestion: "3 sets • 10-12 reps (Mid-back & rhomboids)", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Face Pulls", suggestion: "3 sets • 12-15 reps (Rear delts & rotator cuff)", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Incline Dumbbell Bicep Curl", suggestion: "3 sets • 10-12 reps (Stretch emphasis)", muscleGroup: .biceps),
                        NippardExerciseTemplate(name: "Hammer Curls", suggestion: "3 sets • 12-15 reps (Brachialis & forearms)", muscleGroup: .forearms)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 4, // Wednesday
                    title: "Legs (Quads / Hamstrings / Calves)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Back Squat", suggestion: "3 sets • 6-8 reps (Quad strength)", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Romanian Deadlift", suggestion: "3 sets • 8-10 reps (Hamstrings stretch)", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Press", suggestion: "3 sets • 10-12 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Lying Leg Curl", suggestion: "3 sets • 10-12 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Standing Calf Raises", suggestion: "4 sets • 12-15 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Hanging Leg Raises", suggestion: "3 sets • 12-15 reps (Core control)", muscleGroup: .abs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 5, // Thursday
                    title: "Push (Chest / Delts / Triceps)",
                    exercises: [
                        NippardExerciseTemplate(name: "Incline Barbell Bench Press", suggestion: "3 sets • 6-8 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Dumbbell Flat Bench", suggestion: "3 sets • 8-10 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Dumbbell Lateral Raise", suggestion: "4 sets • 12-15 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Cable Chest Flyes", suggestion: "3 sets • 12-15 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Skull Crushers (EZ-Bar)", suggestion: "3 sets • 10-12 reps", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Cable Crunch", suggestion: "3 sets • 12-15 reps", muscleGroup: .abs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 6, // Friday
                    title: "Pull (Back / Rear Delts / Biceps)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Bent Over Row", suggestion: "3 sets • 6-8 reps (Upper back thickness)", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Pull-Ups / Wide Pulldown", suggestion: "3 sets • 8-10 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Chest Supported Row", suggestion: "3 sets • 10-12 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Reverse Pec Deck Fly", suggestion: "3 sets • 12-15 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Preacher Curl", suggestion: "3 sets • 10-12 reps", muscleGroup: .biceps),
                        NippardExerciseTemplate(name: "Cable Rope Hammer Curl", suggestion: "3 sets • 12-15 reps", muscleGroup: .forearms)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 7, // Saturday
                    title: "Legs (Quads / Hamstrings / Calves)",
                    exercises: [
                        NippardExerciseTemplate(name: "Hack Squat / Front Squat", suggestion: "3 sets • 8-10 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Bulgarian Split Squats", suggestion: "3 sets • 10-12 reps each", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Extensions", suggestion: "3 sets • 12-15 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Seated Leg Curl", suggestion: "3 sets • 12-15 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Seated Calf Raise", suggestion: "4 sets • 15 reps", muscleGroup: .legs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 1, // Sunday
                    title: "Rest & Recovery",
                    exercises: []
                )
            ]
        ),

        // 2. Upper / Lower 4-Day Split
        NippardSplitTemplate(
            name: "Jeff Nippard 4-Day Upper / Lower",
            frequency: "4 Days / Week",
            experience: "All Levels",
            summary: "Highly efficient split allowing maximum recovery between heavy compound lifts. Perfect balance of strength, muscle building, and busy schedules.",
            days: [
                NippardDayTemplate(
                    weekday: 2, // Monday
                    title: "Upper A (Strength Focus)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Bench Press", suggestion: "3 sets • 5-6 reps (Strength)", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Barbell Bent Over Row", suggestion: "3 sets • 6-8 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Overhead Barbell Press", suggestion: "3 sets • 6-8 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Lat Pulldown", suggestion: "3 sets • 8-10 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Incline DB Bicep Curl", suggestion: "3 sets • 10-12 reps", muscleGroup: .biceps),
                        NippardExerciseTemplate(name: "Dips / Tricep Pushdown", suggestion: "3 sets • 8-10 reps", muscleGroup: .triceps)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 3, // Tuesday
                    title: "Lower A (Quad Bias)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Back Squat", suggestion: "3 sets • 6-8 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Romanian Deadlift", suggestion: "3 sets • 8-10 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Press", suggestion: "3 sets • 10-12 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Standing Calf Raises", suggestion: "4 sets • 12-15 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Hanging Knee Raises", suggestion: "3 sets • 12-15 reps", muscleGroup: .abs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 4, // Wednesday
                    title: "Rest Day",
                    exercises: []
                ),
                NippardDayTemplate(
                    weekday: 5, // Thursday
                    title: "Upper B (Hypertrophy Focus)",
                    exercises: [
                        NippardExerciseTemplate(name: "Incline Dumbbell Bench", suggestion: "3 sets • 8-10 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Chest-Supported T-Bar Row", suggestion: "3 sets • 8-12 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Cable Lateral Raises", suggestion: "4 sets • 12-15 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Cable Flyes", suggestion: "3 sets • 12-15 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Spider Curls", suggestion: "3 sets • 10-12 reps", muscleGroup: .biceps),
                        NippardExerciseTemplate(name: "Overhead Rope Tricep Extension", suggestion: "3 sets • 12-15 reps", muscleGroup: .triceps)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 6, // Friday
                    title: "Lower B (Posterior Bias)",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Deadlift", suggestion: "3 sets • 5 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Bulgarian Split Squat", suggestion: "3 sets • 8-10 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Lying Leg Curl", suggestion: "3 sets • 10-12 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Extensions", suggestion: "3 sets • 12-15 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Seated Calf Raises", suggestion: "4 sets • 15 reps", muscleGroup: .legs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 7, // Saturday
                    title: "Rest & Active Recovery",
                    exercises: []
                ),
                NippardDayTemplate(
                    weekday: 1, // Sunday
                    title: "Rest Day",
                    exercises: []
                )
            ]
        ),

        // 3. Full Body 3-Day Split
        NippardSplitTemplate(
            name: "Jeff Nippard 3-Day Full Body",
            frequency: "3 Days / Week",
            experience: "Beginner — Intermediate",
            summary: "High frequency full body split hitting major muscle groups 3 times per week with optimal recovery between sessions.",
            days: [
                NippardDayTemplate(
                    weekday: 2, // Monday
                    title: "Full Body A",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Squat", suggestion: "3 sets • 6-8 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Flat Dumbbell Press", suggestion: "3 sets • 8-10 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Lat Pulldown", suggestion: "3 sets • 8-12 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Romanian Deadlift", suggestion: "3 sets • 8-10 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Lateral Raises", suggestion: "3 sets • 12-15 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Bicep Curls", suggestion: "3 sets • 10-12 reps", muscleGroup: .biceps)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 3, // Tuesday
                    title: "Rest Day",
                    exercises: []
                ),
                NippardDayTemplate(
                    weekday: 4, // Wednesday
                    title: "Full Body B",
                    exercises: [
                        NippardExerciseTemplate(name: "Barbell Deadlift", suggestion: "3 sets • 5 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Overhead Barbell Press", suggestion: "3 sets • 6-8 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Barbell Row", suggestion: "3 sets • 8-10 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Leg Press", suggestion: "3 sets • 10-12 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Tricep Pushdown", suggestion: "3 sets • 10-12 reps", muscleGroup: .triceps),
                        NippardExerciseTemplate(name: "Hanging Leg Raises", suggestion: "3 sets • 12-15 reps", muscleGroup: .abs)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 5, // Thursday
                    title: "Rest Day",
                    exercises: []
                ),
                NippardDayTemplate(
                    weekday: 6, // Friday
                    title: "Full Body C",
                    exercises: [
                        NippardExerciseTemplate(name: "Incline Barbell Press", suggestion: "3 sets • 6-8 reps", muscleGroup: .chest),
                        NippardExerciseTemplate(name: "Neutral Grip Pull-ups", suggestion: "3 sets • 8-10 reps", muscleGroup: .back),
                        NippardExerciseTemplate(name: "Hack Squat", suggestion: "3 sets • 8-10 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Leg Curls", suggestion: "3 sets • 10-12 reps", muscleGroup: .legs),
                        NippardExerciseTemplate(name: "Cable Lateral Raises", suggestion: "3 sets • 12-15 reps", muscleGroup: .shoulders),
                        NippardExerciseTemplate(name: "Incline Hammer Curls", suggestion: "3 sets • 10-12 reps", muscleGroup: .biceps)
                    ]
                ),
                NippardDayTemplate(
                    weekday: 7, // Saturday
                    title: "Rest Day",
                    exercises: []
                ),
                NippardDayTemplate(
                    weekday: 1, // Sunday
                    title: "Rest Day",
                    exercises: []
                )
            ]
        )
    ]
}

struct NippardDayTemplate: Identifiable {
    let id = UUID()
    let weekday: Int
    let title: String
    let exercises: [NippardExerciseTemplate]

    var weekdayShort: String {
        switch weekday {
        case 1: return "SUN"
        case 2: return "MON"
        case 3: return "TUE"
        case 4: return "WED"
        case 5: return "THU"
        case 6: return "FRI"
        case 7: return "SAT"
        default: return ""
        }
    }

    var weekdayName: String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return ""
        }
    }
}

struct NippardExerciseTemplate: Identifiable {
    let id = UUID()
    let name: String
    let suggestion: String
    let muscleGroup: MuscleGroup
}
