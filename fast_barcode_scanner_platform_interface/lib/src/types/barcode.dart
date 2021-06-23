import 'package:flutter/foundation.dart';

import '../../fast_barcode_scanner_platform_interface.dart';

/// Describes a Barcode with type and value.
/// [Barcode] are equatable.
class Barcode {
  /// Creates a [Barcode] from a Flutter Message Protocol
  Barcode(List<dynamic> data)
      : type = BarcodeType.values.firstWhere((e) => describeEnum(e) == data[0]),
        value = data[1];

  /// The type of the barcode.
  final BarcodeType type;

  /// The actual value of the barcode.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is Barcode && other.type == type && other.value == value;
  @override
  int get hashCode => super.hashCode ^ type.hashCode ^ value.hashCode;
}
