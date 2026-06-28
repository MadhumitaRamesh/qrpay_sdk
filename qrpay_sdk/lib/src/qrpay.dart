import 'dart:async';
import 'package:qrpay_sdk_platform_interface/qrpay_sdk_platform_interface.dart';
import 'config/qrpay_config.dart';
import 'config/config_validator.dart';
import 'model/scan_result.dart';
import 'model/qrpay_error.dart';
import 'parser/payment_parser.dart';
import 'state/location_state.dart';

enum LifecycleEvent { started, paused, resumed, stopped }

sealed class ScanEvent {}

class ScanEventTexture extends ScanEvent {
  final int textureId;
  ScanEventTexture(this.textureId);
}

class ScanEventResult extends ScanEvent {
  final ScanResult result;
  final double boundingRatio;
  ScanEventResult(this.result, this.boundingRatio);
}

class ScanEventError extends ScanEvent {
  final QRPayError error;
  ScanEventError(this.error);
}

class ScanEventLifecycle extends ScanEvent {
  final LifecycleEvent event;
  ScanEventLifecycle(this.event);
}

/// Main entry point for the QRPay SDK.
///
/// Use [initialize] to set up the SDK before calling [startScanning].
/// Example:
/// ```dart
/// await QRPay.initialize(QRPayConfig(overlayStyle: OverlayStyle.dark()));
/// ```
class QRPay {
  static final StreamController<bool> _torchStateController = StreamController<bool>.broadcast();
  static final StreamController<double> _zoomLevelController = StreamController<double>.broadcast();
  static final StreamController<String> _thermalStateController = StreamController<String>.broadcast();

  /// Stream broadcasting the current torch state (true if on).
  static Stream<bool> get torchState => _torchStateController.stream;

  /// Stream broadcasting the current native zoom level factor.
  static Stream<double> get zoomLevel => _zoomLevelController.stream;

  /// Stream broadcasting the hardware thermal state ('normal', 'fair', 'serious', 'critical').
  static Stream<String> get thermalState => _thermalStateController.stream;
  
  static QRPayConfig? _config;
  static bool _isDisposed = false;

  /// Initializes the native camera pipeline and prepares for scanning.
  /// Pre-warms the camera asynchronously to achieve fast startup times.
  static Future<void> initialize(QRPayConfig config) async {
    _isDisposed = false;
    final validation = ConfigValidator.validate(config);
    if (validation.isError) {
      throw Exception('Invalid config: ${validation.error?.field} - ${validation.error?.reason}');
    }
    
    _config = config;

    final configMap = <String, dynamic>{
      'supportedSchemes': config.supportedSchemes,
      'autoZoomEnabled': config.autoZoomEnabled,
      'autoZoomThreshold': config.autoZoomThreshold,
      'maxDigitalZoom': config.maxDigitalZoom,
      'autoZoomTimeout': config.autoZoomTimeout.inMilliseconds,
      'scanSessionTimeout': config.scanSessionTimeout.inMilliseconds,
      'torchDefaultOn': config.torchDefaultOn,
      'locationEnabled': config.locationEnabled,
      'locationCacheMaxAge': config.locationCacheMaxAge.inMilliseconds,
    };
    
    await QrpaySdkPlatform.instance.initialize(configMap);
  }

