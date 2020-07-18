import 'package:flutter/material.dart';

class MaterialBarcodeFramePainter extends CustomPainter {
  final borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5 // strokeWidth is painted 50/50 outwards and inwards.
    ..color = Colors.black.withAlpha(160);
  final backgroundPaint = Paint()..color = Colors.black38;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOut = RRect.fromRectXY(
        Rect.fromCenter(
            center: rect.center, width: rect.width - 45, height: 165),
        12,
        12);

    final cutOutPath = Path.combine(PathOperation.difference,
        Path()..addRect(rect), Path()..addRRect(cutOut));

    canvas
      ..drawPath(cutOutPath, backgroundPaint)
      ..drawRRect(cutOut.deflate(borderPaint.strokeWidth / 2), borderPaint);
  }

  @override
  bool shouldRepaint(MaterialBarcodeFramePainter oldDelegate) => false;
}
