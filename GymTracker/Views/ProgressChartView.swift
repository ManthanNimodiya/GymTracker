import SwiftUI
import SwiftData
import Charts

private struct ProgressPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let setsCount: Int
    let totalVolume: Double
    let sets: [ExerciseSet]

    static func == (lhs: ProgressPoint, rhs: ProgressPoint) -> Bool {
        lhs.date == rhs.date && lhs.maxWeight == rhs.maxWeight
    }
}

struct ProgressChartView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allSets: [ExerciseSet]
    @State private var selectedExercise: Exercise?
    @State private var selectedDate: Date?
    @State private var selectedPoint: ProgressPoint?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if exercises.isEmpty {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.top, 40)

                            VStack(spacing: 6) {
                                Text("No Progress Data Yet")
                                    .font(.title3.bold())
                                Text("Add exercises and log workout sets to start visualizing your strength trends.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                    } else {
                        // Exercise Picker Menu
                        HStack {
                            Menu {
                                ForEach(exercises) { exercise in
                                    Button {
                                        withAnimation(.snappy) {
                                            selectedExercise = exercise
                                            selectedDate = nil
                                            selectedPoint = nil
                                        }
                                    } label: {
                                        HStack {
                                            Text(exercise.name)
                                            if selectedExercise?.persistentModelID == exercise.persistentModelID {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedExercise?.muscleGroup.systemImage ?? "dumbbell.fill")
                                        .foregroundStyle(Color.accentColor)
                                    Text(selectedExercise?.name ?? "Select Exercise")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                            }

                            Spacer()
                        }
                        .padding(.horizontal)

                        if let currentExercise = selectedExercise {
                            let pointsList = points(for: currentExercise)

                            if pointsList.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.xyaxis.line")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary.opacity(0.7))
                                        .padding(.top, 30)

                                    Text("No logged sets for \(currentExercise.name)")
                                        .font(.subheadline.bold())
                                    Text("Log a set with this exercise in your Plan or Workouts tab to see your progression curve.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.vertical, 20)
                            } else {
                                // Interactive Info Callout Card
                                if let activePoint = currentActivePoint(in: pointsList) {
                                    pointDetailCard(for: activePoint, in: pointsList)
                                        .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "hand.tap.fill")
                                            .font(.caption2)
                                        Text("Tap or scrub along the chart points to inspect history")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }

                                // Interactive Chart
                                chartView(points: pointsList)

                                // Session Logs Section
                                historySection(points: pointsList)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Progress")
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
            }
            .sensoryFeedback(.selection, trigger: selectedPoint)
        }
    }

    // MARK: - Swift Chart View
    private func chartView(points: [ProgressPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength Curve")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("Max Weight (kg)")
                        .font(.subheadline.bold())
                }
                Spacer()
                if let maxOverall = points.map(\.maxWeight).max() {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("PR: \(maxOverall, specifier: "%.1f") kg")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Max Weight", point.maxWeight)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Max Weight", point.maxWeight)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Max Weight", point.maxWeight)
                    )
                    .symbolSize(isPointSelected(point) ? 140 : 50)
                    .foregroundStyle(isPointSelected(point) ? Color.primary : Color.accentColor)
                }

                if let active = currentActivePoint(in: points) {
                    RuleMark(x: .value("Selected Date", active.date))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.accentColor.opacity(0.6))

                    PointMark(
                        x: .value("Date", active.date),
                        y: .value("Max Weight", active.maxWeight)
                    )
                    .symbolSize(180)
                    .foregroundStyle(Color.accentColor)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(active.maxWeight, specifier: "%.1f") kg")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 3)
                    }
                }
            }
            .chartXSelection(value: $selectedDate)
            .frame(height: 240)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .animation(.snappy, value: selectedPoint)
        }
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Selected Point Detail Callout
    private func pointDetailCard(for point: ProgressPoint, in points: [ProgressPoint]) -> some View {
        let diff = deltaFromPrevious(point: point, in: points)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(point.maxWeight, specifier: "%.1f") kg")
                        .font(.title2.bold())
                }

                Spacer()

                if let diff {
                    HStack(spacing: 4) {
                        Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(diff >= 0 ? "+" : "")\(diff, specifier: "%.1f") kg")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(diff >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((diff >= 0 ? Color.green : Color.red).opacity(0.15))
                    .clipShape(Capsule())
                }

                Button {
                    withAnimation(.snappy) {
                        selectedDate = nil
                        selectedPoint = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sets Logged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(point.setsCount)")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Total Volume")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(point.totalVolume, specifier: "%.0f") kg")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Reps Summary")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(point.sets.map { "\($0.reps)" }.joined(separator: ", "))
                        .font(.subheadline.bold())
                }
            }

            if !point.sets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Breakdown")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    ForEach(Array(point.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(set.reps) reps @ \(set.weight, specifier: "%.1f") kg")
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    // MARK: - History List
    private func historySection(points: [ProgressPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logged History")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(points.reversed()) { point in
                    Button {
                        withAnimation(.snappy) {
                            if selectedPoint == point {
                                selectedPoint = nil
                                selectedDate = nil
                            } else {
                                selectedPoint = point
                                selectedDate = point.date
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(point.setsCount) set\(point.setsCount == 1 ? "" : "s") • \(point.sets.map { "\($0.reps)x\($0.weight.formatted())" }.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(point.maxWeight, specifier: "%.1f") kg")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isPointSelected(point) ? Color.accentColor : .primary)
                                Text("Max")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(isPointSelected(point) ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isPointSelected(point) ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers
    private func isPointSelected(_ point: ProgressPoint) -> Bool {
        if let selectedPoint {
            return selectedPoint == point
        }
        if let selectedDate {
            return abs(point.date.timeIntervalSince(selectedDate)) < 86400 / 2
        }
        return false
    }

    private func currentActivePoint(in points: [ProgressPoint]) -> ProgressPoint? {
        if let selectedPoint {
            return selectedPoint
        }
        guard let selectedDate else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) })
    }

    private func deltaFromPrevious(point: ProgressPoint, in points: [ProgressPoint]) -> Double? {
        guard let currentIndex = points.firstIndex(where: { $0.id == point.id }), currentIndex > 0 else {
            return nil
        }
        return point.maxWeight - points[currentIndex - 1].maxWeight
    }

    private func points(for exercise: Exercise) -> [ProgressPoint] {
        let filtered = allSets.filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
        let grouped = Dictionary(grouping: filtered) { $0.session?.date ?? .distantPast }
        return grouped
            .map { date, sets in
                let sortedSets = sets.sorted(by: { $0.order < $1.order })
                let maxWeight = sets.map(\.weight).max() ?? 0
                let totalVol = sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                return ProgressPoint(
                    date: date,
                    maxWeight: maxWeight,
                    setsCount: sets.count,
                    totalVolume: totalVol,
                    sets: sortedSets
                )
            }
            .sorted { $0.date < $1.date }
    }
}
