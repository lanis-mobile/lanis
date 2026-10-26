import Flutter
import UIKit
import UserNotifications
import XCTest

class RunnerTests: XCTestCase {

  func testSceneLaunchesFlutterWithRegisteredPlugins() throws {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
    )
    let delegate = try XCTUnwrap(scene.delegate as? FlutterSceneDelegate)
    let window = try XCTUnwrap(delegate.window)
    XCTAssertTrue(window.windowScene === scene)

    let controller = try XCTUnwrap(window.rootViewController as? FlutterViewController)
    let engine = try XCTUnwrap(controller.engine)
    XCTAssertNotNil(engine.isolateId)
    // These plugins are needed during Dart startup. Registration must happen
    // when the scene creates its engine, before Dart invokes their channels.
    for plugin in [
      "BackgroundFetchPlugin",
      "FlutterLocalNotificationsPlugin",
      "FlutterSecureStorageDarwinPlugin",
    ] {
      XCTAssertTrue(engine.hasPlugin(plugin), "Missing startup plugin: \(plugin)")
    }
  }

  func testNotificationDelegateRemainsTheAppDelegate() {
    XCTAssertTrue(
      UNUserNotificationCenter.current().delegate === UIApplication.shared.delegate
    )
  }

}
