import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:fast_barcode_scanner_platform_interface/src/method_channel_fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('$MethodChannelFastBarcodeScanner is the default implementation', () {
    expect(FastBarcodeScannerPlatform.instance,
        isA<MethodChannelFastBarcodeScanner>());
  });

  test('Cannot be implemented with `implements`', () {
    expect(() {
      FastBarcodeScannerPlatform.instance =
          ImplementsFastBarcodeScannerPlatform();
    }, throwsNoSuchMethodError);
  });

  test('Can be extended', () {
    FastBarcodeScannerPlatform.instance = ExtendsFastBarcodeScannerPlatform();
  });
}

class ImplementsFastBarcodeScannerPlatform
    implements FastBarcodeScannerPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExtendsFastBarcodeScannerPlatform extends FastBarcodeScannerPlatform {}
