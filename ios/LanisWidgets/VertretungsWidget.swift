import WidgetKit
import SwiftUI

struct SubstitutionTimelineEntry: TimelineEntry {
    let date: Date
    let data: SubstitutionData?
}

struct SubstitutionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SubstitutionTimelineEntry {
        SubstitutionTimelineEntry(date: Date(), data: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (SubstitutionTimelineEntry) -> Void) {
        completion(SubstitutionTimelineEntry(date: Date(), data: WidgetDataReader.substitutions()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SubstitutionTimelineEntry>) -> Void) {
        let entry = SubstitutionTimelineEntry(date: Date(), data: WidgetDataReader.substitutions())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

@available(iOSApplicationExtension 17.0, *)
struct VertretungsSmallView: View {
    let data: SubstitutionData?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Vertretung").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            let count = data?.entries.count ?? 0
            Text("\(count)").font(.system(size: 36, weight: .bold)).foregroundStyle(count > 0 ? Color.red : Color.secondary)
            Text(count == 1 ? "Vertretung" : "Vertretungen").font(.caption).foregroundStyle(.secondary)
            if let first = data?.entries.first {
                Text("\(first.stunde). Std · \(first.art ?? "")").font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@available(iOSApplicationExtension 17.0, *)
struct VertretungsMediumView: View {
    let data: SubstitutionData?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Vertretungen").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let date = data?.date { Text(date).font(.caption2).foregroundStyle(.tertiary) }
            }
            let entries = Array((data?.entries ?? []).prefix(3))
            if entries.isEmpty {
                Spacer()
                Text("Keine Vertretungen").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entries.indices, id: \.self) { i in
                    let e = entries[i]
                    HStack(spacing: 6) {
                        Text("\(e.stunde).")
                            .font(.caption.monospacedDigit()).bold()
                            .frame(width: 20, alignment: .trailing)
                        Text(e.fach ?? "–").font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(e.art ?? "").font(.caption).foregroundStyle(.secondary)
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
struct VertretungsLargeView: View {
    let data: SubstitutionData?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image("AppIcon").resizable().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Vertretungen heute").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let date = data?.date { Text(date).font(.caption2).foregroundStyle(.tertiary) }
            }
            Divider()
            let entries = data?.entries ?? []
            if entries.isEmpty {
                Spacer()
                Text("Keine Vertretungen").foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entries.indices, id: \.self) { i in
                    let e = entries[i]
                    HStack(spacing: 8) {
                        Text("\(e.stunde).")
                            .font(.caption2.monospacedDigit()).bold()
                            .frame(width: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.fach ?? "–").font(.subheadline).bold().lineLimit(1)
                            HStack(spacing: 4) {
                                if let art = e.art { Text(art).font(.caption2).foregroundStyle(.red) }
                                if let raum = e.raum { Text("→ \(raum)").font(.caption2).foregroundStyle(.secondary) }
                                if let v = e.vertreter { Text(v).font(.caption2).foregroundStyle(.secondary) }
                            }
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
struct VertretungsWidget: Widget {
    let kind = "VertretungsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SubstitutionProvider()) { entry in
            VertretungsWidgetView(entry: entry)
        }
        .configurationDisplayName("Vertretungen")
        .description("Zeigt deine heutigen Vertretungen.")
        .supportedFamilies(supportedFamilies)
    }
    private var supportedFamilies: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOSApplicationExtension 16.0, *) { f += [.accessoryCircular, .accessoryRectangular, .accessoryInline] }
        return f
    }
}

@available(iOSApplicationExtension 17.0, *)
struct VertretungsWidgetView: View {
    let entry: SubstitutionTimelineEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            switch family {
            case .systemSmall: VertretungsSmallView(data: entry.data)
            case .systemMedium: VertretungsMediumView(data: entry.data)
            case .systemLarge: VertretungsLargeView(data: entry.data)
            default:
                if #available(iOSApplicationExtension 16.0, *) {
                    let count = entry.data?.entries.count ?? 0
                    switch family {
                    case .accessoryCircular:
                        ZStack {
                            AccessoryWidgetBackground()
                            Text("\(count)").font(.headline.bold()).widgetAccentable()
                        }
                    case .accessoryRectangular:
                        VStack(alignment: .leading) {
                            if let first = entry.data?.entries.first {
                                Text("\(first.stunde). Std · \(first.art ?? "")").font(.headline).widgetAccentable()
                                Text(first.fach ?? "–").font(.caption)
                            } else {
                                Text("Keine Vertretungen").font(.caption)
                            }
                        }
                    case .accessoryInline:
                        Text(count > 0 ? "\(count) Vertretung\(count == 1 ? "" : "en") heute" : "Keine Vertretungen")
                    default: EmptyView()
                    }
                }
            }
        }
        .widgetURL(URL(string: "lanis://applet/vertretungsplan.php")!)
    }
}

// MARK: - Previews

#if DEBUG
private let previewSubData = SubstitutionData(
    updatedAt: "",
    date: "03.06.2026",
    entries: [
        SubstitutionEntry(stunde: "3", fach: "Mathematik", art: "Vertretung", raum: "204", vertreter: "Schmidt"),
        SubstitutionEntry(stunde: "5", fach: "Englisch", art: "Ausfall", raum: nil, vertreter: nil),
        SubstitutionEntry(stunde: "6", fach: "Sport", art: "Raumänderung", raum: "Halle 2", vertreter: "Hoffmann"),
    ]
)

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    VertretungsWidget()
} timeline: {
    SubstitutionTimelineEntry(date: .now, data: previewSubData)
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    VertretungsWidget()
} timeline: {
    SubstitutionTimelineEntry(date: .now, data: previewSubData)
}

@available(iOS 17.0, *)
#Preview("Large", as: .systemLarge) {
    VertretungsWidget()
} timeline: {
    SubstitutionTimelineEntry(date: .now, data: previewSubData)
}
#endif

