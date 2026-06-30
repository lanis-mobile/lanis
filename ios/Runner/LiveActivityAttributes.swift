import ActivityKit
import Foundation

// MARK: - Stunden Live Activity

enum ActivityPhase: String, Codable {
    case lesson
    case `break`
    case dayEnd
}

@available(iOS 16.2, *)
struct LessonActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: ActivityPhase
        var phaseStartTime: Date   // start of current phase (for progress bar)
        var phaseEndTime: Date     // end of current phase (countdown target)
        var nextLessonName: String?
        var nextLessonRoom: String?
        var nextLessonTeacher: String?
        var nextLessonStart: String?  // "HH:mm" display string
    }

    var lessonName: String
    var teacher: String?
    var room: String?
}

// MARK: - Vertretungs Live Activity
struct LiveSubstitutionEntry: Codable, Hashable {
    let stunde: String
    let fach: String?
    let art: String?
}

@available(iOS 16.2, *)
struct SubstitutionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var entries: [LiveSubstitutionEntry]
        var count: Int
    }

    var date: String
}
