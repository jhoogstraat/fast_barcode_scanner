import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'messages/barcode.dart';
import 'messages/barcode_format.dart';
import 'messages/preview_details.dart';

class FastBarcodeScanner {
  static const MethodChannel _channel =
      const MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  static final _codeStreamController = StreamController<Barcode>();

  static final Stream<Barcode> codeStream =
      _codeStreamController.stream.asBroadcastStream();

  static Future<PreviewDetails> start(
      {@required List<BarcodeFormat> formats,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode}) async {
    assert(formats.length > 0);

    var response = await _channel.invokeMethod('start', {
      'formats': formats.map((e) => describeEnum(e)).toList(),
      'detectionMode': describeEnum(detectionMode ?? DetectionMode.continuous),
      'res': describeEnum(resolution ?? Resolution.hd720),
      'fps': describeEnum(framerate ?? Framerate.fps60)
    });

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'read':
          if (_codeStreamController.hasListener) {
            final barcode = Barcode(call.arguments);
            _codeStreamController.add(barcode);
          }
          break;
        default:
          print("FastBarcodeReader: unknown method call received: "
              "${call.method}");
      }
    });

    return PreviewDetails(response);
  }

  static Future stop() {
    _channel.setMethodCallHandler(null);
    return _channel.invokeMethod('stop').catchError(print);
  }

  static Future pause() {
    return _channel.invokeMethod('pause');
  }

  static Future resume() {
    return _channel.invokeMethod('resume');
  }

  static Future toggleFlash() {
    return _channel.invokeMethod('toggleTorch');
  }
}
