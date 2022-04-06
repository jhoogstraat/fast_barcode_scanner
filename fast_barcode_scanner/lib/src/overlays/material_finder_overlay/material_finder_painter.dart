import 'package:fast_barcode_scanner/src/overlays/rect_of_interest/rect_of_interest.dart';
import 'package:flutter/material.dart';

import '../../../fast_barcode_scanner.dart';

/// The MaterialFinderPainter draws a box around the [rectOfInterest] as well as
/// an optional "scan line" as a guide for the user to locate the desired code
/// to scan.
class MaterialFinderPainter extends CustomPainter {
  MaterialFinderPainter({
    required this.borderPaint,
    required this.backgroundColor,
    required this.rectOfInterest,
    this.inflate = 0.0,
    this.opacity = 1.0,
    this.sensingColor = Colors.white,
  });

  final double inflate;
  final double opacity;
  final Color sensingColor;
  final Paint borderPaint;
  final Color? backgroundColor;
  final RectOfInterest rectOfInterest;

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOut = RRect.fromRectXY(
      rectOfInterest.rect(screenRect),
      12,
      12,
    );

    if (opacity != 1 || inflate != 0) {
      borderPaint.color = sensingColor.withAlpha((255 * opacity).toInt());
      borderPaint.strokeWidth = 5 - 4 * inflate;
    }

    if (backgroundColor != null) {
      final backgroundPaint = Paint()..color = backgroundColor!;
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
        oldDelegate.sensingColor != sensingColor ||
        oldDelegate.borderPaint != borderPaint ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
