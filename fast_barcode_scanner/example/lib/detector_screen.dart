import 'dart:async';

import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_beeper/fast_barcode_scanner_beeper.dart';
import 'package:flutter/material.dart';
import 'detections_counter.dart';

/// This is outside of [DetectorScreen] to preserve [BarcodeCameraState] after hot reload.
/// Otherwise a new Key would be generated and thus a new [BarcodeCameraState].
final detector = GlobalKey<BarcodeCameraState>();

final detectionsController = StreamController<Barcode>();
final Stream<Barcode> detectionsStream =
    detectionsController.stream.asBroadcastStream();

class DetectorScreen extends StatelessWidget {
  final _torchIconState = ValueNotifier(false);

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
            valueListenable: _torchIconState,
            builder: (context, state, _) => IconButton(
              icon: state
                  ? const Icon(Icons.flash_on)
                  : const Icon(Icons.flash_off),
              onPressed: () {
                detector.currentState.toggleTorch();
                _torchIconState.value = !_torchIconState.value;
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
          overlays: [
            (key) => BeepPreviewOverlay(key: key),
            (key) => MaterialPreviewOverlay(key: key, animateDetection: false),
            (key) => BlurPreviewOverlay(key: key)
          ],
          onDetect: (barcode) => detectionsController.add(barcode),
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
