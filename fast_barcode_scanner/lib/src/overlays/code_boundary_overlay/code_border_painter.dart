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

  /// Custom [Paint] builder per barcode.
  final CodeBorderPaintBuilder? barcodePaintSelector;

  /// Optional [TextStyle] builder to draw the barcode value below its bounds.
  final TextStyle Function(Barcode)? barcodeValueStyle;

  /// Size of the native analysis frame used to scale coordinates.
  final Size imageSize;

  /// Detected barcodes to render.
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

    final offsets = sourcePoints
        .map(
          (point) => scaleCodeCornerPoint(
            cornerPoint: point,
            analysisImageSize: imageSize,
            widgetSize: size,
          ),
        )
        .toList(growable: false);

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    var minX = offsets.first.dx;
    var maxX = offsets.first.dx;
    var maxY = offsets.first.dy;

    for (var i = 1; i < offsets.length; i++) {
      final offset = offsets[i];
      minX = min(minX, offset.dx);
      maxX = max(maxX, offset.dx);
      maxY = max(maxY, offset.dy);
      path.lineTo(offset.dx, offset.dy);
    }
    path.close();

    final barcodePaint = barcodePaintSelector?.call(barcode) ?? _standardPaint;
    canvas.drawPath(path, barcodePaint);

    final styleBuilder = barcodeValueStyle;
    if (styleBuilder == null) return;

    final tp = TextPainter(
      text: TextSpan(text: barcode.value, style: styleBuilder(barcode)),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();

    final centerX = minX + ((maxX - minX) / 2.0);
    tp.paint(canvas, Offset(centerX - (tp.width / 2.0), maxY + 5.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final barcode in barcodes) {
      _paintBarcode(canvas, size, barcode);
    }
  }

  @override
  bool shouldRepaint(CodeBorderPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}
