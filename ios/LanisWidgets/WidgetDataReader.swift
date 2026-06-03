import Foundation

struct WidgetDataReader {
    private static let defaults = UserDefaults(suiteName: appGroupID)

    static func timetable() -> TimetableData? {
        decode(key: "widget_timetable")
    }

    static func substitutions() -> SubstitutionData? {
        decode(key: "widget_substitutions")
    }

    static func calendar() -> CalendarData? {
        decode(key: "widget_calendar")
    }

    static func conversations() -> ConversationsData? {
        decode(key: "widget_conversations")
    }

    private static func decode<T: Decodable>(key: String) -> T? {
        guard let jsonString = defaults?.string(forKey: key),
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
