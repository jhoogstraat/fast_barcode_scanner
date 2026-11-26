import 'dart:ui';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';

import '../corner_point_utils.dart';

typedef CodeFilter = bool Function(Barcode code);

/// Describes a centered region of interest (ROI) within the camera preview.
abstract class RectOfInterest {
  const RectOfInterest();

  /// A wide 16:9 finder box centered in the preview.
  static RectOfInterest wide({double horizontalPadding = 45}) =>
      WideRectOfInterest(horizontalPadding: horizontalPadding);

  /// A square finder box centered in the preview.
  static RectOfInterest square({required double size}) =>
      SquareRectOfInterest(size: size);

  /// Computes the ROI rectangle inside [previewWidgetRect].
  Rect rect(Rect previewWidgetRect);

  /// Builds a predicate returning `true` when [code] falls completely inside
  /// this region of interest.
  CodeFilter buildCodeFilter({
    required Size analysisSize,
    required Size previewSize,
  }) {
    final roi = rect(previewSize.toRect());
    return (code) {
      final List<Offset> points;
      if (code.cornerPoints != null && code.cornerPoints!.isNotEmpty) {
        points = code.cornerPoints!;
      } else if (code.boundingBox != null) {
        points = [code.boundingBox!.topLeft, code.boundingBox!.bottomRight];
      } else {
        return false;
      }

      for (final point in points) {
        final scaled = scaleCodeCornerPoint(
          cornerPoint: point,
          analysisImageSize: analysisSize,
          widgetSize: previewSize,
        );
        if (!roi.contains(scaled)) {
          return false;
        }
      }
      return true;
    };
  }

  /// Returns only the [codes] contained inside this region of interest.
  List<Barcode> filterCodes({
    required List<Barcode> codes,
    required Size analysisSize,
    required Size previewSize,
  }) {
    return codes
        .where(
          buildCodeFilter(
            analysisSize: analysisSize,
            previewSize: previewSize,
          ),
        )
        .toList(growable: false);
  }
}

/// A 16:9 wide [RectOfInterest] centered in the preview.
class WideRectOfInterest extends RectOfInterest {
  const WideRectOfInterest({this.horizontalPadding = 45});

  final double horizontalPadding;

  @override
  Rect rect(Rect previewWidgetRect) {
    final width = (previewWidgetRect.width - horizontalPadding)
        .clamp(0.0, double.infinity);
    final height = (9.0 / 16.0) * width;
    return Rect.fromCenter(
      center: previewWidgetRect.center,
      width: width,
      height: height,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WideRectOfInterest &&
          runtimeType == other.runtimeType &&
          horizontalPadding == other.horizontalPadding;

  @override
  int get hashCode => horizontalPadding.hashCode;
}

/// A square [RectOfInterest] centered in the preview.
class SquareRectOfInterest extends RectOfInterest {
  const SquareRectOfInterest({required this.size});

  final double size;

  @override
  Rect rect(Rect previewWidgetRect) {
    return Rect.fromCenter(
      center: previewWidgetRect.center,
      width: size,
      height: size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SquareRectOfInterest &&
          runtimeType == other.runtimeType &&
          size == other.size;

  @override
  int get hashCode => size.hashCode;
}
