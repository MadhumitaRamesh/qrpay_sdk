import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_sdk/src/config/overlay_style.dart';
import 'package:qrpay_sdk/src/overlay/positioning_overlay_painter.dart';

/// A widget that renders [PositioningOverlayPainter] at a fixed size for
/// golden comparison. Using a [ColoredBox] background makes the transparent
/// cutout clearly visible against a known background colour.
Widget _buildOverlayWidget({
  required OverlayStyle style,
  required Color background,
  double width = 400,
  double height = 800,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // Fixed background so the cutout transparency is visible in the golden.
            Positioned.fill(child: ColoredBox(color: background)),
            Positioned.fill(
              child: CustomPaint(
                painter: PositioningOverlayPainter(style: style),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('PositioningOverlayPainter goldens', () {
    testWidgets('dark preset — 400×800', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildOverlayWidget(
          style: OverlayStyle.dark(),
          background: const Color(0xFF1A1A2E), // dark navy: makes white border pop
        ),
      );

      await expectLater(
        find.byType(CustomPaint),
        matchesGoldenFile('goldens/overlay_dark_400x800.png'),
      );
    });

    testWidgets('light preset — 400×800', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildOverlayWidget(
          style: OverlayStyle.light(),
          background: const Color(0xFFF5F5F5), // light grey: makes black border pop
        ),
      );

      await expectLater(
        find.byType(CustomPaint),
        matchesGoldenFile('goldens/overlay_light_400x800.png'),
      );
    });

    testWidgets('dark preset — 360×780 (compact phone)', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildOverlayWidget(
          style: OverlayStyle.dark(),
          background: const Color(0xFF1A1A2E),
          width: 360,
          height: 780,
        ),
      );

      await expectLater(
        find.byType(CustomPaint),
        matchesGoldenFile('goldens/overlay_dark_360x780.png'),
      );
    });
  });
}
