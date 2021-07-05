import 'package:flutter/material.dart';

class MaterialBarcodeSensingPainter extends CustomPainter {
  MaterialBarcodeSensingPainter(
      {required this.aspectRatio,
      required this.inflate,
      required this.opacity});

  final double aspectRatio;
  final double inflate;
  final double opacity;

  final sensingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5; // strokeWidth is painted 50/50 outwards and inwards.

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOutWidth = screenRect.width - 45;
    final cutOutHeight = 1 / aspectRatio * cutOutWidth;
    final cutOut = RRect.fromRectXY(
        Rect.fromCenter(
            center: screenRect.center,
            width: cutOutWidth,
            height: cutOutHeight),
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
