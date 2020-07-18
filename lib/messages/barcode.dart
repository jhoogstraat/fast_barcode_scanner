class Barcode {
  Barcode(List<dynamic> data)
      : assert(data[0] is String),
        assert(data[1] is String),
        this.type = data[0],
        this.value = data[1];

  final String type;
  final String value;

  bool operator ==(o) => o is Barcode && o.type == type && o.value == value;
  int get hashCode => super.hashCode ^ type.hashCode ^ value.hashCode;
}
