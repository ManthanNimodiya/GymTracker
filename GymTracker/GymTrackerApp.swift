import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Exercise.self, WorkoutSession.self, ExerciseSet.self,
            ProgressPhoto.self, PlanDay.self, PlanExercise.self, DayCheckIn.self
        ])
    }
}
