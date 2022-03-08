import 'package:flutter/material.dart';

import '../../../fast_barcode_scanner.dart';
import '../../corner_point_utils.dart';

class CodeBorderPainter extends CustomPainter {
  final CodeBorderPaintBuilder? barcodePaintSelector;
  final CodeValueDisplayBuilder? textDecorator;

  CodeBorderPainter({
    required this.imageSize,
    required this.barcodes,
    this.barcodePaintSelector,
    this.textDecorator,
  });

  final Size imageSize;
  final List<Barcode> barcodes;

  static final _standardPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.red;

  Paint _getBarcodePaint(Barcode barcode) {
    if (barcodePaintSelector != null) {
      return barcodePaintSelector!(barcode);
    }
    return _standardPaint;
  }

  CodeValueDisplay? _getTextDecoration(Barcode barcode) {
    if (textDecorator != null) {
      return textDecorator!(barcode);
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (Barcode barcode in barcodes) {
      final Path path = Path();
      final corners = barcode.cornerPoints;
      if (corners != null) {
        final offsets = corners
            .map((e) => scaleCodeCornerPoint(
                cornerPoint: Offset(e.x.toDouble(), e.y.toDouble()),
                analysisImageSize: imageSize,
                widgetSize: size))
            .toList();
        path.moveTo(offsets[0].dx, offsets[0].dy);
        double minX = -1, maxX = -1, minY = -1, maxY = -1;
        for (var offset in offsets) {
          if (minX == -1 || offset.dx < minX) {
            minX = offset.dx;
          }
          if (maxX == -1 || offset.dx > maxX) {
            maxX = offset.dx;
          }
          if (minY == -1 || offset.dy < minY) {
            minY = offset.dy;
          }
          if (maxY == -1 || offset.dy > maxY) {
            maxY = offset.dy;
          }
          path.lineTo(offset.dx, offset.dy);
        }
        // print("minX: $minX, maxX: $maxX, minY: $minY, maxY: $maxY");
        path.close();
        final barcodePaint = _getBarcodePaint(barcode);
        canvas.drawPath(path, barcodePaint);

        final textDecoration = _getTextDecoration(barcode);
        if (textDecoration != null) {
          final TextPainter tp = TextPainter(
              text: textDecoration.textSpan,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr);
          tp.layout();

          final pointsSortedByX = List.from(offsets);
          pointsSortedByX.sort((a, b) => (b.dx - a.dx).toInt());
          final pointsSortedByY = List.from(offsets);
          pointsSortedByY.sort((a, b) => (b.dy - a.dy).toInt());

          final centerX = minX + ((maxX - minX) / 2);
          final textPositionX = centerX - (tp.width / 2);

          const textPadding = 5;
          double textPositionY;
          if (textDecoration.location == CodeValueDisplayLocation.centerTop) {
            textPositionY = minY - (tp.height + textPadding);
          } else {
            textPositionY = maxY + textPadding;
          }
          tp.paint(canvas, Offset(textPositionX, textPositionY));
        }
      }
    }
  }

  @override
  bool shouldRepaint(CodeBorderPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}
