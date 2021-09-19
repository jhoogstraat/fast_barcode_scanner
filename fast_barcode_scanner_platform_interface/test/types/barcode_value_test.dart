import 'package:fast_barcode_scanner_platform_interface/src/types/barcode_value_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BarcodeType should contain 13 options', () {
    const values = BarcodeValueType.values;
    expect(values.length, 13);
  });

  test("BarcodeValueType extension returns correct values", () {
    expect(BarcodeValueType.unknown.name, 'unknown');
    expect(BarcodeValueType.contactInfo.name, 'contactInfo');
    expect(BarcodeValueType.email.name, 'email');
    expect(BarcodeValueType.isbn.name, 'isbn');
    expect(BarcodeValueType.phone.name, 'phone');
    expect(BarcodeValueType.product.name, 'product');
    expect(BarcodeValueType.sms.name, 'sms');
    expect(BarcodeValueType.text.name, 'text');
    expect(BarcodeValueType.url.name, 'url');
    expect(BarcodeValueType.wifi.name, 'wifi');
    expect(BarcodeValueType.geo.name, 'geo');
    expect(BarcodeValueType.calender.name, 'calender');
    expect(BarcodeValueType.license.name, 'license');
  });
}
