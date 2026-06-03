import ActivityKit
import Flutter
import Foundation

@available(iOS 16.2, *)
struct SubstitutionActivityJson: Decodable {
    let date: String
    let newEntries: [LiveSubstitutionEntry]
}

@available(iOS 16.2, *)
enum SubstitutionActivityManager {
    private static var currentActivity: Activity<SubstitutionActivityAttributes>?

    static func start(json: String, result: @escaping FlutterResult) {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SubstitutionActivityJson.self, from: data)
        else {
            result(FlutterError(code: "PARSE_ERROR", message: "Could not parse substitution json", details: nil))
            return
        }

        let attrs = SubstitutionActivityAttributes(date: payload.date)
        let state = SubstitutionActivityAttributes.ContentState(
            entries: payload.newEntries,
            count: payload.newEntries.count
        )

        do {
            currentActivity = try Activity.request(
                attributes: attrs,
                contentState: state,
                pushType: nil
            )
            result(nil)
        } catch {
            result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    static func end(result: @escaping FlutterResult) {
        guard let activity = currentActivity else {
            result(nil)
            return
        }
        Task {
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            result(nil)
        }
    }
}
