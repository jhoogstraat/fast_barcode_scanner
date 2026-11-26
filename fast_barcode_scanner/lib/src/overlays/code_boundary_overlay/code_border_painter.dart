import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../fast_barcode_scanner.dart';

/// Paints bounding boxes or 4-corner polygons and optional value labels for
/// detected [Barcode]s.
class CodeBorderPainter extends CustomPainter {
  /// Creates a [CodeBorderPainter].
  CodeBorderPainter({
    required this.imageSize,
    required this.barcodes,
    this.barcodePaintSelector,
    this.barcodeValueStyle,
  });

  final CodeBorderPaintBuilder? barcodePaintSelector;
  final TextStyle Function(Barcode)? barcodeValueStyle;
  final Size imageSize;
  final List<Barcode> barcodes;

  static final Paint _standardPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = const Color(0xFFF44336);

  void _paintBarcode(Canvas canvas, Size size, Barcode barcode) {
    final List<Offset> sourcePoints;
    if (barcode.cornerPoints != null && barcode.cornerPoints!.length >= 3) {
      sourcePoints = barcode.cornerPoints!;
    } else if (barcode.boundingBox != null) {
      final box = barcode.boundingBox!;
      sourcePoints = [
        box.topLeft,
        box.topRight,
        box.bottomRight,
        box.bottomLeft,
      ];
    } else {
      return;
    }

    final first = scaleCodeCornerPoint(
      cornerPoint: sourcePoints.first,
      analysisImageSize: imageSize,
      widgetSize: size,
    );
    final path = Path()..moveTo(first.dx, first.dy);
    var minX = first.dx;
    var maxX = first.dx;
    var maxY = first.dy;

    for (var i = 1; i < sourcePoints.length; i++) {
      final offset = scaleCodeCornerPoint(
        cornerPoint: sourcePoints[i],
        analysisImageSize: imageSize,
        widgetSize: size,
      );
      minX = min(minX, offset.dx);
      maxX = max(maxX, offset.dx);
      maxY = max(maxY, offset.dy);
      path.lineTo(offset.dx, offset.dy);
    }
    path.close();

    canvas.drawPath(
        path, barcodePaintSelector?.call(barcode) ?? _standardPaint);

    final styleBuilder = barcodeValueStyle;
    if (styleBuilder == null) return;

    final tp = TextPainter(
      text: TextSpan(text: barcode.value, style: styleBuilder(barcode)),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();

    final centerX = minX + ((maxX - minX) / 2.0);
    tp.paint(canvas, Offset(centerX - (tp.width / 2.0), maxY + 5.0));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final barcode in barcodes) {
      _paintBarcode(canvas, size, barcode);
    }
  }

  @override
  bool shouldRepaint(CodeBorderPainter oldDelegate) =>
      oldDelegate.imageSize != imageSize ||
      oldDelegate.barcodes != barcodes ||
      oldDelegate.barcodePaintSelector != barcodePaintSelector ||
      oldDelegate.barcodeValueStyle != barcodeValueStyle;
}
