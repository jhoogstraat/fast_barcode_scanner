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
  final analysis =
      (isWidgetPortrait == (analysisImageSize.width > analysisImageSize.height))
          ? analysisImageSize.flipped
          : analysisImageSize;

  final scale = max(
    widgetSize.width / analysis.width,
    widgetSize.height / analysis.height,
  );
  final cropX = (analysis.width * scale - widgetSize.width) / 2.0;
  final cropY = (analysis.height * scale - widgetSize.height) / 2.0;

  return Offset(cornerPoint.dx * scale - cropX, cornerPoint.dy * scale - cropY);
}
