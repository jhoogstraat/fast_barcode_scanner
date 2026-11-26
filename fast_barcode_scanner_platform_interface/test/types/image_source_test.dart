import 'dart:typed_data';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImageSource.binary creates BinaryImageSource', () {
    final bytes = Uint8List.fromList([10, 20, 30]);
    final source =
        ImageSource.binary(ByteData.sublistView(bytes), rotation: 180);

    expect(source, isA<BinaryImageSource>());
    expect(source.data, [bytes, 180]);
  });

  test('ImageSource.picker creates PickerImageSource', () {
    const source = ImageSource.picker();
    expect(source, isA<PickerImageSource>());
    expect(source.data, isNull);
  });
}
