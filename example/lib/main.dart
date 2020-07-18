import 'dart:async';
import 'dart:ui';

import 'package:fast_barcode_scanner/barcode_camera.dart';
import 'package:fast_barcode_scanner/messages/barcode_format.dart';
import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/messages/preview_details.dart';
import 'package:fast_barcode_scanner/overlays/blur_overlay.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Fast Barcode Scanner')),
        body: Builder(
          builder: (context) => Center(
            child: RaisedButton(
              child: Text("Open Scanner"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetectorScreen()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// This is outside of [DetectorScreen] to preserve [BarcodeCameraState] in hot reload.
/// Otherwise a new Key would be generated and thus a new [BarcodeCameraState].
final detector = GlobalKey<BarcodeCameraState>();

class DetectorScreen extends StatelessWidget {
  final _flashState = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Fast Barcode Scanner',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _flashState,
            builder: (context, state, _) => IconButton(
              icon: state
                  ? const Icon(Icons.flash_on)
                  : const Icon(Icons.flash_off),
              onPressed: () {
                FastBarcodeScanner.toggleFlash();
                _flashState.value = !_flashState.value;
              },
            ),
          )
        ],
      ),
      body: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
        BarcodeCamera(
          key: detector,
          formats: [
            BarcodeFormat.ean8,
            BarcodeFormat.ean13,
            BarcodeFormat.code128
          ],
          resolution: Resolution.hd720,
          framerate: Framerate.fps60,
          detectionMode: DetectionMode.pauseDetectionAndVideo,
          fadeInOnReady: true,
          overlayBuilder: (key) => BlurPreviewOverlay(key: key),
        ),
        Positioned(bottom: 50, child: Counter()),
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

class Counter extends StatefulWidget {
  @override
  _CounterState createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  @override
  void initState() {
    super.initState();
    _streamToken = FastBarcodeScanner.codeStream.listen((event) {
      final count = detectionCount.update(event.value, (value) => value + 1,
          ifAbsent: () => 1);
      detectionInfo.value = "${count}x\n${event.value}";
    });
  }

  @override
  void dispose() {
    _streamToken.cancel();
    super.dispose();
  }

  StreamSubscription _streamToken;
  Map<String, int> detectionCount = {};
  final detectionInfo = ValueNotifier("");

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(15))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
        child: ValueListenableBuilder(
            valueListenable: detectionInfo,
            builder: (context, info, child) => Text(
                  info,
                  textAlign: TextAlign.center,
                )),
      ),
    );
  }
}
