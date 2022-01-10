import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_example/scanning_screen/scanning_overlay_config.dart';
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
  bool _isShowingBottomSheet = false;
  final greenPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..color = Colors.green;

  final orangePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.bevel
    ..color = Colors.orange;

  ScanningOverlayConfig _scanningOverlayConfig = ScanningOverlayConfig(
      ScanningOverlayType.values, ScanningOverlayType.codeBoundaryOverlay);

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
        mode: DetectionMode.continuous,
        position: CameraPosition.back,
        onScan: (code) => history.add(code),
        children: [
          if (_scanningOverlayConfig.enabledOverlay ==
              ScanningOverlayType.materialOverlay)
            const MaterialPreviewOverlay(),
          if (_scanningOverlayConfig.enabledOverlay ==
              ScanningOverlayType.codeBoundaryOverlay)
            CodeBoundaryOverlay(
              customBarcodePaint: (code) {
                return code.value.hashCode % 2 == 0 ? orangePaint : greenPaint;
              },
              barcodeTextDecorator: (code) {
                return SimpleTextDecoration(
                  text: code.value,
                  color: code.value.hashCode % 2 == 0
                      ? Colors.orange
                      : Colors.green,
                  location: TextDecorationLocation.centerTop,
                );
              },
            ),
          if (_scanningOverlayConfig.enabledOverlay ==
              ScanningOverlayType.blurPreview)
            const BlurPreviewOverlay()
        ],
        dispose: widget.dispose,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isShowingBottomSheet = !_isShowingBottomSheet;
          });
        },
        child: Icon(_isShowingBottomSheet ? Icons.close : Icons.settings),
      ),
      bottomSheet: _isShowingBottomSheet
          ? SafeArea(
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
                                        presentErrorAlert(
                                            context, error, stack);
                                      });
                                    },
                                    child: Text(isRunning
                                        ? 'Pause Camera'
                                        : 'Resume Camera'),
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
                                          .then((_) => _scannerRunning.value =
                                              !isRunning)
                                          .catchError((error, stackTrace) {
                                        presentErrorAlert(
                                            context, error, stackTrace);
                                      });
                                    },
                                    child: Text(isRunning
                                        ? 'Pause Scanner'
                                        : 'Resume Scanner'),
                                  );
                                }),
                            ValueListenableBuilder<bool>(
                              valueListenable: _torchIconState,
                              builder: (context, isTorchActive, _) =>
                                  ElevatedButton(
                                onPressed: () {
                                  cam
                                      .toggleTorch()
                                      .then((torchState) =>
                                          _torchIconState.value = torchState)
                                      .catchError((error, stackTrace) {
                                    presentErrorAlert(
                                        context, error, stackTrace);
                                  });
                                },
                                child: Text(
                                    'Torch: ${isTorchActive ? 'on' : 'off'}'),
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
                                      builder: (_) => ConfigureScreen(
                                        config,
                                        _scanningOverlayConfig,
                                        onOverlayConfigurationChanged:
                                            (overlayConfig) {
                                          setState(() {
                                            _scanningOverlayConfig =
                                                overlayConfig;
                                          });
                                        },
                                      ),
                                    ),
                                  );

                                  cam.resumeCamera().catchError((error,
                                          stack) =>
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
            )
          : null,
    );
  }
}
