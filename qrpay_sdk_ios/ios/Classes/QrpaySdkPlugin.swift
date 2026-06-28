import Flutter
import UIKit

public class QrpaySdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var pipeline: CameraPipeline?

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
      if pipeline == nil {
          pipeline = CameraPipeline(eventSink: { [weak self] in self?.eventSink })
      }
      pipeline?.initializeAsync()
      result(nil)
    case "dispose":
      pipeline?.shutdownPipeline()
      pipeline = nil
      result(nil)
    case "startScanning":
      let textureId = pipeline?.startScanning() ?? -1
      result(textureId)
    case "stopScanning":
      pipeline?.shutdownPipeline()
      result(nil)
    case "setTorch":
      let args = call.arguments as? [String: Any]
      let on = args?["on"] as? Bool ?? false
      pipeline?.setTorch(on: on)
      result(nil)
    case "setZoom":
      let args = call.arguments as? [String: Any]
      let ratio = args?["ratio"] as? Double ?? 1.0
      pipeline?.setZoom(ratio: ratio)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
