import 'package:fast_barcode_scanner/barcode_camera.dart';
import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/messages/barcode_type.dart';
import 'package:fast_barcode_scanner/messages/preview_configuration.dart';
import 'package:fast_barcode_scanner/overlays/beep_overlay.dart';
import 'package:fast_barcode_scanner/overlays/blur_overlay.dart';
import 'package:flutter/material.dart';

import 'detections_counter.dart';

/// This is outside of [DetectorScreen] to preserve [BarcodeCameraState] after hot reload.
/// Otherwise a new Key would be generated and thus a new [BarcodeCameraState].
final detector = GlobalKey<BarcodeCameraState>();

class DetectorScreen extends StatelessWidget {
  final _flashIconState = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Fast Barcode Scanner',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _flashIconState,
            builder: (context, state, _) => IconButton(
              icon: state
                  ? const Icon(Icons.flash_on)
                  : const Icon(Icons.flash_off),
              onPressed: () {
                FastBarcodeScanner.toggleFlash();
                _flashIconState.value = !_flashIconState.value;
              },
            ),
          )
        ],
      ),
      body: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
        BarcodeCamera(
          key: detector,
          types: [BarcodeType.ean8, BarcodeType.ean13, BarcodeType.code128],
          resolution: Resolution.hd720,
          framerate: Framerate.fps60,
          detectionMode: DetectionMode.pauseVideo,
          fadeInOnReady: true,
          overlays: [
            (key) => BeepPreviewOverlay(key: key),
            (key) => BlurPreviewOverlay(key: key)
          ],
        ),
        Positioned(bottom: 50, child: DetectionsCounter()),
        Positioned(
          bottom: 150,
          child: RaisedButton(
            child: Text("Resume"),
            onPressed: () => detector.currentState.resumeDetector(),
          ),
        )
      ]),
    );
  }
}
