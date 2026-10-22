import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IconSwitcher") else {
      return
    }
    FlutterMethodChannel(name: "app/icon_switcher", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        AppDelegate.handleIconSwitcher(call: call, result: result)
      }
  }

  // Alternate icon sets live in Assets.xcassets (Weather, Notes, Calendar, Calculator) and are
  // listed in the ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES build setting.
  private static let alternateIcons = [
    "weather": "Weather", "notes": "Notes", "calendar": "Calendar", "calculator": "Calculator",
  ]

  private static func handleIconSwitcher(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setIcon", let name = call.arguments as? String else {
      result(FlutterMethodNotImplemented)
      return
    }
    if name != "default" && alternateIcons[name] == nil {
      result(FlutterError(code: "bad_icon", message: "Unknown icon \(name)", details: nil))
      return
    }
    guard UIApplication.shared.supportsAlternateIcons else {
      result(FlutterError(code: "unsupported", message: "Alternate icons not supported", details: nil))
      return
    }
    let iconName = name == "default" ? nil : alternateIcons[name]
    if UIApplication.shared.alternateIconName == iconName {
      result(nil)
      return
    }
    UIApplication.shared.setAlternateIconName(iconName) { error in
      // The completion handler may run off the main thread; Flutter results must not.
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "set_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }
}
