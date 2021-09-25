import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';

class MaterialFinderPainter extends CustomPainter {
  MaterialFinderPainter({
    this.inflate = 0.0,
    this.opacity = 1.0,
    this.sensingColor = Colors.white,
    this.drawBackground = true,
    required this.borderPaint,
    required this.backgroundColor,
    required this.cutOutShape,
  });

  final double inflate;
  final double opacity;
  final Color sensingColor;
  final bool drawBackground;
  final Paint borderPaint;
  final Color backgroundColor;
  final CutOutShape cutOutShape;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = backgroundColor;

    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOutWidth = screenRect.width - 45;

    double cutOutHeight;
    if (cutOutShape == CutOutShape.square) {
      cutOutHeight = cutOutWidth;
    } else {
      cutOutHeight = 1 / (16 / 9) * cutOutWidth;
    }

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
      borderPaint.color = sensingColor.withAlpha((255 * opacity).toInt());
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
        oldDelegate.borderPaint != borderPaint ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.cutOutShape != cutOutShape;
  }
}
