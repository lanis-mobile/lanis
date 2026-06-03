import ActivityKit
import Flutter
import Foundation

@available(iOS 16.2, *)
struct LessonJson: Decodable {
    let name: String
    let room: String?
    let teacher: String?
    let end: String  // "HH:mm"
    let nextName: String?
    let nextStart: String?
}

@available(iOS 16.2, *)
enum LessonActivityManager {
    private static var currentActivity: Activity<LessonActivityAttributes>?

    static func start(json: String, result: @escaping FlutterResult) {
        guard let data = json.data(using: .utf8),
              let lesson = try? JSONDecoder().decode(LessonJson.self, from: data),
              let endDate = parseTime(lesson.end)
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
            endTime: endDate,
            nextLessonName: lesson.nextName,
            nextLessonStart: lesson.nextStart
        )

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

    static func update(json: String, result: @escaping FlutterResult) {
        guard let activity = currentActivity,
              let data = json.data(using: .utf8),
              let lesson = try? JSONDecoder().decode(LessonJson.self, from: data),
              let endDate = parseTime(lesson.end)
        else {
            result(nil)
            return
        }

        let state = LessonActivityAttributes.ContentState(
            endTime: endDate,
            nextLessonName: lesson.nextName,
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
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
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
