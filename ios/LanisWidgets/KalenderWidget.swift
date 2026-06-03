import WidgetKit
import SwiftUI

struct CalendarTimelineEntry: TimelineEntry {
    let date: Date
    let data: CalendarData?
}

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarTimelineEntry { CalendarTimelineEntry(date: Date(), data: nil) }
    func getSnapshot(in context: Context, completion: @escaping (CalendarTimelineEntry) -> Void) {
        completion(CalendarTimelineEntry(date: Date(), data: WidgetDataReader.calendar()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarTimelineEntry>) -> Void) {
        let entry = CalendarTimelineEntry(date: Date(), data: WidgetDataReader.calendar())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Helpers

private let weekdaySymbols: [String] = {
    var cal = Calendar.current
    cal.locale = Locale(identifier: "de_DE")
    return cal.veryShortWeekdaySymbols
}()

private func dayLabel(_ date: Date?) -> String {
    guard let date else { return "" }
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Heute" }
    if cal.isDateInTomorrow(date) { return "Morgen" }
    if #available(iOSApplicationExtension 15.0, *) {
        return date.formatted(.dateTime.weekday(.abbreviated).day().month())
    }
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "E d. MMM"
    return f.string(from: date)
}

private func timeLabel(_ entry: CalendarEventEntry) -> String {
    if entry.allDay { return "Ganztägig" }
    guard let d = entry.startDate else { return "" }
    if #available(iOSApplicationExtension 15.0, *) {
        return d.formatted(.dateTime.hour().minute())
    }
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: d)
}

// MARK: - Small: prominent day number + next event (Apple Calendar style)

@available(iOSApplicationExtension 17.0, *)
struct KalenderSmallView: View {
    let data: CalendarData?
    private var nextEvent: CalendarEventEntry? { data?.events.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day number header — mirrors Apple Calendar widget
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(dayOfMonthString())
                    .font(.system(size: 38, weight: .thin, design: .rounded))
                    .foregroundStyle(.red)
                Text(weekdayString())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
            Divider().padding(.vertical, 4)
            if let e = nextEvent {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(e.accentColor)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title)
                            .font(.caption).bold()
                            .lineLimit(2)
                        Text(dayLabel(e.startDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Keine\nEreignisse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func dayOfMonthString() -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: Date()))"
    }

    private func weekdayString() -> String {
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: Date())
        let symbols = cal.shortWeekdaySymbols
        return symbols[idx - 1].uppercased()
    }
}

// MARK: - Medium: date column left + event list right (Apple Calendar style)

