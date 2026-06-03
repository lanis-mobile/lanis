import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.2, *)
struct VertretungsLiveActivityView: View {
    let attributes: SubstitutionActivityAttributes
    let state: SubstitutionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                Text("\(state.count) neue\(state.count == 1 ? " Vertretung" : " Vertretungen")")
                    .font(.headline).bold()
                Spacer()
                Text(attributes.date).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(state.entries.prefix(3).indices, id: \.self) { i in
                let e = state.entries[i]
                HStack(spacing: 6) {
                    Text("\(e.stunde).").font(.caption.bold().monospacedDigit()).frame(width: 20, alignment: .trailing)
                    Text(e.fach ?? "–").font(.subheadline).lineLimit(1)
                    Spacer()
                    Text(e.art ?? "").font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding()
    }
}

@available(iOSApplicationExtension 16.2, *)
struct VertretungsLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SubstitutionActivityAttributes.self) { context in
            VertretungsLiveActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text("Vertretungen").font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.count)").font(.title2.bold()).foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(context.state.entries.prefix(2).indices, id: \.self) { i in
                            let e = context.state.entries[i]
                            HStack {
                                Text("\(e.stunde). \(e.fach ?? "–")").font(.caption)
                                Spacer()
                                Text(e.art ?? "").font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow).font(.caption)
            } compactTrailing: {
                Text("\(context.state.count)").font(.caption.bold()).foregroundColor(.red)
            } minimal: {
                Text("\(context.state.count)").font(.caption2.bold()).foregroundColor(.red)
            }
        }
    }
}
