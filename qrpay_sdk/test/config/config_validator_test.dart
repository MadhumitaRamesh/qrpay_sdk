import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_sdk/qrpay_sdk.dart';

void main() {
  group('ConfigValidator', () {
    test('passes valid config', () {
      final config = QRPayConfig(overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isSuccess, true);
      expect(result.error, isNull);
    });

    test('fails when autoZoomThreshold is <= 0', () {
      final config = QRPayConfig(autoZoomThreshold: 0.0, overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isError, true);
      expect(result.error?.field, 'autoZoomThreshold');
    });

    test('fails when autoZoomThreshold is > 0.5', () {
      final config = QRPayConfig(autoZoomThreshold: 0.6, overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isError, true);
      expect(result.error?.field, 'autoZoomThreshold');
    });

    test('fails when maxDigitalZoom is < 1.0', () {
      final config = QRPayConfig(maxDigitalZoom: 0.9, overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isError, true);
      expect(result.error?.field, 'maxDigitalZoom');
    });

    test('fails when maxDigitalZoom is > 10.0', () {
      final config = QRPayConfig(maxDigitalZoom: 11.0, overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isError, true);
      expect(result.error?.field, 'maxDigitalZoom');
    });

    test('fails when autoZoomTimeout is negative', () {
      final config = QRPayConfig(autoZoomTimeout: const Duration(seconds: -1), overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isError, true);
      expect(result.error?.field, 'autoZoomTimeout');
    });
    
    test('fails when scanSessionTimeout is negative', () {
      final config = QRPayConfig(scanSessionTimeout: const Duration(seconds: -1), overlayStyle: OverlayStyle.dark());
      final result = ConfigValidator.validate(config);
      expect(result.isError, true);
      expect(result.error?.field, 'scanSessionTimeout');
    });
  });
}
