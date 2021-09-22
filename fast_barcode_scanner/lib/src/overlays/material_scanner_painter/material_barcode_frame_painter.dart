import 'package:flutter/material.dart';

class MaterialBarcodeFramePainter extends CustomPainter {
  const MaterialBarcodeFramePainter(this.aspectRatio, this.backgroundColor,
      this.scanViewBorderColor, this.squareScanView);

  final double aspectRatio;
  final Color backgroundColor;
  final Color scanViewBorderColor;
  final bool squareScanView;

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
    if (squareScanView == false) {
      cutOutHeight = 1 / aspectRatio * cutOutWidth;
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
