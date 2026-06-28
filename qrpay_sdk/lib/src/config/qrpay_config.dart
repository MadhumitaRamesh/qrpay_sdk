import 'overlay_style.dart';

/// Configuration options for the QRPay SDK.
///
/// Use this to customize the scanning behavior, UI overlay, and performance limits.
class QRPayConfig {
  final List<String> supportedSchemes;
  final bool autoZoomEnabled;
  final double autoZoomThreshold;
  final double maxDigitalZoom;
  final Duration autoZoomTimeout;
  final Duration scanSessionTimeout;
  final bool torchDefaultOn;
  final OverlayStyle overlayStyle;
  final bool locationEnabled;
  final Duration locationCacheMaxAge;

  const QRPayConfig({
    this.supportedSchemes = const ['emvco', 'upi'],
    this.autoZoomEnabled = true,
    this.autoZoomThreshold = 0.20,
    this.maxDigitalZoom = 10.0,
    this.autoZoomTimeout = const Duration(seconds: 3),
    this.scanSessionTimeout = const Duration(seconds: 60),
    this.torchDefaultOn = false,
    required this.overlayStyle,
    this.locationEnabled = true,
    this.locationCacheMaxAge = const Duration(seconds: 30),
  });
}
