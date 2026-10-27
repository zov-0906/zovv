import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var cacheChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZovvIosCache") {
      let channel = FlutterMethodChannel(name: "zovv/ios-cache", binaryMessenger: registrar.messenger())
      cacheChannel = channel
      channel.setMethodCallHandler { call, result in
        guard call.method == "directory" else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          var folder = try FileManager.default.url(for: .cachesDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ZovvVideoSegments", isDirectory: true)
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try folder.setResourceValues(values)
          result(folder.path)
        } catch {
          result(FlutterError(code: "CACHE_UNAVAILABLE", message: "Video cache unavailable", details: nil))
        }
      }
    }
  }
}
