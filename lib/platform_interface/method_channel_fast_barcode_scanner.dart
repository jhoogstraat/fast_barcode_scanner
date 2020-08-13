import 'dart:async';

import 'package:flutter/services.dart';

import '../messages/preview_configuration.dart';
import 'fast_barcode_scanner_platform_interface.dart';

class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  static const MethodChannel _channel =
      const MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  void Function(dynamic) _onReadHandler;

  Future<PreviewConfiguration> init(List<String> types, String resolution,
      String framerate, String detectionMode) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'read':
          _onReadHandler?.call(call.arguments);
          break;
        default:
          assert(true,
              "FastBarcodeScanner: unknown method call received: ${call.method}");
      }
    });

    final response = await _channel.invokeMethod('start', {
      'types': types,
      'detectionMode': detectionMode,
      'res': resolution,
      'fps': framerate
    });

    return PreviewConfiguration(response);
  }

  Future<void> dispose() {
    _channel.setMethodCallHandler(null);
    _onReadHandler = null;
    return _channel.invokeMethod('stop');
  }

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> resume() => _channel.invokeMethod('resume');

  Future<void> toggleFlash() => _channel.invokeMethod('toggleTorch');

  @override
  void setOnReadHandler(void Function(dynamic) handler) =>
      _onReadHandler = handler;
}
