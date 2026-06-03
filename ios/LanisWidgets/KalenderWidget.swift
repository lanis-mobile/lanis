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

private func formatEventDate(_ date: Date?) -> String {
    guard let date else { return "" }
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Heute" }
    if cal.isDateInTomorrow(date) { return "Morgen" }
    if #available(iOSApplicationExtension 15.0, *) {
        return date.formatted(.dateTime.day().month())
    }
    let f = DateFormatter()
    f.dateFormat = "d. MMM"
    return f.string(from: date)
}

@available(iOSApplicationExtension 17.0, *)
struct KalenderSmallView: View {
    let data: CalendarData?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Kalender").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let event = data?.events.first {
                Text(event.title).font(.subheadline).bold().lineLimit(2)
                Text(formatEventDate(event.startDate)).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Keine Ereignisse").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@available(iOSApplicationExtension 17.0, *)
struct KalenderMediumView: View {
    let data: CalendarData?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Kalender").font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            let events = Array((data?.events ?? []).prefix(3))
            if events.isEmpty {
                Spacer()
                Text("Keine bevorstehenden Ereignisse").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(events.indices, id: \.self) { i in
                    let e = events[i]
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(e.accentColor).frame(width: 3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.title).font(.subheadline).bold().lineLimit(1)
                            Text(formatEventDate(e.startDate)).font(.caption).foregroundStyle(.secondary)
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

@available(iOSApplicationExtension 17.0, *)
struct KalenderLargeView: View {
    let data: CalendarData?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon").resizable().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Kalender").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Divider()
            let events = Array((data?.events ?? []).prefix(7))
            if events.isEmpty {
                Spacer()
                Text("Keine bevorstehenden Ereignisse").foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(events.indices, id: \.self) { i in
                    let e = events[i]
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(e.accentColor).frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.title).font(.subheadline).bold().lineLimit(1)
                            Text(formatEventDate(e.startDate)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

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
        case .systemSmall: KalenderSmallView(data: entry.data)
        case .systemMedium: KalenderMediumView(data: entry.data)
        case .systemLarge: KalenderLargeView(data: entry.data)
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
                            Text(formatEventDate(e.startDate)).font(.caption)
                        } else {
                            Text("Kein Ereignis").font(.caption)
                        }
                    }
                case .accessoryInline:
                    if let e = next { Text("\(formatEventDate(e.startDate)): \(e.title)") }
                    else { Text("Keine Ereignisse") }
                default: EmptyView()
                }
            }
        }
    }
}
