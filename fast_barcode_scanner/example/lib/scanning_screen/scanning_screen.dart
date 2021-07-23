import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../scan_history.dart';
import '../settings_screen/settings_screen.dart';
import 'scans_counter.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({Key? key}) : super(key: key);

  @override
  _ScanningScreenState createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final _torchIconState = ValueNotifier(false);

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
        mode: DetectionMode.pauseDetection,
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
              const ScansCounter(),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            cam.resumeCamera().catchError(presentErrorAlert),
                        child: const Text('Resume Camera'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            cam.resumeScanner().catchError(presentErrorAlert),
                        child: const Text('Resume Scanner'),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _torchIconState,
                        builder: (context, isTorchActive, _) => ElevatedButton(
                          onPressed: () async {
                            cam
                                .toggleTorch()
                                .then((torchState) =>
                                    _torchIconState.value = torchState)
                                .catchError((error, stackTrace) {
                              presentErrorAlert(error, stackTrace);
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
                          await cam
                              .pauseCamera()
                              .catchError((_, __) {}); // swallow errors

                          final dialog = SimpleDialog(
                            children: [
                              SimpleDialogOption(
                                child: const Text('Choose path'),
                                onPressed: () => Navigator.pop(context, 1),
                              ),
                              SimpleDialogOption(
                                child: const Text('Choose image'),
                                onPressed: () => Navigator.pop(context, 2),
                              ),
                              SimpleDialogOption(
                                child: const Text('Open Picker'),
                                onPressed: () => Navigator.pop(context, 3),
                              )
                            ],
                          );

                          final result = await showDialog<int>(
                              context: context, builder: (_) => dialog);
                          final ImageSource source;

                          switch (result) {
                            case 1:
                              source = ImageSource.path('path');
                              break;
                            case 2:
                              final bytes = await rootBundle.load(
                                'assets/barcode.jpg',
                              );
                              source = ImageSource.binary(bytes);
                              break;
                            case 3:
                              source = ImageSource.picker();
                              break;
                            default:
                              cam.resumeCamera();
                              return;
                          }

                          try {
                            final barcodes = await cam.scanImage(source);
                            for (final barcode in barcodes) {
                              history.add(barcode);
                            }

                            await cam.resumeCamera();
                          } catch (error, stack) {
                            presentErrorAlert(error, stack);
                          }
                        },
                        child: const Text('Pick image'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final config = cam.state.scannerConfig;
                          if (config != null) {
                            // swallow errors
                            cam.pauseCamera().catchError((_, __) {});

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SettingsScreen(config),
                              ),
                            );

                            cam.resumeCamera().catchError(presentErrorAlert);
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

  void presentErrorAlert(Object error, StackTrace stack) {
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
