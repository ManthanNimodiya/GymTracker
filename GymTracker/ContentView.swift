import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }

            HistoryView()
                .tabItem { Label("Workouts", systemImage: "list.bullet.rectangle") }

            ExercisesView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }

            ProgressChartView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            ExploreView()
                .tabItem { Label("Explore", systemImage: "play.rectangle.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Exercise.self, WorkoutSession.self, ExerciseSet.self,
            ProgressPhoto.self, PlanDay.self, PlanExercise.self, DayCheckIn.self
        ], inMemory: true)
}
