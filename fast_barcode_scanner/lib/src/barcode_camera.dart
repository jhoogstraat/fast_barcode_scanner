import 'dart:ui';

import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner/src/camera_controller.dart';
import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef ErrorCallback = Widget Function(BuildContext context, Object? error);

Widget _defaultOnError(BuildContext context, Object? error) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Center(
      child: Text(
        "Error:\n$error",
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

/// The main class connecting the platform code to the UI.
///
/// This class is used in the widget tree and connects to the camera
/// as soon as didChangeDependencies gets called.
class BarcodeCamera extends StatefulWidget {
  const BarcodeCamera({
    Key? key,
    required this.types,
    this.mode = DetectionMode.pauseVideo,
    this.resolution = Resolution.hd720,
    this.framerate = Framerate.fps30,
    this.position = CameraPosition.back,
    this.onScan,
    this.children = const [],
    ErrorCallback? onError,
  })  : onError = onError ?? _defaultOnError,
        super(key: key);

  final List<BarcodeType> types;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode mode;
  final CameraPosition position;
  final void Function(Barcode)? onScan;
  final List<Widget> children;
  final ErrorCallback onError;

  @override
  BarcodeCameraState createState() => BarcodeCameraState();
}

class BarcodeCameraState extends State<BarcodeCamera> {
  var _opacity = 0.0;
  var showingError = false;

  final cameraController = CameraController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    cameraController
        .initialize(widget.types, widget.resolution, widget.framerate,
            widget.position, widget.mode, widget.onScan)
        .whenComplete(() => setState(() => _opacity = 1.0))
        .onError((error, stackTrace) => setState(() => showingError = true));

    cameraController.events.addListener(onScannerEvent);
  }

  void onScannerEvent() {
    if (cameraController.events.value != ScannerEvent.error && showingError) {
      setState(() => showingError = false);
    } else if (cameraController.events.value == ScannerEvent.error) {
      setState(() => showingError = true);
    }
  }

  @override
  void dispose() {
    cameraController.pauseCamera();
    cameraController.events.removeListener(onScannerEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = cameraController.state;
    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 260),
        child: cameraController.events.value == ScannerEvent.error
            ? widget.onError(
                context,
                cameraState.error ?? "Unknown error occured",
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraState.isInitialized)
                    _buildPreview(cameraState.previewConfig!),
                  ...widget.children
                ],
              ),
      ),
    );
  }

  Widget _buildPreview(PreviewConfiguration config) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: config.width.toDouble(),
        height: config.height.toDouble(),
        child: Builder(
          builder: (_) {
            switch (defaultTargetPlatform) {
              case TargetPlatform.android:
                return Texture(
                  textureId: config.textureId,
                  filterQuality: FilterQuality.none,
                );
              case TargetPlatform.iOS:
                return const UiKitView(
                  viewType: "fast_barcode_scanner.preview",
                  creationParamsCodec: StandardMessageCodec(),
                );
              default:
                throw UnsupportedError("Unsupported platform");
            }
          },
        ),
      ),
    );
  }
}
