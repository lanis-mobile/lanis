import Foundation
import SwiftUI

let appGroupID = "group.io.github.alessioc42.sph.widgets"

struct TimetableEntry: Decodable {
    let name: String
    let room: String?
    let teacher: String?
    let start: String
    let end: String
    let stunde: Int
    let color: String?

    var accentColor: Color {
        guard let hex = color else { return .accentColor }
        return Color(hex: hex) ?? .accentColor
    }
}

struct TimetableData: Decodable {
    let updatedAt: String
    let today: [TimetableEntry]
    let currentLesson: TimetableEntry?
}

struct SubstitutionEntry: Decodable {
    let stunde: String
    let fach: String?
    let art: String?
    let raum: String?
    let vertreter: String?
}

struct SubstitutionData: Decodable {
    let updatedAt: String
    let date: String
    let entries: [SubstitutionEntry]
}

struct CalendarEventEntry: Decodable {
    let title: String
    let start: String
    let allDay: Bool
    let color: String?

    var startDate: Date? {
        ISO8601DateFormatter().date(from: start)
    }

    var accentColor: Color {
        guard let hex = color else { return .accentColor }
        return Color(hex: hex) ?? .accentColor
    }
}

struct CalendarData: Decodable {
    let updatedAt: String
    let events: [CalendarEventEntry]
}

struct ConversationEntry: Decodable {
    let sender: String
    let subject: String
    let isUnread: Bool
}

struct ConversationsData: Decodable {
    let updatedAt: String
    let unreadCount: Int
    let latest: [ConversationEntry]
}

// MARK: - Color from Hex helper
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b)
    }
}
