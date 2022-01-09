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
    this.cutOutWidth,
    this.cutOutHeight,
    this.cutOutCenter,
  });

  final double inflate;
  final double opacity;
  final Color sensingColor;
  final bool drawBackground;
  final Paint borderPaint;
  final Color backgroundColor;
  final CutOutShape cutOutShape;
  final double? cutOutWidth;
  final double? cutOutHeight;
  final Offset? cutOutCenter;

  @override
  void paint(Canvas canvas, Size size) {
    if (cutOutCenter != null) {
      assert(cutOutCenter != const Offset(0.0, 0.0),
          "CutOutCenter can't be at the origin");
          assert(cutOutCenter != Offset(size.width, 0.0),
          "CutOutCenter can't be at TopRight");
          assert(cutOutCenter != Offset(size.width, size.height),
          "CutOutCenter can't be at BottomRight");
          assert(cutOutCenter != Offset(0.0, size.height),
          "CutOutCenter can't be at the BottomLeft");
    }
    if (cutOutWidth != null) {
      assert(cutOutWidth! <= size.width,
          "CutOutWidth $cutOutWidth can't be greater than Screen Width ${size.width}");
      if (cutOutCenter != null) {
        assert(cutOutCenter!.dx - (cutOutWidth! / 2) >= 0.0,
            "CutOut is overflowing towards left by ${(cutOutCenter!.dx - (cutOutWidth! / 2)).abs()} by pixels, adjust CutOutWidth");
        assert(cutOutCenter!.dx + (cutOutWidth! / 2) <= size.width,
            "CutOut is overflowing towards right by ${(cutOutCenter!.dx - (cutOutWidth! / 2)).abs()} pixels, adjust it's CutOutWidth");
      }
    }
    if (cutOutHeight != null && cutOutShape == CutOutShape.wide) {
      assert(cutOutHeight! <= size.height,
          "CutOutHeigth $cutOutHeight can't be greater than Screen Height ${size.height}");
      if (cutOutCenter != null) {
        assert(cutOutCenter!.dy - (cutOutHeight! / 2) >= 0.0,
            "CutOut is overflowing towards top by ${(cutOutCenter!.dy - (cutOutHeight! / 2)).abs()} pixels, adjust it's CutOutHeight");
        assert(cutOutCenter!.dy + (cutOutHeight! / 2) <= size.height,
            "CutOut is overflowing towards bottom by ${(cutOutCenter!.dy - (cutOutHeight! / 2)).abs()} pixels, adjust it's CutOutHeight");
      }
    }

    final backgroundPaint = Paint()..color = backgroundColor;

    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final width = cutOutWidth ?? screenRect.width * 0.5;

    final center = cutOutCenter ?? screenRect.center;

    double height;
    if (cutOutShape == CutOutShape.square) {
      height = width;
    } else {
      height = cutOutHeight ?? 1 / (16 / 9) * width;
    }

    final cutOut = RRect.fromRectXY(
      Rect.fromCenter(
        center: center,
        width: width,
        height: height,
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
        oldDelegate.sensingColor != sensingColor ||
        oldDelegate.borderPaint != borderPaint ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.cutOutShape != cutOutShape;
  }
}
