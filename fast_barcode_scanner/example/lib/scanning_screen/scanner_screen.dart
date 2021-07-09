import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_example/scan_history.dart';
import 'package:fast_barcode_scanner_example/settings_screen/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'detections_counter.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({Key? key}) : super(key: key);

  @override
  _ScanningScreenState createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
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
        onScan: (code) => history.add(code),
        children: const [
          MaterialPreviewOverlay(showSensing: false),
          // BlurPreviewOverlay()
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DetectionsCounter(),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            CameraController.instance.pauseDetector(),
                        child: const Text('pause'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            CameraController.instance.resumeDetector(),
                        child: const Text('resume'),
                      ),
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
                    ],
                  ),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await CameraController.instance.pauseDetector();
                            final barcode = await CameraController.instance
                                .pickImageToAnalyze();
                            if (barcode != null) {
                              history.add(barcode);
                            }

                            CameraController.instance.resumeDetector();
                          } catch (error) {
                            presentErrorAlert(error);
                          }
                        },
                        child: const Text('Pick image'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final config =
                              CameraController.instance.state.scannerConfig;
                          if (config != null) {
                            CameraController.instance.pauseDetector();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SettingsScreen(config),
                              ),
                            );
                            CameraController.instance.resumeDetector();
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

  void presentErrorAlert(Object error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok'),
          )
        ],
      ),
    );
  }
}
