import 'package:flutter/material.dart';

class MaterialBarcodeFramePainter extends CustomPainter {
  const MaterialBarcodeFramePainter(
      this.scanViewAspectRatio, this.backgroundColor, this.scanViewBorderColor);

  final double scanViewAspectRatio;
  final Color backgroundColor;
  final Color scanViewBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 // strokeWidth is painted 50/50 outwards and inwards.
      ..color = scanViewBorderColor;

    final backgroundPaint = Paint()..color = backgroundColor;

    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOutWidth = screenRect.width - 45;

    double cutOutHeight = cutOutWidth;
    if (scanViewAspectRatio != 1) {
      cutOutHeight = 1 / scanViewAspectRatio * cutOutWidth;
    }

    final cutOut = RRect.fromRectXY(
        Rect.fromCenter(
            center: screenRect.center,
            width: cutOutWidth,
            height: cutOutHeight),
        12,
        12);

    final cutOutPath = Path.combine(PathOperation.difference,
        Path()..addRect(screenRect), Path()..addRRect(cutOut));

    canvas
      ..drawPath(cutOutPath, backgroundPaint)
      ..drawRRect(cutOut.deflate(borderPaint.strokeWidth / 2), borderPaint);
  }

  @override
  bool shouldRepaint(MaterialBarcodeFramePainter oldDelegate) => false;
}
