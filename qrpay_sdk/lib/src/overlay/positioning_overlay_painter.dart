import 'package:flutter/material.dart';
import '../config/overlay_style.dart';

class PositioningOverlayPainter extends CustomPainter {
  final OverlayStyle style;

  PositioningOverlayPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()..color = style.maskColor;
    
    final shortEdge = size.width < size.height ? size.width : size.height;
    final cutoutSize = shortEdge * 0.7;
    
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutoutSize,
      height: cutoutSize,
    );

    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(maskPath, maskPaint);

    if (style.borderWidth > 0) {
      final borderPaint = Paint()
        ..color = style.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth;
      canvas.drawRect(cutoutRect, borderPaint);
    }

    if (style.cornerStrokeWidth > 0 && style.cornerLength > 0) {
      final cornerPaint = Paint()
        ..color = style.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.cornerStrokeWidth
        ..strokeCap = StrokeCap.square;

      final length = style.cornerLength;
      
      canvas.drawLine(cutoutRect.topLeft, cutoutRect.topLeft + Offset(length, 0), cornerPaint);
      canvas.drawLine(cutoutRect.topLeft, cutoutRect.topLeft + Offset(0, length), cornerPaint);
      
      canvas.drawLine(cutoutRect.topRight, cutoutRect.topRight + Offset(-length, 0), cornerPaint);
      canvas.drawLine(cutoutRect.topRight, cutoutRect.topRight + Offset(0, length), cornerPaint);

      canvas.drawLine(cutoutRect.bottomLeft, cutoutRect.bottomLeft + Offset(length, 0), cornerPaint);
      canvas.drawLine(cutoutRect.bottomLeft, cutoutRect.bottomLeft + Offset(0, -length), cornerPaint);

      canvas.drawLine(cutoutRect.bottomRight, cutoutRect.bottomRight + Offset(-length, 0), cornerPaint);
      canvas.drawLine(cutoutRect.bottomRight, cutoutRect.bottomRight + Offset(0, -length), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PositioningOverlayPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}
