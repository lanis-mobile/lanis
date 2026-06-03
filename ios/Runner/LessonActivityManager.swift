import ActivityKit
import Flutter
import Foundation

@available(iOS 16.2, *)
struct LessonJson: Decodable {
    let name: String
    let room: String?
    let teacher: String?
    let phase: String          // "lesson" | "break" | "dayEnd"
    let phaseStartTime: String // "HH:mm"
    let phaseEndTime: String   // "HH:mm"
    let nextName: String?
    let nextRoom: String?
    let nextTeacher: String?
    let nextStart: String?
}

@available(iOS 16.2, *)
enum LessonActivityManager {
    private static var currentActivity: Activity<LessonActivityAttributes>?

    static func start(json: String, result: @escaping FlutterResult) {
        guard let data = json.data(using: .utf8),
              let lesson = try? JSONDecoder().decode(LessonJson.self, from: data),
              let phase = ActivityPhase(rawValue: lesson.phase),
              let startDate = parseTime(lesson.phaseStartTime),
              let endDate = parseTime(lesson.phaseEndTime)
        else {
            result(FlutterError(code: "PARSE_ERROR", message: "Could not parse lesson json", details: nil))
            return
        }

        let attrs = LessonActivityAttributes(
            lessonName: lesson.name,
            teacher: lesson.teacher,
            room: lesson.room
        )
        let state = LessonActivityAttributes.ContentState(
            phase: phase,
            phaseStartTime: startDate,
            phaseEndTime: endDate,
            nextLessonName: lesson.nextName,
            nextLessonRoom: lesson.nextRoom,
            nextLessonTeacher: lesson.nextTeacher,
            nextLessonStart: lesson.nextStart
        )

        Task {
            if let existing = currentActivity {
                await existing.end(dismissalPolicy: .immediate)
                currentActivity = nil
            }
            do {
                currentActivity = try Activity.request(
                    attributes: attrs,
                    contentState: state,
                    pushType: nil
                )
                result(nil)
            } catch {
                result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    static func update(json: String, result: @escaping FlutterResult) {
        guard let activity = currentActivity,
              let data = json.data(using: .utf8),
              let lesson = try? JSONDecoder().decode(LessonJson.self, from: data),
              let phase = ActivityPhase(rawValue: lesson.phase),
              let startDate = parseTime(lesson.phaseStartTime),
              let endDate = parseTime(lesson.phaseEndTime)
        else {
            result(nil)
            return
        }

        let state = LessonActivityAttributes.ContentState(
            phase: phase,
            phaseStartTime: startDate,
            phaseEndTime: endDate,
            nextLessonName: lesson.nextName,
            nextLessonRoom: lesson.nextRoom,
            nextLessonTeacher: lesson.nextTeacher,
            nextLessonStart: lesson.nextStart
        )
        Task {
            await activity.update(using: state)
            result(nil)
        }
    }

    static func end(result: @escaping FlutterResult) {
        guard let activity = currentActivity else {
            result(nil)
            return
        }
        Task {
            let activityToEnd = activity
            currentActivity = nil
            await activityToEnd.end(dismissalPolicy: .immediate)
            result(nil)
        }
    }

    private static func parseTime(_ timeString: String) -> Date? {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts[0]
        components.minute = parts[1]
        components.second = 0
        return calendar.date(from: components)
    }
}
