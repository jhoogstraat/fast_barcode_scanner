import 'package:flutter/material.dart';

class MaterialBarcodeSensingPainter extends CustomPainter {
  MaterialBarcodeSensingPainter({required this.inflate, required this.opacity});

  final double inflate;
  final double opacity;

  final sensingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5; // strokeWidth is painted 50/50 outwards and inwards.

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOut = RRect.fromRectXY(
        Rect.fromCenter(
            center: rect.center, width: rect.width - 45, height: 165),
        12,
        12);

    sensingPaint.color = Colors.white.withAlpha((255 * opacity).toInt());
    sensingPaint.strokeWidth = 5 - 4 * inflate;

    canvas.drawRRect(
        _inflate(cutOut.deflate(sensingPaint.strokeWidth / 2)), sensingPaint);
  }

  /// Inflates a rect, but keeps the border radius.
  RRect _inflate(RRect rect) {
    return RRect.fromRectAndRadius(
        rect.outerRect.inflate(inflate * 20), rect.blRadius);
  }

  @override
  bool shouldRepaint(MaterialBarcodeSensingPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.inflate != inflate;
  }
}
