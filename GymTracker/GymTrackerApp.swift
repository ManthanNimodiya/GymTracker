import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    @AppStorage("appTheme") private var appTheme: String = "system"

    private var preferredScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
        }
        .modelContainer(for: [
            Exercise.self, WorkoutSession.self, ExerciseSet.self,
            ProgressPhoto.self, PlanDay.self, PlanExercise.self, DayCheckIn.self
        ])
    }
}
