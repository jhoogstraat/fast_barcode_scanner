import 'dart:async';

import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'detections_counter.dart';

/// This is outside of [ScannerScreen] to preserve [BarcodeCameraState] after hot reload.
/// Otherwise a new Key would be generated and thus a new [BarcodeCameraState].
final scanner = GlobalKey<BarcodeCameraState>();

final detectionsController = StreamController<Barcode>();
final Stream<Barcode> detectionsStream =
    detectionsController.stream.asBroadcastStream();

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
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
                scanner.currentState!.toggleTorch();
                _torchIconState.value = !_torchIconState.value;
              },
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (ctx) => ScannerScreen())),
            icon: Icon(Icons.navigate_next),
          )
        ],
      ),
      body: BarcodeCamera(
        key: scanner,
        types: [
          BarcodeType.ean8,
          BarcodeType.ean13,
          BarcodeType.code128,
          BarcodeType.qr
        ],
        resolution: Resolution.hd720,
        framerate: Framerate.fps30,
        mode: DetectionMode.pauseVideo,
        position: CameraPosition.front,
        onDetect: (barcode) => detectionsController.add(barcode),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // (key) => BeepPreviewOverlay(key: key),
            MaterialPreviewOverlay(animateDetection: false),
            BlurPreviewOverlay(),
            Positioned(
              bottom: 50,
              child: Column(
                children: [
                  ElevatedButton(
                    child: Text("Resume"),
                    onPressed: () => scanner.currentState!.resumeDetector(),
                  ),
                  SizedBox(height: 20),
                  DetectionsCounter()
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
