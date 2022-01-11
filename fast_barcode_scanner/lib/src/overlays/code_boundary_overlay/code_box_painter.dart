import 'package:flutter/material.dart';

import '../../../fast_barcode_scanner.dart';

class BarcodePainter extends CustomPainter {
  final CodeBorderPaintBuilder? barcodePaintSelector;
  final CodeValueDisplayBuilder? textDecorator;

  BarcodePainter({
    required this.imageSize,
    required this.barcodes,
    this.barcodePaintSelector,
    this.textDecorator,
  });

  final Size imageSize;
  final List<Barcode> barcodes;

  final _standardPaint = Paint()
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
            .map((e) => _scalePoint(
                offset: Offset(e.x.toDouble(), e.y.toDouble()),
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
  bool shouldRepaint(BarcodePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}

/// We use BoxFit.cover to display our preview
///
/// Because of this, the source image is scaled to fill the longest edge of our widget
/// while the other portion of our image is clipped/cropped
///
/// In order to scale the points without distortion, we must obtain the scale factor
/// from the longest side of our box: either x or y (not both).
///
/// Using this single-dimension scale factor we can calculate how much of the image is cropped.
/// we then apply this adjustment on the cropped dimension
Offset _scalePoint({
  required Offset offset,
  required Size analysisImageSize,
  required Size widgetSize,
}) {
  // The analysis image is usually landscape regardless of the preview orientation
  final isAnalysisImageLandscape =
      analysisImageSize.width > analysisImageSize.height;
  final analysisHeight = isAnalysisImageLandscape
      ? analysisImageSize.width
      : analysisImageSize.height; // 640
  final analysisWidth = isAnalysisImageLandscape
      ? analysisImageSize.height
      : analysisImageSize.width; // 480

  // our widget may have any dimension for the preview. The preview image will be scaled towards the longest edge
  double scale = 1;
  double cropAdjustmentX = 0;
  double cropAdjustmentY = 0;
  if (widgetSize.width > widgetSize.height) {
    // the source image will be scaled to fit the width because it is the longest side
    // Y will need to be adjusted for the crop amount
    scale = widgetSize.width / analysisHeight;
    // essentially, we will scale the analysis image height at the same factor
    // as the width. The height of the analysis image will be larger than the
    // height of the widget. BoxFit.cover will cause the top and bottom of the
    // preview image to be cropped out equally (which is why we divide by 2)
    cropAdjustmentY = ((scale * analysisHeight) - widgetSize.height) / 2;
  } else {
    // the source image will be scaled to fit the height because it is the longest side
    // the X will need to be adjusted for the crop amount
    scale = widgetSize.height / analysisHeight;
    // find out how much horizontal adjustment is necessary to account for the cropping.
    cropAdjustmentX = ((scale * analysisWidth) - widgetSize.width) / 2;
  }
  return Offset((offset.dx.toDouble() * scale) - cropAdjustmentX,
      (offset.dy.toDouble() * scale) - cropAdjustmentY);
}
