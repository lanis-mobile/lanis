import ActivityKit
import Foundation

// MARK: - Stunden Live Activity
@available(iOS 16.2, *)
struct LessonActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var nextLessonName: String?
        var nextLessonStart: String?
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
