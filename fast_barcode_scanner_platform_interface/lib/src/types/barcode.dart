import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../fast_barcode_scanner_platform_interface.dart';

/// Describes a Barcode with type and value.
/// [Barcode] is value-equatable.
class Barcode {
  /// Creates a [Barcode] from a Flutter Message Protocol
  Barcode(List<dynamic> data)
      : type = BarcodeType.values.firstWhere((e) => describeEnum(e) == data[0]),
        value = data[1],
        valueType = data.length > 2
            ? data[2] != null
                ? BarcodeValueType.values[data[2]]
                : null
            : null,
        cornerPoints = data.length > 3 ? parsePointList(data[3]) : null;

  /// The type of the barcode.
  ///
  ///
  final BarcodeType type;

  /// The actual value of the barcode.
  ///
  ///
  final String value;

  /// The type of content of the barcode.
  ///
  /// On available on Android.
  /// Returns [null] on iOS.
  final BarcodeValueType? valueType;

  final List<Point>? cornerPoints;

  static List<Point<int>>? parsePointList(List<dynamic>? pointList) {
    return pointList?.map((e) => Point<int>(e[0], e[1])).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.type == type &&
      other.value == value &&
      other.valueType == valueType &&
      other.cornerPoints == cornerPoints;

  @override
  int get hashCode =>
      super.hashCode ^
      type.hashCode ^
      value.hashCode ^
      valueType.hashCode & cornerPoints.hashCode;

  @override
  String toString() {
    return '''
    Barcode {
      type: $type,
      value: $value,
      valueType: $valueType,
      rect: $cornerPoints
    }
    ''';
  }
}
