import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BarcodeType contains all 15 supported symbologies', () {
    expect(BarcodeType.values, hasLength(15));
    expect(
      BarcodeType.values.map((e) => e.name),
      containsAll([
        'aztec',
        'codabar',
        'code128',
        'code39',
        'code93',
        'dataMatrix',
        'ean13',
        'ean8',
        'gs1DataBar',
        'itf',
        'msi',
        'pdf417',
        'qr',
        'upcA',
        'upcE',
      ]),
    );
  });
}
