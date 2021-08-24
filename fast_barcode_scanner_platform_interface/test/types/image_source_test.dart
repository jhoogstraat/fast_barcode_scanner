import 'dart:typed_data';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../resources/load_resources.dart';

void main() {
  test('Initializes data = null for picker', () {
    final source = ImageSource.picker();
    expect(source.data, isNull);
  });

  test('Initializes data correctly for binary', () {
    final binaryData = ByteData(10);
    final source = ImageSource.binary(binaryData, rotation: 10);
    expect(source.data, [binaryData.buffer.asUint8List(), 10]);
  });

  test('Initializes data = "path/to/test" for path', () {
    const path = "path/to/test";
    final source = ImageSource.path(path);
    expect(source.data, path);
  });

  test('Initializes data with jpg image', () async {
    final image = await loadBarcodeImage();
    final bytes = await image.toByteData();
    final source = ImageSource.binary(bytes!, rotation: 10);
    expect(source.data, [bytes.buffer.asUint8List(), 10]);
  });
}
