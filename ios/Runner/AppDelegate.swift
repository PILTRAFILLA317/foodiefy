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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FoodiefyShareInbox") {
      let channel = FlutterMethodChannel(name: "foodiefy/share", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        do {
          switch call.method {
          case "peek": result(try ShareInbox.peek())
          case "ack":
            if let id = call.arguments as? String { try ShareInbox.ack(id) }
            result(nil)
          default: result(FlutterMethodNotImplemented)
          }
        } catch { result(FlutterError(code: "share_unavailable", message: "App Group unavailable", details: nil)) }
      }
    }
  }
}
