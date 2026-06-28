import Flutter
import UIKit

public class QrpaySdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "qrpay_sdk/control", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "qrpay_sdk/events", binaryMessenger: registrar.messenger())
    
    let instance = QrpaySdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      // TODO: Implement camera pre-warm and configuration via AVFoundation
      // Corresponds to Android initializeAsync()
      result(nil)
    case "dispose":
      // TODO: Release camera resources
      // Corresponds to Android shutdownPipeline()
      result(nil)
    case "startScanning":
      // TODO: Bind use cases, start AVCaptureSession, emit texture ID
      // Corresponds to Android startScanning()
      // Needs to emit: camera-ready, started, camera-interrupted, camera-unrecoverable, permission-revoked, permission-denied
      result(-1) // Stub texture ID
    case "stopScanning":
      // TODO: Stop capture session
      // Needs to emit: stopped, releaseLocation
      result(nil)
    case "setTorch":
      // let on = args?["on"] as? Bool ?? false
      // TODO: set torch logic
      result(nil)
    case "setZoom":
      // let args = call.arguments as? [String: Any]
      // let ratio = args?["ratio"] as? Double ?? 1.0
      // TODO: set zoom logic
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    // TODO: wire up events logic
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
