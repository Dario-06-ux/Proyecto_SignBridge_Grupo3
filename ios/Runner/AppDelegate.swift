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

    let channel = FlutterMethodChannel(
      name: "com.example.detector_senas/sign_vision",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "init":
        result([
          "ok": false,
          "error": "ios_stub",
          "hint": "MediaPipe Hand Landmarker is not bundled on iOS in this build (Android-first).",
        ])
      case "detect":
        result([
          "ok": false,
          "error": "ios_stub",
        ])
      case "dispose":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
