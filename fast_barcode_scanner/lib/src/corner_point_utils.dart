import 'dart:math';
import 'dart:ui';

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
Offset scaleCodeCornerPoint({
  required Offset cornerPoint,
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
  return Offset((cornerPoint.dx.toDouble() * scale) - cropAdjustmentX,
      (cornerPoint.dy.toDouble() * scale) - cropAdjustmentY);
}

extension PointExtension on Point {
  Offset toOffset() {
    return Offset(x.toDouble(), y.toDouble());
  }
}

extension SizeExtensions on Size {
  Rect toRect() {
    return Rect.fromLTWH(0, 0, width, height);
  }
}
