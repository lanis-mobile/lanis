import Flutter
import WidgetKit
import ActivityKit

class WidgetChannel {
    static let channelName = "io.github.alessioc42.sph/widgets"
    private static let defaults = UserDefaults(suiteName: "group.io.github.alessioc42.sph.widgets")

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "writeData":
                guard let args = call.arguments as? [String: String],
                      let key = args["key"], let value = args["value"] else {
                    result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                    return
                }
                defaults?.set(value, forKey: key)
                result(nil)

            case "reloadWidgets":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)

            case "startLessonActivity":
                if #available(iOS 16.2, *) {
                    guard let json = call.arguments as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                        return
                    }
                    LessonActivityManager.start(json: json, result: result)
                } else {
                    result(nil)
                }

            case "updateLessonActivity":
                if #available(iOS 16.2, *) {
                    guard let json = call.arguments as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                        return
                    }
                    LessonActivityManager.update(json: json, result: result)
                } else {
                    result(nil)
                }

            case "endLessonActivity":
                if #available(iOS 16.2, *) {
                    LessonActivityManager.end(result: result)
                } else {
                    result(nil)
                }

            case "startSubstitutionActivity":
                if #available(iOS 16.2, *) {
                    guard let json = call.arguments as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                        return
                    }
                    SubstitutionActivityManager.start(json: json, result: result)
                } else {
                    result(nil)
                }

            case "endSubstitutionActivity":
                if #available(iOS 16.2, *) {
                    SubstitutionActivityManager.end(result: result)
                } else {
                    result(nil)
                }

            case "getInitialWidget":
                result(AppDelegate.pendingWidgetURL)
                AppDelegate.pendingWidgetURL = nil

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
