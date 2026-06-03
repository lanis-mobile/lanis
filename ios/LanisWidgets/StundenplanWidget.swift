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

// MARK: - Shared helpers

private func nowMinutes() -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

private func toMinutes(_ time: String) -> Int {
    let parts = time.split(separator: ":").compactMap { Int($0) }
    return (parts.first ?? 0) * 60 + (parts.last ?? 0)
}

private func progressInLesson(_ entry: TimetableEntry) -> Double {
    let now = nowMinutes()
    let start = toMinutes(entry.start)
    let end = toMinutes(entry.end)
    guard end > start else { return 0 }
    return min(1, max(0, Double(now - start) / Double(end - start)))
}

private func isOngoing(_ entry: TimetableEntry) -> Bool {
    let now = nowMinutes()
    return now >= toMinutes(entry.start) && now < toMinutes(entry.end)
}

private func isUpcoming(_ entry: TimetableEntry) -> Bool {
    return toMinutes(entry.start) > nowMinutes()
}

// Compute text color like the app: white on dark, black on light
private func labelColor(for bg: Color) -> Color {
    // SwiftUI Color doesn't expose luminance directly — use a heuristic via UIColor
    let ui = UIColor(bg)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return luminance > 0.5 ? .black : .white
}

// MARK: - Lesson block (mirrors app's ItemBlock)

/// Replicates the app's colored rounded rectangle with name + teacher + room.
@available(iOSApplicationExtension 16.0, *)
private struct LessonBlock: View {
    let entry: TimetableEntry
    /// Height in points; nil = intrinsic
    var fixedHeight: CGFloat? = nil
    var showTime: Bool = true
    var compact: Bool = false