  /// Disposes of the native camera resources.
  /// Safe to call multiple times.
  static Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _sessionTimer?.cancel();
    await QrpaySdkPlatform.instance.dispose();
  }

  static Timer? _sessionTimer;

  /// Starts the camera stream and barcode detection.
  /// Returns a stream of [ScanEvent] to track lifecycle, errors, and results.
  static Stream<ScanEvent> startScanning() {
    _sessionTimer?.cancel();

    late StreamController<ScanEvent> controller;
    StreamSubscription? sub;

    controller = StreamController<ScanEvent>(
      onListen: () {
        sub = QrpaySdkPlatform.instance.startScanning().listen((event) async {
          if (event is Map) {
            final type = event['type'];
            if (type == 'texture') {
              controller.add(ScanEventTexture(event['id'] as int));
            } else if (type == 'lifecycle') {
              final lEvent = event['event'];
              if (lEvent == 'started') controller.add(ScanEventLifecycle(LifecycleEvent.started));
              if (lEvent == 'scan-complete') controller.add(ScanEventLifecycle(LifecycleEvent.stopped));
              if (lEvent == 'camera-ready') controller.add(ScanEventLifecycle(LifecycleEvent.resumed));
              if (lEvent == 'camera-interrupted') controller.add(ScanEventLifecycle(LifecycleEvent.paused));
              if (lEvent == 'camera-unrecoverable') controller.add(ScanEventError(const CameraUnrecoverable()));
              if (lEvent == 'permission-revoked') controller.add(ScanEventError(const PermissionRevoked()));
            } else if (type == 'error') {
              final code = event['code'];
              final desc = event['description'] as String? ?? 'Unknown native error';
              
              if (code == 'permission-denied') {
                controller.add(ScanEventError(PermissionDenied(description: desc)));
              } else if (code == 'camera-unavailable') {
                controller.add(ScanEventError(CameraUnavailable(description: desc)));
              } else if (code == 'torch-unavailable') {
                controller.add(ScanEventError(TorchUnavailable(description: desc)));
              } else {
                // TODO: Map specific native error codes to typed errors when more are defined.
                // Using ConfigInvalid as a fallback for unclassified native errors.
                controller.add(ScanEventError(ConfigInvalid(description: desc)));
              }
            } else if (type == 'result') {
              _sessionTimer?.cancel();
              final rawString = event['rawString'] as String;
              final confidence = (event['confidence'] as num?)?.toDouble() ?? 1.0;
              final boundingRatio = (event['boundingRatio'] as num?)?.toDouble() ?? 0.0;
              final timestamp = DateTime.fromMillisecondsSinceEpoch(event['timestamp'] as int);
              
              final parseResult = PaymentParser.parseQr(rawString);
              if (parseResult.isError) {
                controller.add(ScanEventError(parseResult.error!));
                return;
              }
              
              final paymentData = parseResult.value!;
              var locationFix;
              if (_config != null && _config!.locationEnabled) {
                locationFix = await LocationState.getCurrentOrCached(_config!.locationCacheMaxAge);
              }

              final result = ScanResult(
                rawString: rawString,
                payment: paymentData,
                timestamp: timestamp,
                location: locationFix,
                confidence: confidence,
                schemeId: paymentData.schemeId,
              );
              
              controller.add(ScanEventResult(result, boundingRatio));
            } else if (type == 'releaseLocation') {
              LocationState.stopUpdates();
            } else if (type == 'torchState') {
              _torchStateController.add(event['state'] as bool);
            } else if (type == 'thermalState') {
              final state = event['state'] as String;
              _thermalStateController.add(state);
              if (state == 'serious') controller.add(ScanEventLifecycle(LifecycleEvent.paused));
              if (state == 'critical') {
                 controller.add(ScanEventLifecycle(LifecycleEvent.stopped));
                 stopScanning();
              }
            }
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        _sessionTimer?.cancel();
      },
    );

    // Single source of session timeout logic — fires if no successful decode within the window.
    _sessionTimer = Timer(_config?.scanSessionTimeout ?? const Duration(seconds: 60), () {
      controller.add(ScanEventError(const SessionTimeout()));
      stopScanning();
    });

    return controller.stream;
  }

  /// Stops the active scan session and pauses the camera stream.
  static Future<void> stopScanning() async {
    _sessionTimer?.cancel();
    await QrpaySdkPlatform.instance.stopScanning();
  }

  /// Enables or disables the device torch/flash.
  static Future<void> setTorch(bool on) async {
    await QrpaySdkPlatform.instance.setTorch(on);
  }

  /// Adjusts the camera zoom level.
  static Future<void> setZoom(double ratio) async {
    await QrpaySdkPlatform.instance.setZoom(ratio);
    _zoomLevelController.add(ratio);
  }
}
