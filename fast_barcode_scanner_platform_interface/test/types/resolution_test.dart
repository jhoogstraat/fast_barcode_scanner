import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Resolution should contain 4 options', () {
    const values = Resolution.values;
    expect(values.length, 4);
  });

  test("Resolution extension returns correct values", () {
    expect(Resolution.sd480.name, 'sd480');
    expect(Resolution.hd720.name, 'hd720');
    expect(Resolution.hd1080.name, 'hd1080');
    expect(Resolution.hd4k.name, 'hd4k');
  });
}
