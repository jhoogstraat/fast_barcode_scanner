import 'package:flutter/material.dart';

import '../../../fast_barcode_scanner.dart';

/// The MaterialFinderPainter draws a box around the [rectOfInterest] as well as
/// an optional "scan line" as a guide for the user to locate the desired code
/// to scan.
///
/// When including linear codes such as Code128, it is recommended to show the
/// scan line, especially on iOS where in certain cases these codes can only
/// be recognized when they are exactly in the middle of the screen. Without the
/// line to guide the user, they may find it difficult to get the scanner to
/// recognize these codes.
class MaterialFinderPainter extends CustomPainter {
  MaterialFinderPainter({
    required this.borderPaint,
    required this.backgroundColor,
    required this.rectOfInterest,
    this.inflate = 0.0,
    this.opacity = 1.0,
    this.showScanLine = false,
    this.sensingColor = Colors.white,
  });

  final double inflate;
  final double opacity;
  final bool showScanLine;
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

    if (showScanLine) {
      // draw scan line
      final scanLinePaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.square;
      final wideMiddle = cutOut.safeInnerRect;
      final centerLeft = wideMiddle.centerLeft;
      final centerRight = wideMiddle.centerRight;
      const borderAdjustment = 2.5;
      canvas.drawLine(
          Offset(centerLeft.dx + borderAdjustment, centerLeft.dy),
          Offset(centerRight.dx - borderAdjustment, centerRight.dy),
          scanLinePaint);
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
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.showScanLine != showScanLine;
  }
}
