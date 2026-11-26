import 'dart:math';
import 'dart:ui';

/// Maps a point from the camera's analysis image coordinate space into the
/// Flutter preview widget's coordinate space assuming `BoxFit.cover`.
Offset scaleCodeCornerPoint({
  required Offset cornerPoint,
  required Size analysisImageSize,
  required Size widgetSize,
}) {
  if (analysisImageSize.isEmpty || widgetSize.isEmpty) {
    return Offset.zero;
  }

  final isWidgetPortrait = widgetSize.height >= widgetSize.width;
  final isAnalysisLandscape =
      analysisImageSize.width > analysisImageSize.height;

  final double analysisWidth;
  final double analysisHeight;
  if (isWidgetPortrait && isAnalysisLandscape) {
    analysisWidth = analysisImageSize.height;
    analysisHeight = analysisImageSize.width;
  } else if (!isWidgetPortrait && !isAnalysisLandscape) {
    analysisWidth = analysisImageSize.height;
    analysisHeight = analysisImageSize.width;
  } else {
    analysisWidth = analysisImageSize.width;
    analysisHeight = analysisImageSize.height;
  }

  final scaleX = widgetSize.width / analysisWidth;
  final scaleY = widgetSize.height / analysisHeight;
  final scale = max(scaleX, scaleY);

  final scaledWidth = analysisWidth * scale;
  final scaledHeight = analysisHeight * scale;
  final cropAdjustmentX = (scaledWidth - widgetSize.width) / 2.0;
  final cropAdjustmentY = (scaledHeight - widgetSize.height) / 2.0;

  return Offset(
    (cornerPoint.dx * scale) - cropAdjustmentX,
    (cornerPoint.dy * scale) - cropAdjustmentY,
  );
}

extension PointExtension on Point {
  Offset toOffset() => Offset(x.toDouble(), y.toDouble());
}

extension SizeExtensions on Size {
  Rect toRect() => Rect.fromLTWH(0, 0, width, height);
}
