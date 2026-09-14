import Foundation
import SwiftData

enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case legs = "Legs"
    case biceps = "Bicep"
    case triceps = "Tricep"
    case forearms = "Forearms"
    case abs = "Abs"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.strengthtraining.functional"
        case .shoulders: return "figure.arms.open"
        case .legs: return "figure.walk"
        case .biceps, .triceps, .forearms: return "dumbbell.fill"
        case .abs: return "figure.core.training"
        case .other: return "ellipsis.circle"
        }
    }
}

@Model
final class Exercise {
    var name: String
    var category: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.exercise)
    var photos: [ProgressPhoto] = []

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: category) ?? .other }
        set { category = newValue.rawValue }
    }

    init(name: String, category: String = MuscleGroup.other.rawValue) {
        self.name = name
        self.category = category
        self.createdAt = .now
    }
}

@Model
final class ProgressPhoto {
    @Attribute(.externalStorage)
    var imageData: Data
    var date: Date
    var note: String
    var exercise: Exercise?

    init(imageData: Data, date: Date = .now, note: String = "", exercise: Exercise? = nil) {
        self.imageData = imageData
        self.date = date
        self.note = note
        self.exercise = exercise
    }
}

@Model
final class WorkoutSession {
    var date: Date
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session)
    var sets: [ExerciseSet] = []

    init(date: Date = .now, notes: String = "") {
        self.date = date
        self.notes = notes
    }
}

@Model
final class ExerciseSet {
    var reps: Int
    var weight: Double
    var order: Int
    var exercise: Exercise?
    var session: WorkoutSession?

    init(reps: Int, weight: Double, order: Int, exercise: Exercise?) {
        self.reps = reps
        self.weight = weight
        self.order = order
        self.exercise = exercise
    }
}

@Model
final class PlanDay {
    /// Matches `Calendar.component(.weekday, from:)`: 1 = Sunday ... 7 = Saturday.
    var weekday: Int
    var title: String

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.day)
    var exercises: [PlanExercise] = []

    init(weekday: Int, title: String) {
        self.weekday = weekday
        self.title = title
    }
}

@Model
final class PlanExercise {
    var name: String
    var suggestion: String
    var order: Int
    var muscleGroupRaw: String = MuscleGroup.other.rawValue
    var day: PlanDay?

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
        set { muscleGroupRaw = newValue.rawValue }
    }

    init(name: String, suggestion: String, order: Int, muscleGroup: MuscleGroup = .other, day: PlanDay? = nil) {
        self.name = name
        self.suggestion = suggestion
        self.order = order
        self.muscleGroupRaw = muscleGroup.rawValue
        self.day = day
    }
}

@Model
final class DayCheckIn {
    var date: Date
    var status: String
    var reason: String = ""

    init(date: Date, status: String, reason: String = "") {
        self.date = date
        self.status = status
        self.reason = reason
    }
}
