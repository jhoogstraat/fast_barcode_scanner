import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'detections_counter.dart';

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
        children: [
          MaterialPreviewOverlay(animateDetection: false),
          BlurPreviewOverlay(),
          Positioned(
            bottom: 50,
            child: Column(
              children: [
                ElevatedButton(
                  child: Text("Resume"),
                  onPressed: () => CameraController.instance.resumeDetector(),
                ),
                SizedBox(height: 20),
                DetectionsCounter()
              ],
            ),
          )
        ],
      ),
    );
  }
}
