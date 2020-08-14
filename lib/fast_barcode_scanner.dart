export 'package:fast_barcode_scanner/src/barcode_camera.dart';
export 'package:fast_barcode_scanner/src/preview_overlay.dart';
export 'package:fast_barcode_scanner/src/overlays/beep_overlay.dart';
export 'package:fast_barcode_scanner/src/overlays/blur_overlay.dart';
export 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart'
    show
        Barcode,
        BarcodeType,
        Framerate,
        Resolution,
        DetectionMode,
        PreviewConfiguration;

// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';

// class FastBarcodeScanner {
//   static FastBarcodeScannerPlatform get _platformInstance =>
//       FastBarcodeScannerPlatform.instance;

//   static final _detectionStreamController = StreamController<Barcode>();
//   static final detections =
//       _detectionStreamController.stream.asBroadcastStream();

//   static Future<PreviewConfiguration> init(
//       {@required List<BarcodeType> types,
//       Resolution resolution = Resolution.hd720,
//       Framerate framerate = Framerate.fps60,
//       DetectionMode detectionMode = DetectionMode.pauseVideo}) async {
//     assert(types.length > 0);

//     _platformInstance.setOnDetectHandler((barcode) {
//       if (_detectionStreamController.hasListener)
//         _detectionStreamController.add(barcode);
//     });

//     return _platformInstance.init(types, resolution, framerate, detectionMode);
//   }

//   static Future<void> stop() {
//     return _platformInstance.dispose();
//   }

//   static Future<void> pause() {
//     return _platformInstance.pause();
//   }

//   static Future<void> resume() {
//     return _platformInstance.resume();
//   }

//   static Future<void> toggleFlash() {
//     return _platformInstance.toggleFlash();
//   }
// }
