import 'dart:ui';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';

import '../../corner_point_utils.dart';

typedef CodeFilter = bool Function(Barcode code);

/// A simple description of a rect of interest. The Rect will be located in the
/// center of the screen and will fill the width minus horizontal padding.
abstract class RectOfInterest {
  const RectOfInterest();

  static RectOfInterest wide({double horizontalPadding = 45}) =>
      WideRectOfInterest(horizontalPadding: horizontalPadding);

  static RectOfInterest square({required double size}) =>
      SquareRectOfInterest(size: size);

  Rect rect(Rect previewWidgetRect);

  /// A curried function which is used for filtering scanned codes based on the
  /// bounds of the [RectOfInterest].
  CodeFilter buildCodeFilter({
    required Size analysisSize,
    required Size previewSize,
  }) {
    return (code) {
      final cornerPoints = code.cornerPoints;
      if (cornerPoints != null) {
        for (final cornerPoint in cornerPoints) {
          final scaledCornerOffset = scaleCodeCornerPoint(
            cornerPoint: cornerPoint.toOffset(),
            analysisImageSize: analysisSize,
            widgetSize: previewSize,
          );
          if (!rect(previewSize.toRect()).contains(scaledCornerOffset)) {
            // this code is not completely contained in the rect of interest
            return false;
          }
        }
        return true;
      } else {
        return false;
      }
    };
  }

  List<Barcode> filterCodes({
    required List<Barcode> codes,
    required Size analysisSize,
    required Size previewSize,
  }) {
    return codes.where((code) {
      final cornerPoints = code.cornerPoints;
      if (cornerPoints != null) {
        for (final cornerPoint in cornerPoints) {
          final scaledCornerOffset = scaleCodeCornerPoint(
            cornerPoint: cornerPoint.toOffset(),
            analysisImageSize: analysisSize,
            widgetSize: previewSize,
          );
          if (!rect(previewSize.toRect()).contains(scaledCornerOffset)) {
            // this code is not completely contained in the rect of interest
            return false;
          }
        }
        return true;
      } else {
        return false;
      }
    }).toList();
  }
}

class WideRectOfInterest extends RectOfInterest {
  final double horizontalPadding;

  const WideRectOfInterest({this.horizontalPadding = 45});

  /// The rect of interest should be in the center of the screen
  ///
  /// on iOS AVFoundation will only recognize linear codes like Code128 when
  /// they are exactly in the exact center of the image when it is configured
  /// to recognize both linear and 2D barcodes. When you only want linear codes
  /// then this doesn't apply while using modern hardware.
  @override
  Rect rect(Rect previewWidgetSize) {
    final width = previewWidgetSize.width - horizontalPadding;
    final height = 1 / (16 / 9) * width;
    return Rect.fromCenter(
      center: previewWidgetSize.center,
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

  @override
  String toString() {
    return 'RectOfInterestDimensions{horizontalPadding: $horizontalPadding}';
  }
}

class SquareRectOfInterest extends RectOfInterest {
  final double size;

  const SquareRectOfInterest({required this.size});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SquareRectOfInterest &&
          runtimeType == other.runtimeType &&
          size == other.size;

  @override
  int get hashCode => size.hashCode;

  @override
  Rect rect(Rect previewWidgetRect) {
    return Rect.fromCenter(
      center: previewWidgetRect.center,
      width: size,
      height: size,
    );
  }
}
