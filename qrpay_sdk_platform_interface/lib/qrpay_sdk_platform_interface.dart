import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'src/method_channel_qrpay_sdk.dart';

abstract class QrpaySdkPlatform extends PlatformInterface {
  /// Constructs a QrpaySdkPlatform.
  QrpaySdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static QrpaySdkPlatform _instance = MethodChannelQrpaySdk();

  /// The default instance of [QrpaySdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelQrpaySdk].
  static QrpaySdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QrpaySdkPlatform] when
  /// they register themselves.
  static set instance(QrpaySdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(Map<String, dynamic> config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Stream<dynamic> startScanning() {
    throw UnimplementedError('startScanning() has not been implemented.');
  }

  Future<void> stopScanning() {
    throw UnimplementedError('stopScanning() has not been implemented.');
  }

  Future<void> setTorch(bool on) {
    throw UnimplementedError('setTorch() has not been implemented.');
  }

  Future<void> setZoom(double ratio) {
    throw UnimplementedError('setZoom() has not been implemented.');
  }
}