    private var bg: Color { entry.accentColor }
    private var fg: Color { labelColor(for: bg) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(bg)

            // Progress bar overlay for ongoing lesson
            if isOngoing(entry) {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.black.opacity(0.15))
                            .frame(height: geo.size.height * (1 - progressInLesson(entry)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: compact ? 0 : 1) {
                // Name + teacher row (same as app's Wrap)
                HStack(alignment: .top) {
                    Text(entry.name)
                        .font(.system(size: compact ? 10 : 12, weight: .semibold))
                        .foregroundStyle(fg)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if let teacher = entry.teacher, !compact {
                        Text(teacher)
                            .font(.system(size: 11))
                            .foregroundStyle(fg.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                if let room = entry.room {
                    Text(room)
                        .font(.system(size: compact ? 9 : 11))
                        .foregroundStyle(fg.opacity(0.85))
                        .lineLimit(1)
                }
                if showTime && !compact {
                    Text("\(entry.start)–\(entry.end)")
                        .font(.system(size: 10))
                        .foregroundStyle(fg.opacity(0.7))
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
        }
        .frame(height: fixedHeight)
    }
}

// MARK: - Row with stunde indicator (mirrors app's left column + block)

@available(iOSApplicationExtension 16.0, *)
private struct LessonRow: View {
    let entry: TimetableEntry
    var highlightOngoing: Bool = true

    private var ongoing: Bool { isOngoing(entry) }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Left: stunde + time (mirrors app's hourWidth column)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.stunde).")
                    .font(.system(size: 12, weight: ongoing ? .bold : .regular, design: .rounded))
                    .foregroundStyle(ongoing ? Color.accentColor : .primary)
                Text(entry.start)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30, alignment: .trailing)

            // Right: colored block
            LessonBlock(entry: entry, showTime: false)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Small: current/next lesson as a prominent block

@available(iOSApplicationExtension 17.0, *)
struct TimetableSmallView: View {
    let data: TimetableData?

    private var featured: TimetableEntry? {
        data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
    }
    private var next: TimetableEntry? {
        guard let f = featured else { return nil }
        let idx = data?.today.firstIndex(where: { $0.name == f.name && $0.start == f.start })
        guard let i = idx, i + 1 < (data?.today.count ?? 0) else { return nil }
        return data?.today[i + 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: "Jetzt" / "Nächste"
            HStack {
                Text(featured != nil && isOngoing(featured!) ? "Jetzt" : "Nächste Stunde")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(Date(), style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let lesson = featured {
                LessonBlock(entry: lesson, fixedHeight: nil, showTime: true, compact: false)
                    .frame(maxHeight: .infinity)
            } else {
                Spacer()
                Text("Keine weiteren\nStunden heute")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            }

            // Next lesson hint
            if let n = next {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(n.accentColor)
                        .frame(width: 3, height: 12)
                    Text("Dann: \(n.name) · \(n.start)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium: 3 lessons as rows (stunde + block)

@available(iOSApplicationExtension 17.0, *)
struct TimetableMediumView: View {
    let data: TimetableData?

    private var visible: [TimetableEntry] {
        let all = data?.today ?? []
        let now = nowMinutes()
        // prefer ongoing + next 2, else next 3
        let relevant = all.filter { toMinutes($0.end) > now }
        return Array(relevant.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Stundenplan heute")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if visible.isEmpty {
                Spacer()
                Text("Keine weiteren Stunden heute")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(visible.indices, id: \.self) { i in
                    LessonRow(entry: visible[i])
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large: all today's lessons

@available(iOSApplicationExtension 17.0, *)
struct TimetableLargeView: View {
    let data: TimetableData?

    private var lessons: [TimetableEntry] { data?.today ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Stundenplan heute")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Divider()

            if lessons.isEmpty {
                Spacer()
                Text("Keine Stunden heute")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(lessons.indices, id: \.self) { i in
                    LessonRow(entry: lessons[i])
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen Views (unchanged)

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

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    StundenplanWidget()
} timeline: {
    TimetableTimelineEntry(date: .now, data: TimetableData(
        updatedAt: "",
        today: [
            TimetableEntry(name: "Mathematik", room: "204", teacher: "Müller", start: "07:55", end: "08:40", stunde: 1, color: "#E53935"),
            TimetableEntry(name: "Deutsch", room: "101", teacher: "Koch", start: "08:45", end: "09:30", stunde: 2, color: "#1E88E5"),
            TimetableEntry(name: "Englisch", room: "102", teacher: "Weber", start: "09:50", end: "10:35", stunde: 3, color: "#43A047"),
            TimetableEntry(name: "Biologie", room: "301", teacher: "Fischer", start: "10:40", end: "11:25", stunde: 4, color: "#8E24AA"),
            TimetableEntry(name: "Sport", room: "Halle", teacher: "Hoffmann", start: "11:40", end: "12:25", stunde: 5, color: "#FB8C00"),
            TimetableEntry(name: "Musik", room: "103", teacher: "Braun", start: "12:30", end: "13:15", stunde: 6, color: "#00897B"),
        ],
        currentLesson: TimetableEntry(name: "Mathematik", room: "204", teacher: "Müller", start: "07:55", end: "08:40", stunde: 1, color: "#E53935")
    ))
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    StundenplanWidget()
} timeline: {
    TimetableTimelineEntry(date: .now, data: TimetableData(
        updatedAt: "",
        today: [
            TimetableEntry(name: "Mathematik", room: "204", teacher: "Müller", start: "07:55", end: "08:40", stunde: 1, color: "#E53935"),
            TimetableEntry(name: "Deutsch", room: "101", teacher: "Koch", start: "08:45", end: "09:30", stunde: 2, color: "#1E88E5"),
            TimetableEntry(name: "Englisch", room: "102", teacher: "Weber", start: "09:50", end: "10:35", stunde: 3, color: "#43A047"),
            TimetableEntry(name: "Biologie", room: "301", teacher: "Fischer", start: "10:40", end: "11:25", stunde: 4, color: "#8E24AA"),
            TimetableEntry(name: "Sport", room: "Halle", teacher: "Hoffmann", start: "11:40", end: "12:25", stunde: 5, color: "#FB8C00"),
            TimetableEntry(name: "Musik", room: "103", teacher: "Braun", start: "12:30", end: "13:15", stunde: 6, color: "#00897B"),
        ],
        currentLesson: TimetableEntry(name: "Mathematik", room: "204", teacher: "Müller", start: "07:55", end: "08:40", stunde: 1, color: "#E53935")
    ))
}

@available(iOS 17.0, *)
#Preview("Large", as: .systemLarge) {
    StundenplanWidget()
} timeline: {
    TimetableTimelineEntry(date: .now, data: TimetableData(
        updatedAt: "",
        today: [
            TimetableEntry(name: "Mathematik", room: "204", teacher: "Müller", start: "07:55", end: "08:40", stunde: 1, color: "#E53935"),
            TimetableEntry(name: "Deutsch", room: "101", teacher: "Koch", start: "08:45", end: "09:30", stunde: 2, color: "#1E88E5"),
            TimetableEntry(name: "Englisch", room: "102", teacher: "Weber", start: "09:50", end: "10:35", stunde: 3, color: "#43A047"),
            TimetableEntry(name: "Biologie", room: "301", teacher: "Fischer", start: "10:40", end: "11:25", stunde: 4, color: "#8E24AA"),
            TimetableEntry(name: "Sport", room: "Halle", teacher: "Hoffmann", start: "11:40", end: "12:25", stunde: 5, color: "#FB8C00"),
            TimetableEntry(name: "Musik", room: "103", teacher: "Braun", start: "12:30", end: "13:15", stunde: 6, color: "#00897B"),
        ],
        currentLesson: nil
    ))
}
