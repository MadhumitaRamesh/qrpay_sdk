import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_sdk/qrpay_sdk.dart';
import 'package:qrpay_sdk/src/state/auto_zoom_controller.dart';

void main() {
  group('AutoZoomController Math', () {
    testWidgets('computes zoom correctly with high confidence', (WidgetTester tester) async {
      final config = QRPayConfig(autoZoomThreshold: 0.25, maxDigitalZoom: 5.0, overlayStyle: OverlayStyle.dark());
      double currentZoom = 1.0;
      final controller = AutoZoomController(
        vsync: tester,
        threshold: config.autoZoomThreshold,
        maxDigitalZoom: config.maxDigitalZoom,
        timeout: config.autoZoomTimeout,
        onZoomChanged: (z) { currentZoom = z; },
      );

      // ratio = 0.01 -> sqrt = 0.1 -> 0.5 / 0.1 = 5.0, clamped to 3.0 internally
      controller.processDetection(0.01, 0.9);
      await tester.pumpAndSettle();
      expect(currentZoom, 3.0);

      controller.resetZoom();
      currentZoom = 1.0;

      // ratio = 0.0625 -> sqrt = 0.25 -> 0.5 / 0.25 = 2.0
      controller.processDetection(0.0625, 0.9);
      await tester.pumpAndSettle();
      expect(currentZoom, 2.0);
    });

    testWidgets('halves delta with low confidence', (WidgetTester tester) async {
      final config = QRPayConfig(autoZoomThreshold: 0.25, maxDigitalZoom: 5.0, overlayStyle: OverlayStyle.dark());
      double currentZoom = 1.0;
      final controller = AutoZoomController(
        vsync: tester,
        threshold: config.autoZoomThreshold,
        maxDigitalZoom: config.maxDigitalZoom,
        timeout: config.autoZoomTimeout,
        onZoomChanged: (z) { currentZoom = z; },
      );

      // target is 2.0 (for ratio 0.0625). Confidence < 0.5, so delta is halved to 1.5.
      controller.processDetection(0.0625, 0.4);
      await tester.pumpAndSettle();
      expect(currentZoom, 1.5);
    });

    testWidgets('clamps to maxDigitalZoom', (WidgetTester tester) async {
      final config = QRPayConfig(autoZoomThreshold: 0.25, maxDigitalZoom: 2.0, overlayStyle: OverlayStyle.dark());
      double currentZoom = 1.0;
      final controller = AutoZoomController(
        vsync: tester,
        threshold: config.autoZoomThreshold,
        maxDigitalZoom: config.maxDigitalZoom,
        timeout: config.autoZoomTimeout,
        onZoomChanged: (z) { currentZoom = z; },
      );

      // target = 5.0 -> internally clamped to 3.0 -> then maxDigitalZoom clamps to 2.0
      controller.processDetection(0.01, 0.9);
      await tester.pumpAndSettle();
      expect(currentZoom, 2.0);
    });

    testWidgets('ignores ratio above threshold', (WidgetTester tester) async {
      final config = QRPayConfig(autoZoomThreshold: 0.25, maxDigitalZoom: 5.0, overlayStyle: OverlayStyle.dark());
      double currentZoom = 1.0;
      final controller = AutoZoomController(
        vsync: tester,
        threshold: config.autoZoomThreshold,
        maxDigitalZoom: config.maxDigitalZoom,
        timeout: config.autoZoomTimeout,
        onZoomChanged: (z) { currentZoom = z; },
      );

      controller.processDetection(0.36, 0.9);
      await tester.pumpAndSettle();
      expect(currentZoom, 1.0);
    });
  });
}
