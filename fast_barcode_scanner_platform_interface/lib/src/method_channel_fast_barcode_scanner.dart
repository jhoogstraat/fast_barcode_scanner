import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';
import 'fast_barcode_scanner_platform_interface.dart';

class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  static const MethodChannel _channel =
      const MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  void Function(Barcode)? _onDetectHandler;

  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'read':
          // This might fail if the code type is not present in the list of available code types.
          // Barcode init will throw in this case.
          final barcode = Barcode(call.arguments);
          this._onDetectHandler?.call(barcode);
          break;
        default:
          assert(true,
              "FastBarcodeScanner: Unknown method call received: ${call.method}");
      }
    });

    final response = await _channel.invokeMethod('start', {
      'types': types.map((e) => describeEnum(e)).toList(growable: false),
      'mode': describeEnum(detectionMode),
      'res': describeEnum(resolution),
      'fps': describeEnum(framerate),
      'pos': describeEnum(position)
    });

    return PreviewConfiguration(response);
  }

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> resume() => _channel.invokeMethod('resume');

  Future<void> dispose() {
    _channel.setMethodCallHandler(null);
    _onDetectHandler = null;
    return _channel.invokeMethod('stop');
  }

  Future<bool> toggleTorch() =>
      _channel.invokeMethod('toggleTorch').then<bool>((isOn) => isOn);

  Future<bool> changeCamera(CameraPosition position) => _channel
      .invokeMethod('changeCamera', describeEnum(position))
      .then<bool>((success) => success);

  void setOnDetectHandler(void Function(Barcode) handler) =>
      _onDetectHandler = handler;
}
