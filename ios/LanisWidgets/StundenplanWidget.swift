import WidgetKit
import SwiftUI

struct TimetableTimelineEntry: TimelineEntry {
    let date: Date
    let data: TimetableData?
}

struct TimetableProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimetableTimelineEntry {
        TimetableTimelineEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableTimelineEntry) -> Void) {
        completion(TimetableTimelineEntry(date: Date(), data: WidgetDataReader.timetable()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableTimelineEntry>) -> Void) {
        let entry = TimetableTimelineEntry(date: Date(), data: WidgetDataReader.timetable())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Small View
@available(iOSApplicationExtension 17.0, *)
struct TimetableSmallView: View {
    let data: TimetableData?

    private var relevantLesson: TimetableEntry? {
        data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Stundenplan")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let lesson = relevantLesson {
                Text(lesson.name)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(lesson.start) Uhr")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Keine Stunden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium View
@available(iOSApplicationExtension 17.0, *)
struct TimetableMediumView: View {
    let data: TimetableData?

    private var currentAndNext: [TimetableEntry] {
        guard let today = data?.today else { return [] }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return today.filter { entry in
            let endParts = entry.end.split(separator: ":").compactMap { Int($0) }
            let endMin = (endParts.first ?? 0) * 60 + (endParts.last ?? 0)
            return endMin > nowMin
        }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Stundenplan")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if currentAndNext.isEmpty {
                Spacer()
                Text("Keine weiteren Stunden heute")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(currentAndNext.indices, id: \.self) { i in
                    let lesson = currentAndNext[i]
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(lesson.accentColor)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(lesson.name)
                                .font(.subheadline).bold()
                                .lineLimit(1)
                            Text("\(lesson.start)–\(lesson.end)\(lesson.room.map { " · \($0)" } ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large View
@available(iOSApplicationExtension 17.0, *)
struct TimetableLargeView: View {
    let data: TimetableData?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Stundenplan heute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Divider()
            if let today = data?.today, !today.isEmpty {
                ForEach(today.indices, id: \.self) { i in
                    let lesson = today[i]
                    HStack(spacing: 8) {
                        Text(lesson.start)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(lesson.accentColor)
                            .frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(lesson.name)
                                .font(.subheadline).bold()
                                .lineLimit(1)
                            if let room = lesson.room {
                                Text(room)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            } else {
                Spacer()
                Text("Keine Stunden heute")
                    .foregroundColor(.secondary)
                Spacer()
            }
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen Views
@available(iOSApplicationExtension 16.0, *)
struct TimetableAccessoryCircularView: View {
    let data: TimetableData?
    var body: some View {
        let name = data?.currentLesson?.name ?? data?.today.first(where: { isUpcoming($0) })?.name ?? "–"
        let short = String(name.prefix(3))
        ZStack {
            AccessoryWidgetBackground()
            Text(short)
                .font(.caption.bold())
                .widgetAccentable()
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
struct TimetableAccessoryRectangularView: View {
    let data: TimetableData?
    var body: some View {
        let lesson = data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
        if let l = lesson {
            VStack(alignment: .leading) {
                Text(l.name).font(.headline).widgetAccentable()
                Text("\(l.start) Uhr\(l.room.map { " · \($0)" } ?? "")").font(.caption)
            }
        } else {
            Text("Keine Stunden").font(.caption)
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
struct TimetableAccessoryInlineView: View {
    let data: TimetableData?
    var body: some View {
        let lesson = data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
        if let l = lesson {
            Text("Jetzt: \(l.name)\(l.room.map { " \($0)" } ?? "")")
        } else {
            Text("Kein Unterricht")
        }
    }
}

// MARK: - Widget
@available(iOSApplicationExtension 17.0, *)
struct StundenplanWidget: Widget {
    let kind = "StundenplanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableProvider()) { entry in
            StundenplanWidgetView(entry: entry)
        }
        .configurationDisplayName("Stundenplan")
        .description("Zeigt deine heutigen Stunden.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOSApplicationExtension 16.0, *) {
            families += [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        }
        return families
    }
}

@available(iOSApplicationExtension 17.0, *)
struct StundenplanWidgetView: View {
    let entry: TimetableTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            TimetableSmallView(data: entry.data)
        case .systemMedium:
            TimetableMediumView(data: entry.data)
        case .systemLarge:
            TimetableLargeView(data: entry.data)
        default:
            if #available(iOSApplicationExtension 16.0, *) {
                switch family {
                case .accessoryCircular:
                    TimetableAccessoryCircularView(data: entry.data)
                case .accessoryRectangular:
                    TimetableAccessoryRectangularView(data: entry.data)
                case .accessoryInline:
                    TimetableAccessoryInlineView(data: entry.data)
                default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Helpers
private func isUpcoming(_ entry: TimetableEntry) -> Bool {
    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
    let parts = entry.start.split(separator: ":").compactMap { Int($0) }
    let startMin = (parts.first ?? 0) * 60 + (parts.last ?? 0)
    return startMin > nowMin
}
