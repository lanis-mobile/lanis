import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.2, *)
struct StundenLiveActivityView: View {
    let attributes: LessonActivityAttributes
    let state: LessonActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .lesson:
            lessonView
        case .break:
            breakView
        case .dayEnd:
            dayEndView
        }
    }

    // MARK: Lesson view (current behaviour)
    private var lessonView: some View {
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
                Text(timerInterval: Date()...state.phaseEndTime, countsDown: true)
                    .font(.title2.monospacedDigit().bold())
                    .foregroundColor(.accentColor)
                    .frame(width: 70, alignment: .trailing)
            }

            progressBar

            if let next = state.nextLessonName {
                HStack {
                    Text("Danach: \(next)\(state.nextLessonStart.map { " um \($0)" } ?? "")").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
    }

    // MARK: Break view
    private var breakView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(timerInterval: Date()...state.phaseEndTime, countsDown: true)
                            .font(.title2.monospacedDigit().bold())
                            .foregroundColor(.accentColor)
                        if let name = state.nextLessonName {
                            Text("· \(name)").font(.headline).bold()
                        }
                    }
                    HStack(spacing: 8) {
                        if let room = state.nextLessonRoom {
                            Label(room, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                        }
                        if let teacher = state.nextLessonTeacher {
                            Label(teacher, systemImage: "person").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }

            progressBar
        }
        .padding()
    }

    // MARK: Day end view
    private var dayEndView: some View {
        HStack(spacing: 10) {
            Image("AppIcon").resizable().frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Schultag beendet").font(.headline).bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Progress bar (shared)
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 4)
                RoundedRectangle(cornerRadius: 3).fill(Color.accentColor).frame(width: geo.size.width * progressFraction, height: 4)
            }
        }.frame(height: 4)
    }

    private var progressFraction: CGFloat {
        let total = state.phaseEndTime.timeIntervalSince(state.phaseStartTime)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(state.phaseStartTime)
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
                        switch context.state.phase {
                        case .lesson:
                            Text(context.attributes.lessonName).font(.headline)
                        case .break:
                            Text(context.state.nextLessonName ?? "Pause").font(.headline)
                        case .dayEnd:
                            Text("Schultag beendet").font(.headline)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    switch context.state.phase {
                    case .lesson, .break:
                        Text(timerInterval: Date()...context.state.phaseEndTime, countsDown: true)
                            .font(.headline.monospacedDigit())
                            .foregroundColor(.accentColor)
                    case .dayEnd:
                        EmptyView()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        switch context.state.phase {
                        case .lesson:
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
                        case .break:
                            if let room = context.state.nextLessonRoom {
                                Label(room, systemImage: "mappin").font(.caption)
                            }
                            if let teacher = context.state.nextLessonTeacher {
                                Label(teacher, systemImage: "person").font(.caption)
                            }
                            Spacer()
                        case .dayEnd:
                            Spacer()
                        }
                    }
                }
            } compactLeading: {
                switch context.state.phase {
                case .lesson:
                    Text(String(context.attributes.lessonName.prefix(3))).font(.caption.bold())
                case .break:
                    Text(String((context.state.nextLessonName ?? "").prefix(3))).font(.caption.bold())
                case .dayEnd:
                    Text("—").font(.caption.bold())
                }
            } compactTrailing: {
                switch context.state.phase {
                case .lesson, .break:
                    Text(timerInterval: Date()...context.state.phaseEndTime, countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40)
                case .dayEnd:
                    EmptyView()
                }
            } minimal: {
                switch context.state.phase {
                case .lesson:
                    Text(String(context.attributes.lessonName.prefix(2)))
                        .font(.system(size: 15, weight: .bold))
                case .break:
                    Text(String((context.state.nextLessonName ?? "").prefix(2)))
                        .font(.system(size: 15, weight: .bold))
                case .dayEnd:
                    Image(systemName: "checkmark").font(.caption.bold())
                }
            }
        }
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Lock Screen – Lesson", as: .content, using: LessonActivityAttributes(
    lessonName: "Mathematik",
    teacher: "Müller",
    room: "204"
)) {
    StundenLiveActivityWidget()
} contentStates: {
    LessonActivityAttributes.ContentState(
        phase: .lesson,
        phaseStartTime: Date().addingTimeInterval(-20 * 60),
        phaseEndTime: Date().addingTimeInterval(25 * 60),
        nextLessonName: "Deutsch",
        nextLessonRoom: "101",
        nextLessonTeacher: "Schmidt",
        nextLessonStart: "09:30"
    )
}

@available(iOS 17.0, *)
#Preview("Lock Screen – Break", as: .content, using: LessonActivityAttributes(
    lessonName: "Mathematik",
    teacher: "Müller",
    room: "204"
)) {
    StundenLiveActivityWidget()
} contentStates: {
    LessonActivityAttributes.ContentState(
        phase: .break,
        phaseStartTime: Date().addingTimeInterval(-3 * 60),
        phaseEndTime: Date().addingTimeInterval(7 * 60),
        nextLessonName: "Deutsch",
        nextLessonRoom: "101",
        nextLessonTeacher: "Schmidt",
        nextLessonStart: "09:30"
    )
}

@available(iOS 17.0, *)
#Preview("Lock Screen – Day End", as: .content, using: LessonActivityAttributes(
    lessonName: "Mathematik",
    teacher: "Müller",
    room: "204"
)) {
    StundenLiveActivityWidget()
} contentStates: {
    LessonActivityAttributes.ContentState(
        phase: .dayEnd,
        phaseStartTime: Date(),
        phaseEndTime: Date().addingTimeInterval(50),
        nextLessonName: nil,
        nextLessonRoom: nil,
        nextLessonTeacher: nil,
        nextLessonStart: nil
    )
}

@available(iOS 17.0, *)
#Preview("Dynamic Island Expanded – Break", as: .dynamicIsland(.expanded), using: LessonActivityAttributes(
    lessonName: "Mathematik",
    teacher: "Müller",
    room: "204"
)) {
    StundenLiveActivityWidget()
} contentStates: {
    LessonActivityAttributes.ContentState(
        phase: .break,
        phaseStartTime: Date().addingTimeInterval(-3 * 60),
        phaseEndTime: Date().addingTimeInterval(7 * 60),
        nextLessonName: "Deutsch",
        nextLessonRoom: "101",
        nextLessonTeacher: "Schmidt",
        nextLessonStart: "09:30"
    )
}
