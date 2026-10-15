import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Opens the phone app with a number (hospitals, 112). Mirrors the
    // Android "elan/phone" channel in MainActivity.kt.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "elan/phone", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "dial",
          let args = call.arguments as? [String: Any],
          let raw = args["number"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        let digits = raw.filter { "0123456789+".contains($0) }
        guard let url = URL(string: "tel://\(digits)") else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in result(opened) }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
