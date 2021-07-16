import 'package:flutter/material.dart';

class MaterialFinderPainter extends CustomPainter {
  MaterialFinderPainter({
    required this.aspectRatio,
    this.inflate = 0.0,
    this.opacity = 1.0,
    this.drawBackground = true,
    required this.borderPaint,
  });

  final double aspectRatio;
  final double inflate;
  final double opacity;
  final bool drawBackground;
  final Paint borderPaint;

  static final defaultBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5 // strokeWidth is painted 50/50 outwards and inwards.
    ..color = Colors.black.withAlpha(160);

  static final sensingBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5; // strokeWidth is painted 50/50 outwards and inwards.

  static final backgroundPaint = Paint()..color = Colors.black45;

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOutWidth = screenRect.width - 45;
    final cutOutHeight = 1 / aspectRatio * cutOutWidth;
    final cutOut = RRect.fromRectXY(
      Rect.fromCenter(
        center: screenRect.center,
        width: cutOutWidth,
        height: cutOutHeight,
      ),
      12,
      12,
    );

    if (opacity != 1 || inflate != 0) {
      borderPaint.color = Colors.white.withAlpha((255 * opacity).toInt());
      borderPaint.strokeWidth = 5 - 4 * inflate;
    }

    if (drawBackground) {
      final cutOutPath = Path.combine(
        PathOperation.difference,
        Path()..addRect(screenRect),
        Path()..addRRect(cutOut),
      );

      canvas.drawPath(cutOutPath, backgroundPaint);
    }

    canvas.drawRRect(
      _inflate(cutOut.deflate(borderPaint.strokeWidth / 2)),
      borderPaint,
    );
  }

  /// Inflates a rect, but keeps the border radius.
  RRect _inflate(RRect rect) {
    return RRect.fromRectAndRadius(
        rect.outerRect.inflate(inflate * 20), rect.blRadius);
  }

  @override
  bool shouldRepaint(MaterialFinderPainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
        oldDelegate.inflate != inflate ||
        oldDelegate.aspectRatio != aspectRatio ||
        oldDelegate.borderPaint != borderPaint;
  }
}
