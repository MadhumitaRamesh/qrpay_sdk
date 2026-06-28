# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-28

### Added
- Federated plugin structure with 4 sub-packages (`qrpay_sdk`, `qrpay_sdk_platform_interface`, `qrpay_sdk_android`, `qrpay_sdk_ios`).
- Full Android CameraX + ML Kit scanning pipeline (`qrpay_sdk_android`) bound to an independent plugin lifecycle.
- Full iOS AVFoundation + Vision scanning pipeline (`qrpay_sdk_ios`) matching Android behavior.
- Dart `ScannerView` widget providing a robust, drop-in camera preview UI.
- Background pre-warming of camera pipelines to achieve sub-300ms time-to-first-frame.
- EMVCo QR TLV parser with full CRC-16/CCITT-FALSE validation.
- UPI URI parsing.
- Pluggable `CustomSchemeRegistry` for adding proprietary QR formats.
- Advanced `AutoZoomController` algorithm adjusting zoom proportionally to QR bounding box sizes.
- Custom `PositioningOverlayPainter` with light/dark presets.
- `geolocator` integration for optionally tagging scans with the current location.
- Native thermal state monitoring automatically throttling analysis and pausing zoom under thermal strain.
- Adaptive FPS processing (30fps active vs 10fps idle) in native layers.
- Camera interruption and recovery mechanisms with auto-retries.
- Scan session timeouts configured via pure Dart timers.
- Comprehensive `QRPayError` hierarchy (`MalformedQr`, `CameraUnrecoverable`, `PermissionRevoked`, etc.).
- Unit test coverage for configuration validation, auto-zoom math, and all scheme parsers.
