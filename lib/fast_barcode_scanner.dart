import 'dart:async';

import 'package:flutter/foundation.dart';

import 'messages/barcode.dart';
import 'messages/barcode_type.dart';
import 'messages/preview_configuration.dart';
import 'platform_interface/fast_barcode_scanner_platform_interface.dart';

class FastBarcodeScanner {
  static FastBarcodeScannerPlatform get _platformInstance =>
      FastBarcodeScannerPlatform.instance;

  static final _detectionStreamController = StreamController<Barcode>();
  static final detections =
      _detectionStreamController.stream.asBroadcastStream();

  static Future<PreviewConfiguration> start(
      {@required List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode}) async {
    assert(types.length > 0);

    _platformInstance.setOnReadHandler((arguments) {
      if (_detectionStreamController.hasListener)
        _detectionStreamController.add(Barcode(arguments));
    });

    return _platformInstance.init(
        types.map((e) => describeEnum(e)).toList(growable: false),
        describeEnum(resolution ?? Resolution.hd720),
        describeEnum(framerate ?? Framerate.fps60),
        describeEnum(detectionMode ?? DetectionMode.continuous));
  }

  static Future<void> stop() {
    print("calling dispose");
    return _platformInstance.dispose();
  }

  static Future<void> pause() {
    return _platformInstance.pause();
  }

  static Future<void> resume() {
    return _platformInstance.resume();
  }

  static Future<void> toggleFlash() {
    return _platformInstance.toggleFlash();
  }
}
