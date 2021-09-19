import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../scan_history.dart';
import '../configure_screen/configure_screen.dart';
import '../utils.dart';
import 'scans_counter.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({Key? key, required this.dispose}) : super(key: key);

  final bool dispose;

  @override
  _ScanningScreenState createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final _torchIconState = ValueNotifier(false);
  final _cameraRunning = ValueNotifier(true);
  final _scannerRunning = ValueNotifier(true);

  final cam = CameraController();

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
              final preview = cam.state.previewConfig;
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
        dispose: widget.dispose,
      ),
      bottomSheet: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScansCounter(),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      ValueListenableBuilder<bool>(
                          valueListenable: _cameraRunning,
                          builder: (context, isRunning, _) {
                            return ElevatedButton(
                              onPressed: () {
                                final future = isRunning
                                    ? cam.pauseCamera()
                                    : cam.resumeCamera();

                                future
                                    .then((_) =>
                                        _cameraRunning.value = !isRunning)
                                    .catchError((error, stack) {
                                  presentErrorAlert(context, error, stack);
                                });
                              },
                              child: Text(
                                  isRunning ? 'Pause Camera' : 'Resume Camera'),
                            );
                          }),
                      ValueListenableBuilder<bool>(
                          valueListenable: _scannerRunning,
                          builder: (context, isRunning, _) {
                            return ElevatedButton(
                              onPressed: () {
                                final future = isRunning
                                    ? cam.pauseScanner()
                                    : cam.resumeScanner();

                                future
                                    .then((_) =>
                                        _scannerRunning.value = !isRunning)
                                    .catchError((error, stackTrace) {
                                  presentErrorAlert(context, error, stackTrace);
                                });
                              },
                              child: Text(isRunning
                                  ? 'Pause Scanner'
                                  : 'Resume Scanner'),
                            );
                          }),
                      ValueListenableBuilder<bool>(
                        valueListenable: _torchIconState,
                        builder: (context, isTorchActive, _) => ElevatedButton(
                          onPressed: () {
                            cam
                                .toggleTorch()
                                .then((torchState) =>
                                    _torchIconState.value = torchState)
                                .catchError((error, stackTrace) {
                              presentErrorAlert(context, error, stackTrace);
                            });
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
                          final config = cam.state.scannerConfig;
                          if (config != null) {
                            // swallow errors
                            cam.pauseCamera().catchError((_, __) {});

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConfigureScreen(config),
                              ),
                            );

                            cam.resumeCamera().catchError((error, stack) =>
                                presentErrorAlert(context, error, stack));
                          }
                        },
                        child: const Text('Update Configuration'),
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
