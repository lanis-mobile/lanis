import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.2, *)
struct StundenLiveActivityView: View {
    let attributes: LessonActivityAttributes
    let state: LessonActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(attributes.lessonName).font(.headline).bold()
                    }
                    HStack(spacing: 8) {
                        if let room = attributes.room {
                            Label(room, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                        }
                        if let teacher = attributes.teacher {
                            Label(teacher, systemImage: "person").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text(timerInterval: Date()...state.endTime, countsDown: true)
                    .font(.title2.monospacedDigit().bold())
                    .foregroundColor(.accentColor)
                    .frame(width: 70, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3).fill(Color.accentColor).frame(width: geo.size.width * progressFraction, height: 4)
                }
            }.frame(height: 4)

            if let next = state.nextLessonName {
                HStack {
                    Text("Danach: \(next)\(state.nextLessonStart.map { " um \($0)" } ?? "")").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
    }

    private var progressFraction: CGFloat {
        let total = state.endTime.timeIntervalSinceNow + 45 * 60
        let elapsed = total - state.endTime.timeIntervalSinceNow
        return min(max(CGFloat(elapsed / total), 0), 1)
    }
}

@available(iOSApplicationExtension 16.2, *)
struct StundenLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivityAttributes.self) { context in
            StundenLiveActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(context.attributes.lessonName).font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.accentColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let room = context.attributes.room {
                            Label(room, systemImage: "mappin").font(.caption)
                        }
                        if let teacher = context.attributes.teacher {
                            Label(teacher, systemImage: "person").font(.caption)
                        }
                        Spacer()
                        if let next = context.state.nextLessonName {
                            Text("→ \(next)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Text(String(context.attributes.lessonName.prefix(3))).font(.caption.bold())
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 40)
            } minimal: {
                Text(String(context.attributes.lessonName.prefix(2))).font(.caption2.bold())
            }
        }
    }
}
