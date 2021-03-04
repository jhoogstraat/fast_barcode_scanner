import 'package:flutter/foundation.dart';

import '../../fast_barcode_scanner_platform_interface.dart';

/// Describes a Barcode with type and value.
/// [Barcode] are equatable.
class Barcode {
  /// Creates a [Barcode] from a Flutter Message Protocol
  Barcode(List<dynamic> data)
      : this.type =
            BarcodeType.values.firstWhere((e) => describeEnum(e) == data[0]),
        this.value = data[1];

  /// The type if the Barcode.
  ///
  /// Can be one of [BarcodeType] in [String] form.
  final BarcodeType type;

  /// The actual value of the barcode.
  final String value;

  bool operator ==(o) => o is Barcode && o.type == type && o.value == value;
  int get hashCode => super.hashCode ^ type.hashCode ^ value.hashCode;
}
