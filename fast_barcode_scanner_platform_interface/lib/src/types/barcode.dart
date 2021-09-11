import 'package:fast_barcode_scanner_platform_interface/src/types/barcode_value_type.dart';
import 'package:flutter/foundation.dart';

import '../../fast_barcode_scanner_platform_interface.dart';

/// Describes a Barcode with type and value.
/// [Barcode] is value-equatable.
class Barcode {
  /// Creates a [Barcode] from a Flutter Message Protocol
  Barcode(List<dynamic> data)
      : type = BarcodeType.values.firstWhere((e) => describeEnum(e) == data[0]),
        value = data[1],
        valueType = data.length > 2 ? BarcodeValueType.values[data[2]] : null;

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

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.type == type &&
      other.value == value &&
      other.valueType == valueType;

  @override
  int get hashCode =>
      super.hashCode ^ type.hashCode ^ value.hashCode ^ valueType.hashCode;

  @override
  String toString() {
    return '''
    Barcode {
      type: $type,
      value: $value,
      valueType: $valueType
    }
    ''';
  }
}
