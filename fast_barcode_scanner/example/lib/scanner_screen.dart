import 'dart:async';

import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'camera_settings/camera_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'detections_counter.dart';

final codeStream = StreamController<Barcode>.broadcast();

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _torchIconState = ValueNotifier(false);

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
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              final preview = CameraController.instance.state.previewConfig;
              if (preview != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Preview Config"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Texture Id: ${preview.textureId}"),
                        Text(
                            "Preview (WxH): ${preview.width}x${preview.height}"),
                        Text("Analysis (WxH): ${preview.analysisResolution}"),
                        Text(
                            "Target Rotation (unused): ${preview.targetRotation}"),
                      ],
                    ),
                  ),
                );
              }
            },
          )
        ],
      ),
      body: BarcodeCamera(
        types: const [
          BarcodeType.ean8,
          BarcodeType.ean13,
          BarcodeType.code128,
          BarcodeType.qr
        ],
        resolution: Resolution.hd720,
        framerate: Framerate.fps30,
        mode: DetectionMode.pauseVideo,
        position: CameraPosition.back,
        onScan: (code) => codeStream.add(code),
        children: const [
          MaterialPreviewOverlay(animateDetection: false),
          BlurPreviewOverlay()
        ],
      ),
      bottomSheet: SafeArea(
        // minimum: const EdgeInsets.only(bottom: 20),
        // bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DetectionsCounter(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            CameraController.instance.pauseDetector();
                          },
                          child: const Text('pause')),
                      ElevatedButton(
                          onPressed: () {
                            CameraController.instance.resumeDetector();
                          },
                          child: const Text('resume')),
                    ],
                  ),
                  Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _torchIconState,
                        builder: (context, isTorchActive, _) => ElevatedButton(
                          onPressed: () async {
                            await CameraController.instance.toggleTorch();
                            _torchIconState.value =
                                CameraController.instance.state.torchState;
                          },
                          child: Text('Torch: ${isTorchActive ? 'on' : 'off'}'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final config =
                              CameraController.instance.state.cameraConfig;
                          if (config != null) {
                            await CameraController.instance.pauseDetector();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CameraSettings(config),
                              ),
                            );
                          }
                        },
                        child: const Text('updateConfiguration'),
                      )
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
