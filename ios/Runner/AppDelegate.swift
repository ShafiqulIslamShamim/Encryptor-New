import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let shortcutChannelName = "com.shamim.encryptor/shortcut"
  private static var shortcutTarget: String?
  private static var shortcutChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Cold start from a quick action.
    if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
      AppDelegate.shortcutTarget = AppDelegate.target(for: item)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.shortcutChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { @Sendable (call, result) in
      if call.method == "getShortcutTarget" {
        result(AppDelegate.shortcutTarget)
      } else {
        result(nil)
      }
    }
    AppDelegate.shortcutChannel = channel
  }

  // Quick action tapped while the app was already running.
  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    let target = AppDelegate.target(for: shortcutItem)
    AppDelegate.shortcutTarget = target
    if target == "settings" {
      AppDelegate.shortcutChannel?.invokeMethod(
        "shortcutTargetChanged", arguments: "settings"
      )
    }
    completionHandler(target != nil)
  }

  private static func target(for item: UIApplicationShortcutItem) -> String? {
    switch item.type {
    case "com.shamim.encryptor.home":
      return "home"
    case "com.shamim.encryptor.settings":
      return "settings"
    default:
      return nil
    }
  }
}
