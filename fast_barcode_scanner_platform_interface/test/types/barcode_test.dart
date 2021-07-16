import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:fast_barcode_scanner_platform_interface/src/types/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Should initialize type and value with list', () {
    final barcodeEan13 = Barcode(["ean13", "1234"]);
    final barcodeQR = Barcode(["qr", "This is a QR Code"]);

    expect(barcodeEan13.type, BarcodeType.ean13);
    expect(barcodeEan13.value, "1234");

    expect(barcodeQR.type, BarcodeType.qr);
    expect(barcodeQR.value, "This is a QR Code");
  });

  test("Should throw A StateError if invalid type is provided", () {
    expect(() => Barcode(["invalid_type", "1234"]), throwsStateError);
    expect(() => Barcode([1234, "1234"]), throwsStateError);
    expect(() => Barcode([1234, 1234]), throwsStateError);
  });

  test("Should throw a TypeError if value is not of type String", () {
    expect(() => Barcode(["ean13", 1234]), throwsA(isA<TypeError>()));
    expect(() => Barcode(["ean13", 12.34]), throwsA(isA<TypeError>()));
  });

  test('Should be value-equatable', () {
    final barcode1 = Barcode(["ean13", "1234"]);
    final barcode1Copy = Barcode(["ean13", "1234"]);

    final barcode2 = Barcode(["qr", "4321"]);
    final barcode2Copy = Barcode(["qr", "4321"]);

    expect(barcode1 == barcode1, true);
    expect(barcode2 == barcode2, true);
    expect(barcode1 == barcode2, false);
    expect(barcode1 == barcode1Copy, true);
    expect(barcode2 == barcode2Copy, true);
  });
}
