import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';

class ScannedBarcodes {
  final List<Barcode> barcodes;
  final DateTime scannedAt;

  ScannedBarcodes(this.barcodes) : scannedAt = DateTime.now();

  ScannedBarcodes.none() : this([]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedBarcodes &&
          runtimeType == other.runtimeType &&
          barcodes == other.barcodes &&
          scannedAt == other.scannedAt;

  @override
  int get hashCode => barcodes.hashCode ^ scannedAt.hashCode;
}
