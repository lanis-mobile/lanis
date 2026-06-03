import UIKit
import Flutter
import flutter_local_notifications
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  static var pendingWidgetURL: String? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 13.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if let controller = window?.rootViewController as? FlutterViewController {
        WidgetChannel.register(with: controller)
    }

    // End any orphaned substitution live activities left over from a previous
    // app version that still had the VertretungsLiveActivityWidget registered.
    if #available(iOS 16.2, *) {
        Task {
            for activity in Activity<SubstitutionActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "lanis" {
      AppDelegate.pendingWidgetURL = url.absoluteString
    }
    return true
  }
}