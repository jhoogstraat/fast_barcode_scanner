import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/src/types/image_source.dart';
import 'package:flutter/services.dart';

import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';
import 'fast_barcode_scanner_platform_interface.dart';

class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  void Function(Barcode)? _onDetectHandler;

  @override
  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position) async {
    final response = await _channel.invokeMethod('init', {
      'types': types.map((e) => e.name).toList(growable: false),
      'mode': detectionMode.name,
      'res': resolution.name,
      'fps': framerate.name,
      'pos': position.name
    });

    _channel.setMethodCallHandler(handlePlatformMethodCall);

    return PreviewConfiguration(response);
  }

  @override
  Future<void> start() => _channel.invokeMethod('start');

  @override
  Future<void> stop() => _channel.invokeMethod('stop');

  @override
  Future<void> startDetector() => _channel.invokeMethod('startDetector');

  @override
  Future<void> stopDetector() => _channel.invokeMethod('stopDetector');

  // @override
  // Future<void> dispose() {
  //   _channel.setMethodCallHandler(null);
  //   _onDetectHandler = null;
  //   return _channel.invokeMethod('stop');
  // }

  @override
  Future<bool> toggleTorch() =>
      _channel.invokeMethod('torch').then<bool>((isOn) => isOn);

  @override
  Future<PreviewConfiguration> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) async {
    final response = await _channel.invokeMethod('config', {
      if (types != null) 'types': types.map((e) => e.name).toList(),
      if (detectionMode != null) 'mode': detectionMode.name,
      if (resolution != null) 'res': resolution.name,
      if (framerate != null) 'fps': framerate.name,
      if (position != null) 'pos': position.name,
    });
    return PreviewConfiguration(response);
  }

  @override
  void setOnDetectHandler(void Function(Barcode) handler) =>
      _onDetectHandler = handler;

  @override
  Future<List<Barcode>> scanImage(ImageSource source) async {
    final List<Object?>? response = await _channel.invokeMethod(
      'scan',
      source.data,
    );

    return response?.map((e) => Barcode(e as List<dynamic>)).toList() ??
        const [];
  }

  Future<void> handlePlatformMethodCall(MethodCall call) async {
    switch (call.method) {
      case 's':
        // This might fail if the code type is not present in the list of available code types.
        // Barcode init will throw in this case. Ignore this cases and continue as if nothing happened.
        try {
          final barcode = Barcode(call.arguments);
          _onDetectHandler?.call(barcode);
          // ignore: empty_catches
        } catch (e) {}

        break;
      default:
        assert(true,
            "FastBarcodeScanner: Unknown method call received: ${call.method}");
    }
  }
}
