import 'dart:ui';

import 'package:fast_barcode_scanner/src/camera_controller.dart';
import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef ErrorCallback = Widget Function(BuildContext context, Object? error);

Widget _defaultOnError(BuildContext context, Object? error) {
  debugPrint("Error reading from camera: $error");
  return const Center(child: Text("Error reading from camera..."));
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    CameraController.instance
        .initialize(widget.types, widget.resolution, widget.framerate,
            widget.mode, widget.position, widget.onScan)
        .whenComplete(() => setState(() => _opacity = 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraController.instance.state;
    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 260),
        child: cameraState.hasError
            ? widget.onError(context, cameraState.error!)
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
        child: Texture(
          textureId: config.textureId,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
