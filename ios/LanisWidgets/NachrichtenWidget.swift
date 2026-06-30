import WidgetKit
import SwiftUI

struct ConversationsTimelineEntry: TimelineEntry {
    let date: Date
    let data: ConversationsData?
}

struct ConversationsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConversationsTimelineEntry { ConversationsTimelineEntry(date: Date(), data: nil) }
    func getSnapshot(in context: Context, completion: @escaping (ConversationsTimelineEntry) -> Void) {
        completion(ConversationsTimelineEntry(date: Date(), data: WidgetDataReader.conversations()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ConversationsTimelineEntry>) -> Void) {
        let entry = ConversationsTimelineEntry(date: Date(), data: WidgetDataReader.conversations())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

@available(iOSApplicationExtension 17.0, *)
struct NachrichtenSmallView: View {
    let data: ConversationsData?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Nachrichten").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            let count = data?.unreadCount ?? 0
            Text("\(count)").font(.system(size: 36, weight: .bold)).foregroundStyle(count > 0 ? Color.accentColor : Color.secondary)
            Text("Ungelesen").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@available(iOSApplicationExtension 17.0, *)
struct NachrichtenMediumView: View {
    let data: ConversationsData?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Nachrichten").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                let count = data?.unreadCount ?? 0
                if count > 0 {
                    Text("\(count) ungelesen")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            let msgs = Array((data?.latest ?? []).prefix(2))
            if msgs.isEmpty {
                Spacer()
                Text("Keine Nachrichten").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(msgs.indices, id: \.self) { i in
                    let m = msgs[i]
                    HStack(spacing: 6) {
                        Circle().fill(m.isUnread ? Color.accentColor : Color.clear).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(m.sender).font(.caption.bold()).lineLimit(1)
                            Text(m.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
struct NachrichtenLargeView: View {
    let data: ConversationsData?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon").resizable().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Nachrichten").font(.caption).foregroundStyle(.secondary)
                Spacer()
                let count = data?.unreadCount ?? 0
                if count > 0 {
                    Text("\(count) ungelesen").font(.caption2).foregroundStyle(Color.accentColor)
                }
            }
            Divider()
            let msgs = data?.latest ?? []
            if msgs.isEmpty {
                Spacer()
                Text("Keine Nachrichten").foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(msgs.indices, id: \.self) { i in
                    let m = msgs[i]
                    HStack(spacing: 8) {
                        Circle().fill(m.isUnread ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(m.sender).font(.subheadline).bold().lineLimit(1)
                            Text(m.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
struct NachrichtenWidget: Widget {
    let kind = "NachrichtenWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConversationsProvider()) { entry in
            NachrichtenWidgetView(entry: entry)
        }
        .configurationDisplayName("Nachrichten")
        .description("Zeigt ungelesene Nachrichten.")
        .supportedFamilies({
            var f: [WidgetFamily] = [.systemSmall, .systemMedium]
            if #available(iOSApplicationExtension 16.0, *) { f += [.accessoryCircular, .accessoryRectangular, .accessoryInline] }
            return f
        }())
    }
}

@available(iOSApplicationExtension 17.0, *)
struct NachrichtenWidgetView: View {
    let entry: ConversationsTimelineEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            switch family {
            case .systemSmall: NachrichtenSmallView(data: entry.data)
            case .systemMedium: NachrichtenMediumView(data: entry.data)
            default:
                if #available(iOSApplicationExtension 16.0, *) {
                    let count = entry.data?.unreadCount ?? 0
                    switch family {
                    case .accessoryCircular:
                        ZStack {
                            AccessoryWidgetBackground()
                            Text("\(count)").font(.headline.bold()).widgetAccentable()
                        }
                    case .accessoryRectangular:
                        VStack(alignment: .leading) {
                            if let first = entry.data?.latest.first {
                                Text(first.sender).font(.headline).widgetAccentable().lineLimit(1)
                                Text(first.subject).font(.caption).lineLimit(1)
                            } else {
                                Text("Keine Nachrichten").font(.caption)
                            }
                        }
                    case .accessoryInline:
                        Text(count > 0 ? "\(count) ungelesene Nachricht\(count == 1 ? "" : "en")" : "Keine neuen Nachrichten")
                    default: EmptyView()
                    }
                }
            }
        }
        .widgetURL(URL(string: "lanis://applet/nachrichten.php")!)
    }
}

// MARK: - Previews

#if DEBUG
private let previewConvData = ConversationsData(
    updatedAt: "",
    unreadCount: 2,
    latest: [
        ConversationEntry(sender: "Herr Brandt", subject: "Klassenfahrt: Wichtige Infos", isUnread: true),
        ConversationEntry(sender: "Schulleitung", subject: "Informationen zum Schuljahresabschluss", isUnread: false),
        ConversationEntry(sender: "Frau Koch", subject: "Hausaufgaben Deutsch", isUnread: false),
    ]
)

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    NachrichtenWidget()
} timeline: {
    ConversationsTimelineEntry(date: .now, data: previewConvData)
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    NachrichtenWidget()
} timeline: {
    ConversationsTimelineEntry(date: .now, data: previewConvData)
}
#endif
