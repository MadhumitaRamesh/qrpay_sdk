import 'package:flutter/services.dart';
import '../qrpay_sdk_platform_interface.dart';

class MethodChannelQrpaySdk extends QrpaySdkPlatform {
  final methodChannel = const MethodChannel('qrpay_sdk/control');
  final eventChannel = const EventChannel('qrpay_sdk/events');

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    await methodChannel.invokeMethod('initialize', config);
  }

  @override
  Future<void> dispose() async {
    await methodChannel.invokeMethod('dispose');
  }

  @override
  Stream<dynamic> startScanning() {
    return eventChannel.receiveBroadcastStream();
  }

  @override
  Future<void> stopScanning() async {
    await methodChannel.invokeMethod('stopScanning');
  }

  @override
  Future<void> setTorch(bool on) async {
    await methodChannel.invokeMethod('setTorch', {'on': on});
  }

  @override
  Future<void> setZoom(double ratio) async {
    await methodChannel.invokeMethod('setZoom', {'ratio': ratio});
  }
}
