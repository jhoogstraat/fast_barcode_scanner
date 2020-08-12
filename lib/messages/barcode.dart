/// Describes a Barcode with type and value.
/// [Barcode] are equatable.
class Barcode {
  /// Creates a [Barcode] from a Flutter Message Protocol
  Barcode(List<dynamic> data)
      : assert(data[0] is String),
        assert(data[1] is String),
        this.type = data[0],
        this.value = data[1];

  /// The type if the Barcode.
  ///
  /// Can be one of [BarcodeType] in [String] form.
  final String type;

  /// The actual value of the barcode.
  final String value;

  bool operator ==(o) => o is Barcode && o.type == type && o.value == value;
  int get hashCode => super.hashCode ^ type.hashCode ^ value.hashCode;
}
