import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';

import '../configure_screen/configure_screen.dart';
import '../scan_history.dart';
import '../utils.dart';
import 'scans_counter.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({
    super.key,
    this.apiMode = const ApiMode(),
    required this.dispose,
  });

  final ApiMode apiMode;
  final bool dispose;

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
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

  final List<String> enabledOverlays = ['Material', 'Boundary'];

  final cam = CameraController.shared;

  @override
  void dispose() {
    _torchIconState.dispose();
    _cameraRunning.dispose();
    _scannerRunning.dispose();
    super.dispose();
  }

  Future<void> _toggleCamera() async {
    final isRunning = _cameraRunning.value;
    try {
      if (isRunning) {
        await cam.pauseCamera();
      } else {
        await cam.resumeCamera();
      }
      _cameraRunning.value = !isRunning;
    } catch (error, stack) {
      if (!mounted) return;
      presentErrorAlert(context, error, stack);
    }
  }

  Future<void> _toggleScanner() async {
    final isRunning = _scannerRunning.value;
    try {
      if (isRunning) {
        await cam.pauseScanner();
      } else {
        await cam.resumeScanner();
      }
      _scannerRunning.value = !isRunning;
    } catch (error, stack) {
      if (!mounted) return;
      presentErrorAlert(context, error, stack);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      final torchState = await cam.toggleTorch();
      _torchIconState.value = torchState;
    } catch (error, stack) {
      if (!mounted) return;
      presentErrorAlert(context, error, stack);
    }
  }

  Future<void> _switchCamera() async {
    try {
      await cam.switchCamera();
    } catch (error, stack) {
      if (!mounted) return;
      presentErrorAlert(context, error, stack);
    }
  }

  Future<void> _openConfig() async {
    final config = cam.state.value.scannerConfig;
    if (config == null) return;

    await cam.pauseCamera().catchError((_) {});
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfigureScreen()),
    );

    try {
      await cam.resumeCamera();
    } catch (error, stack) {
      if (!mounted) return;
      presentErrorAlert(context, error, stack);
    }
  }

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
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            tooltip: 'Switch camera',
            onPressed: _switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.info, color: Colors.white),
            onPressed: () {
              final preview = cam.state.value.cameraInformation;
              if (preview != null) {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Camera Info'),
                    content: Text(preview.toString()),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: BarcodeCamera(
        types: const [
          BarcodeType.ean8,
          BarcodeType.ean13,
          BarcodeType.code128,
          BarcodeType.qr,
        ],
        mode: PerformanceMode.system,
        detectionMode: DetectionMode.continuous,
        position: CameraPosition.back,
        api: widget.apiMode,
        onScan: history.addAll,
        dispose: widget.dispose,
        children: [
          if (enabledOverlays.contains('Material'))
            MaterialPreviewOverlay(
              rectOfInterest: RectOfInterest.wide(),
              onScan: (codes) {},
              showSensing: true,
              onScannedBoundsColor: (codes) {
                if (codes.isNotEmpty) {
                  return codes.first.value.hashCode % 2 == 0
                      ? Colors.orange
                      : Colors.green;
                }
                return null;
              },
            ),
          if (enabledOverlays.contains('Boundary'))
            CodeBoundaryOverlay(
              codeBorderPaintBuilder: (code) {
                return code.value.hashCode % 2 == 0 ? orangePaint : greenPaint;
              },
              barcodeValueStyle: (code) => TextStyle(
                color:
                    code.value.hashCode % 2 == 0 ? Colors.orange : Colors.green,
              ),
            ),
          if (enabledOverlays.contains('Blur')) const BlurPreviewOverlay(),
        ],
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
                              builder: (context, isRunning, _) =>
                                  ElevatedButton(
                                onPressed: _toggleCamera,
                                child: Text(
                                  isRunning ? 'Pause Camera' : 'Resume Camera',
                                ),
                              ),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _scannerRunning,
                              builder: (context, isRunning, _) =>
                                  ElevatedButton(
                                onPressed: _toggleScanner,
                                child: Text(
                                  isRunning
                                      ? 'Pause Scanner'
                                      : 'Resume Scanner',
                                ),
                              ),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _torchIconState,
                              builder: (context, isTorchActive, _) =>
                                  ElevatedButton(
                                onPressed: _toggleTorch,
                                child: Text(
                                  'Torch: ${isTorchActive ? 'on' : 'off'}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: _openConfig,
                              child: const Text('Update Configuration'),
                            ),
                            ElevatedButton(
                              onPressed: _switchCamera,
                              child: const Text('Switch Camera'),
                            ),
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
