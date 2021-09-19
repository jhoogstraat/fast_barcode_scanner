import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BarcodeType should contain 15 options', () {
    const values = BarcodeType.values;
    expect(values.length, 15);
  });

  test("BarcodeType extension returns correct values", () {
    expect(BarcodeType.aztec.name, 'aztec');
    expect(BarcodeType.codabar.name, 'codabar');
    expect(BarcodeType.code128.name, 'code128');
    expect(BarcodeType.code39.name, 'code39');
    expect(BarcodeType.code39mod43.name, 'code39mod43');
    expect(BarcodeType.code93.name, 'code93');
    expect(BarcodeType.dataMatrix.name, 'dataMatrix');
    expect(BarcodeType.ean13.name, 'ean13');
    expect(BarcodeType.ean8.name, 'ean8');
    expect(BarcodeType.interleaved.name, 'interleaved');
    expect(BarcodeType.itf.name, 'itf');
    expect(BarcodeType.pdf417.name, 'pdf417');
    expect(BarcodeType.qr.name, 'qr');
    expect(BarcodeType.upcA.name, 'upcA');
    expect(BarcodeType.upcE.name, 'upcE');
  });
}
