# QRPay SDK

A Flutter federated plugin for scanning and parsing payment QR codes. It provides a camera-based scanning pipeline with built-in support for EMVCo and UPI QR standards, an auto-zoom algorithm, a positioning overlay, and location tagging — packaged as a clean federated plugin that can be extended with custom payment schemes.

## Packages

| Package | Description |
|---|---|
| `qrpay_sdk` | App-facing Dart package. Exposes the public API and `ScannerView` widget. |
| `qrpay_sdk_platform_interface` | Abstract platform interface using `PlatformInterface`. |
| `qrpay_sdk_android` | Android implementation using CameraX and ML Kit barcode scanning. |
| `qrpay_sdk_ios` | iOS stub — method channel interface matching Android, ready for AVFoundation implementation. |

## Features

- CameraX-powered barcode scanning with ML Kit, bound to a plugin-owned `LifecycleOwner` so camera state survives host widget rebuilds.
- Pre-warming: camera is configured on `initialize()` and ready to stream on `startScanning()`, targeting first frame under 300ms.
- EMVCo TLV parsing with CRC-16/CCITT-FALSE validation.
- UPI URI parsing.
- Open registry for adding custom scheme parsers.
- Auto-zoom: adjusts zoom based on barcode bounding box size using a square-root ratio algorithm, eased over 300ms, with confidence-based scaling and timeout reset.
- Pinch-to-zoom gesture handling that temporarily overrides auto-zoom.
- Positioning overlay with configurable mask color, border, and corner bracket indicators.
- Location tagging on scan results using `geolocator`, with caching and graceful permission handling.
- Torch control with flash availability detection, surfaced as a broadcast stream.
- Adaptive FPS: 30fps when a QR candidate is active, 10fps when idle.
- Thermal monitoring with automatic scan pause on serious/critical device thermal state.
- Camera interruption recovery with up to 3 auto-retry attempts before emitting `camera-unrecoverable`.
- Session timeout: auto-stops scanning if no QR is decoded within a configurable window.
- Fully typed error hierarchy: `MalformedQr`, `ChecksumFailed`, `UnsupportedScheme`, `CameraUnrecoverable`, `PermissionRevoked`, `SessionTimeout`, and more.

## Getting Started

Add the app-facing package to your `pubspec.yaml`:

```yaml
dependencies:
  qrpay_sdk:
    path: ./qrpay_sdk
```

### Basic Usage

```dart
import 'package:qrpay_sdk/qrpay_sdk.dart';

ScannerView(
  config: QRPayConfig(
    overlayStyle: OverlayStyle.dark(),
  ),
  onScan: (ScanResult result) {
    print(result.payment.merchantName);
    print(result.payment.amount);
  },
  onError: (QRPayError error) {
    print(error.description);
  },
)
```

### Custom Scheme Parser

```dart
CustomSchemeRegistry.instance.register(MyCustomParser());
```

Implement `SchemeParser`:

```dart
class MyCustomParser implements SchemeParser {
  @override
  String get schemeId => 'my-scheme';

  @override
  bool matches(String rawString) => rawString.startsWith('myapp://');

  @override
  Result<PaymentData, QRPayError> parse(String rawString) {
    // parse and return
  }
}
```

## Configuration

```dart
QRPayConfig(
  overlayStyle: OverlayStyle.dark(),       // or OverlayStyle.light() or custom
  autoZoomEnabled: true,
  autoZoomThreshold: 0.20,                 // bounding box ratio below which zoom kicks in
  maxDigitalZoom: 10.0,
  autoZoomTimeout: Duration(seconds: 3),   // reset zoom if stuck at max
  scanSessionTimeout: Duration(seconds: 60),
  torchDefaultOn: false,
  locationEnabled: true,
  locationCacheMaxAge: Duration(seconds: 30),
)
```

## Streams

```dart
QRPay.torchState      // Stream<bool>    — current torch state after every toggle
QRPay.zoomLevel       // Stream<double>  — current zoom level
QRPay.thermalState    // Stream<String>  — 'normal' | 'fair' | 'serious' | 'critical'
LocationState.permanentlyDeniedStream  // Stream<void> — prompt user to open settings
```

## Requirements

- Flutter 3.35.1+
- Dart 3.0+
- Android: minSdk 24, compileSdk 34
- iOS: 17.0+ (stub only; AVFoundation implementation is Phase 5)

## Android Permissions

Add to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

For orientation change handling without triggering camera interruption recovery, add to your activity:

```xml
android:configChanges="orientation|screenSize|screenLayout"
```

## Project Status

Android implementation is complete. iOS method channel signatures are fully stubbed and ready for AVFoundation/Vision implementation. All Dart parsing, overlay, auto-zoom, and state management logic is platform-independent and fully tested.

## Running Tests

```bash
cd qrpay_sdk
flutter test
```

## License

MIT