@available(iOSApplicationExtension 17.0, *)
struct KalenderMediumView: View {
    let data: CalendarData?
    private var events: [CalendarEventEntry] { Array((data?.events ?? []).prefix(3)) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column — date
            VStack(alignment: .center, spacing: 2) {
                Text(weekdayAbbr())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(dayNumber())
                    .font(.system(size: 32, weight: .thin, design: .rounded))
                    .foregroundStyle(.red)
            }
            .frame(width: 44)

            Divider()

            // Right column — event list
            VStack(alignment: .leading, spacing: 5) {
                if events.isEmpty {
                    Spacer()
                    Text("Keine Ereignisse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(events.indices, id: \.self) { i in
                        let e = events[i]
                        HStack(alignment: .center, spacing: 6) {
                            Circle()
                                .fill(e.accentColor)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(e.title)
                                    .font(.subheadline).bold()
                                    .lineLimit(1)
                                Text("\(dayLabel(e.startDate))  \(timeLabel(e))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func weekdayAbbr() -> String {
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: Date())
        return cal.shortWeekdaySymbols[idx - 1]
    }

    private func dayNumber() -> String {
        "\(Calendar.current.component(.day, from: Date()))"
    }
}

// MARK: - Large: mini month grid top + event list bottom

@available(iOSApplicationExtension 17.0, *)
struct KalenderLargeView: View {
    let data: CalendarData?
    private var events: [CalendarEventEntry] { Array((data?.events ?? []).prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MiniMonthView(events: data?.events ?? [])
            Divider()
            if events.isEmpty {
                Spacer()
                Text("Keine bevorstehenden Ereignisse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(events.indices, id: \.self) { i in
                    let e = events[i]
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(e.accentColor)
                            .frame(width: 3, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.title).font(.subheadline).bold().lineLimit(1)
                            Text("\(dayLabel(e.startDate))  \(timeLabel(e))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Mini month grid (used in Large)

@available(iOSApplicationExtension 17.0, *)
private struct MiniMonthView: View {
    let events: [CalendarEventEntry]

    private var cal: Calendar { Calendar.current }
    private var today: Date { Date() }

    private var monthDays: [(day: Int, date: Date, hasEvent: Bool)] {
        let components = cal.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let eventDays: Set<Int> = Set(events.compactMap { e -> Int? in
            guard let d = e.startDate, cal.isDate(d, equalTo: today, toGranularity: .month) else { return nil }
            return cal.component(.day, from: d)
        })

        return range.compactMap { day -> (Int, Date, Bool)? in
            var c = components; c.day = day
            guard let date = cal.date(from: c) else { return nil }
            return (day, date, eventDays.contains(day))
        }
    }

    private var firstWeekday: Int {
        let components = cal.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = cal.date(from: components) else { return 1 }
        // Adjust so Monday = 0
        return (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
    }

    private var monthName: String {
        if #available(iOSApplicationExtension 15.0, *) {
            return today.formatted(.dateTime.month(.wide))
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM"
        return f.string(from: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthName)
                .font(.caption.bold())
                .foregroundStyle(.primary)

            // Weekday header — Mon first
            let headers = ["Mo","Di","Mi","Do","Fr","Sa","So"]
            HStack(spacing: 0) {
                ForEach(headers, id: \.self) { h in
                    Text(h)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let todayDay = cal.component(.day, from: today)
            let cells: [Int?] = Array(repeating: nil, count: firstWeekday) + monthDays.map { $0.day }
            let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0+7, cells.count)]) }

            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = col < rows[r].count ? rows[r][col] : nil
                        let hasEvent = day.flatMap { d in monthDays.first { $0.day == d } }?.hasEvent ?? false
                        ZStack {
                            if let d = day, d == todayDay {
                                Circle().fill(Color.red).frame(width: 18, height: 18)
                            }
                            VStack(spacing: 1) {
                                Text(day.map { "\($0)" } ?? "")
                                    .font(.system(size: 10))
                                    .foregroundStyle(day == todayDay ? .white : .primary)
                                if hasEvent {
                                    Circle().fill(day == todayDay ? Color.white : Color.accentColor).frame(width: 3, height: 3)
                                } else {
                                    Color.clear.frame(width: 3, height: 3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Widget

@available(iOSApplicationExtension 17.0, *)
struct KalenderWidget: Widget {
    let kind = "KalenderWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            KalenderWidgetView(entry: entry)
        }
        .configurationDisplayName("Kalender")
        .description("Zeigt bevorstehende Schulereignisse.")
        .supportedFamilies({
            var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
            if #available(iOSApplicationExtension 16.0, *) { f += [.accessoryCircular, .accessoryRectangular, .accessoryInline] }
            return f
        }())
    }
}

@available(iOSApplicationExtension 17.0, *)
struct KalenderWidgetView: View {
    let entry: CalendarTimelineEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        switch family {
        case .systemSmall:  KalenderSmallView(data: entry.data)
        case .systemMedium: KalenderMediumView(data: entry.data)
        case .systemLarge:  KalenderLargeView(data: entry.data)
        default:
            if #available(iOSApplicationExtension 16.0, *) {
                let next = entry.data?.events.first
                switch family {
                case .accessoryCircular:
                    ZStack {
                        AccessoryWidgetBackground()
                        if let d = next?.startDate {
                            let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
                            Text(days == 0 ? "Heute" : "+\(days)").font(.caption2.bold()).widgetAccentable()
                        } else {
                            Image(systemName: "calendar").widgetAccentable()
                        }
                    }
                case .accessoryRectangular:
                    VStack(alignment: .leading) {
                        if let e = next {
                            Text(e.title).font(.headline).widgetAccentable().lineLimit(1)
                            Text(dayLabel(e.startDate)).font(.caption)
                        } else {
                            Text("Kein Ereignis").font(.caption)
                        }
                    }
                case .accessoryInline:
                    if let e = next { Text("\(dayLabel(e.startDate)): \(e.title)") }
                    else { Text("Keine Ereignisse") }
                default: EmptyView()
                }
            }
        }
    }
}
