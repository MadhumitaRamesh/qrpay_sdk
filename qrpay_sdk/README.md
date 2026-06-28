# QRPay SDK

QRPay SDK is a robust, cross-platform Flutter federated plugin designed for high-performance scanning and parsing of payment QR codes (EMVCo and UPI). It features a native CameraX / AVFoundation pipeline with built-in auto-zoom algorithms, thermal state monitoring, adaptive framerates, and location tagging, offering a seamless and drop-in `ScannerView` widget for Flutter applications.

## Federated Architecture

The plugin is built using a federated architecture to ensure clean separation of concerns:

- `qrpay_sdk`: The app-facing package containing the public Dart API, `ScannerView` widget, configuration, and QR parsing logic.
- `qrpay_sdk_platform_interface`: The abstract interface package defining the contract that platform implementations must fulfill.
- `qrpay_sdk_android`: The Android platform implementation using CameraX, ML Kit Barcode Scanning, and Kotlin Coroutines.
- `qrpay_sdk_ios`: The iOS platform implementation using AVFoundation, Vision framework, and Swift.

## Installation

Add `qrpay_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  qrpay_sdk:
    path: ./path/to/qrpay_sdk
```

> **Note for iOS**: You MUST add the following keys to your host application's `ios/Runner/Info.plist`:
> ```xml
> <key>NSCameraUsageDescription</key>
> <string>Camera access is required to scan payment QR codes.</string>
> <key>NSLocationWhenInUseUsageDescription</key>
> <string>Location access is required to securely tag scans.</string>
> ```

## Quick Start

Initialize the SDK and use the `ScannerView` widget in your app:

```dart
import 'package:qrpay_sdk/qrpay_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize the SDK configuration
  await QRPay.initialize(QRPayConfig(
    autoZoomEnabled: true,
    locationEnabled: true,
    overlayStyle: OverlayStyle.dark(),
  ));

  runApp(const MyApp());
}

// 2. Use ScannerView in your Widget tree
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScannerView(
        onScan: (ScanResult result) {
          print('Scanned: \${result.payment.merchantName}');
          print('Amount: \${result.payment.amount} \${result.payment.currency}');
        },
        onError: (QRPayError error) {
          print('Error: \${error.description}');
        },
      ),
    );
  }
}
```

## Supported Payment Fields

The SDK automatically extracts the following standardized fields from EMVCo and UPI QR codes:

| Field | EMVCo Tag / UPI Param | Description |
|---|---|---|
| `schemeId` | - | Identifies the parsed scheme (e.g. `emvco`, `upi`) |
| `merchantAccountInfo` | 02-51 | Map of merchant specific IDs |
| `merchantCategoryCode`| 52 | MCC standard code |
| `currency` | 53 | ISO 4217 numeric currency code |
| `amount` | 54 / `am` | Transaction amount (if specified) |
| `countryCode` | 58 | ISO 3166-1 alpha-2 country code |
| `merchantName` | 59 / `pn` | Name of the merchant/payee |
| `merchantCity` | 60 | City of the merchant |
| `merchantId` | / `pa` | Primary merchant identifier / VPA |

## Current Status

**Completed & Verified (Phases 1-5):**
- ✅ Android CameraX native implementation (fully verified via emulator build).
- ✅ iOS AVFoundation native implementation (structurally complete, syntactically verified).
- ✅ Dart `ScannerView` UI, positioning overlay, and AutoZoom math algorithms.
- ✅ Robustness features: Thermal monitoring, adaptive FPS, session timeouts, auto-recovery.
- ✅ Parsers: EMVCo (with full CRC-16/CCITT-FALSE validation) and UPI URI parsing.
- ✅ 100% unit test coverage for config validation, zoom math, scheme parsing, and registry fallbacks.

**Pending/Unverified:**
- ⚠️ The iOS AVFoundation code has been written and compiles syntactically but has not been run or tested on a physical iOS device/Xcode due to current environment limitations.
- ⚠️ The Android ML Kit barcode detection has only been verified up to the emulator build stage; live physical-device camera scanning testing is pending.
- ⚠️ A broader integration test suite mapping the native-to-Dart boundary is deferred.
