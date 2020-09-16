import 'dart:async';
import 'dart:ui';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'preview_overlay.dart';

final ErrorCallback _defaultOnError = (BuildContext context, Object error) {
  debugPrint("Error reading from camera: $error");
  return Center(child: Text("Error reading from camera..."));
};

typedef PreviewOverlay OverlayBuilder(GlobalKey<PreviewOverlayState> key);
typedef Widget ErrorCallback(BuildContext context, Object error);

/// The main class connecting the platform code to the Flutter UI.
///
/// This class is used in a widget tree and connects to the camera
/// as soon as the build method gets called.
class BarcodeCamera extends StatefulWidget {
  BarcodeCamera(
      {Key key,
      @required this.types,
      @required this.onDetect,
      this.child,
      this.detectionMode = DetectionMode.pauseVideo,
      this.resolution = Resolution.hd720,
      this.framerate = Framerate.fps60,
      this.overlays = const [],
      ErrorCallback onError})
      : onError = onError ?? _defaultOnError,
        super(key: key);

  final List<BarcodeType> types;
  final void Function(Barcode) onDetect;
  final Widget child;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode detectionMode;
  final List<OverlayBuilder> overlays;
  final ErrorCallback onError;

  @override
  BarcodeCameraState createState() => BarcodeCameraState(overlays.length);
}

class BarcodeCameraState extends State<BarcodeCamera> {
  BarcodeCameraState(int overlays)
      : overlayKeys = List.generate(
            overlays, (_) => GlobalKey(debugLabel: "overlay_$overlays"));

  final List<GlobalKey<PreviewOverlayState>> overlayKeys;

  Future<void> _init;
  PreviewConfiguration _previewConfig;
  Object _error;
  double _opacity = 0.0;
  Iterable<Widget> _overlayCache;

  FastBarcodeScannerPlatform get _platformInstance =>
      FastBarcodeScannerPlatform.instance;

  @override
  void initState() {
    super.initState();
    _initDetector();
  }

  /// Informs the platform to initialize the camera.
  ///
  /// The camera is initialized only once per session.
  /// All susequent calls to this method will be dropped.
  /// Caution: The callback might be called many times in quick succession
  ///  when using [DetectionMode.continuous].
  void _initDetector() async {
    if (_init != null) return;

    _init = _platformInstance
        .init(widget.types, widget.resolution, widget.framerate,
            widget.detectionMode)
        .then((value) => _previewConfig = value)
        .catchError((error) => setState(() => _error = error))
        .whenComplete(() => setState(() => _opacity = 1.0));

    /// Notify the overlays when a barcode is detected and then call [onDetect].
    _platformInstance.setOnDetectHandler((barcode) {
      overlayKeys.forEach((key) => key.currentState.didDetectBarcode());
      widget.onDetect(barcode);
    });
  }

  Future<void> pauseDetector() => _platformInstance.pause();

  void resumeDetector() async {
    await _platformInstance.resume();
    overlayKeys.forEach((key) => key.currentState.didResumePreview());
  }

  @override
  dispose() {
    _platformInstance.dispose();
    super.dispose();
  }

  Future<bool> _togglingTorch;

  Future<bool> toggleTorch() async {
    if (_togglingTorch == null)
      _togglingTorch = _platformInstance
          .toggleTorch()
          .whenComplete(() => _togglingTorch = null);
    return _togglingTorch;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 260),
        child: Stack(fit: StackFit.expand, children: [
          if (_error != null) widget.onError(context, _error),
          if (_previewConfig != null) _buildPreview(_previewConfig),
          if (_previewConfig != null) ..._buildOverlays(),
          if (widget.child != null) widget.child
        ]),
      ),
    );
  }

  Iterable<Widget> _buildOverlays() {
    if (_overlayCache == null)
      _overlayCache = widget.overlays
          .asMap()
          .entries
          .map((entry) => entry.value(overlayKeys[entry.key]));
    return _overlayCache;
  }

  Widget _buildPreview(PreviewConfiguration details) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: details.width.toDouble(),
        height: details.height.toDouble(),
        child: Texture(
          textureId: details.textureId,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
