import 'package:flutter/material.dart';

class OverlayStyle {
  final Color maskColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerLength;
  final double cornerStrokeWidth;

  const OverlayStyle({
    required this.maskColor,
    required this.borderColor,
    this.borderWidth = 2.0,
    this.cornerLength = 30.0,
    this.cornerStrokeWidth = 4.0,
  });

  factory OverlayStyle.light() {
    return const OverlayStyle(
      maskColor: Color(0x66FFFFFF),
      borderColor: Colors.black,
    );
  }

  factory OverlayStyle.dark() {
    return const OverlayStyle(
      maskColor: Color(0x99000000),
      borderColor: Colors.white,
    );
  }
}
