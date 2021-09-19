import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Framerate should contain 4 options', () {
    const values = Framerate.values;
    expect(values.length, 4);
  });

  test("Framerate extension returns correct values", () {
    expect(Framerate.fps30.name, 'fps30');
    expect(Framerate.fps60.name, 'fps60');
    expect(Framerate.fps120.name, 'fps120');
    expect(Framerate.fps240.name, 'fps240');
  });
}
