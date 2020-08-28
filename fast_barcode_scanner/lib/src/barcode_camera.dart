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

class BarcodeCameraState extends State<BarcodeCamera>
    with WidgetsBindingObserver {
  BarcodeCameraState(int overlays)
      : overlayKeys = List.generate(
            overlays, (_) => GlobalKey(debugLabel: "overlay_$overlays"));

  FastBarcodeScannerPlatform get _platformInstance =>
      FastBarcodeScannerPlatform.instance;

  final List<GlobalKey<PreviewOverlayState>> overlayKeys;

  Future<void> _init;
  PreviewConfiguration _previewConfiguration;
  Error _error;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDetector();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_previewConfiguration == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _platformInstance.resume();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _platformInstance.pause();
        break;
    }
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
        .then((value) => _previewConfiguration = value)
        .catchError((error) => _error = error)
        .whenComplete(() => setState(() => _opacity = 1.0));

    // Notify the overlays when a barcode is detected and then call [onDetect].
    _platformInstance.setOnDetectHandler((barcode) {
      overlayKeys.forEach((key) => key.currentState.didDetectBarcode());
      widget.onDetect(barcode);
    });
  }

  void resumeDetector() async {
    await _platformInstance.resume();
    overlayKeys.forEach((key) => key.currentState.didResumePreview());
  }

  @override
  dispose() {
    _platformInstance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> toggleTorch() {
    return _platformInstance.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 260),
      child: Stack(children: [
        if (_error != null) widget.onError(context, _error),
        if (_previewConfiguration != null) _buildPreview(_previewConfiguration),
        if (_previewConfiguration != null) ..._buildOverlays(),
        if (widget.child != null) widget.child
      ]),
    );
  }

  Iterable<Widget> _buildOverlays() {
    return widget.overlays
        .asMap()
        .entries
        .map((entry) => entry.value(overlayKeys[entry.key]));
  }

  /// TODO: [FittedBox] produces a wrong height (666.7 instead of 667 on iPhone 6 screen size).
  /// This results in a white line at the bottom.
  Widget _buildPreview(PreviewConfiguration details) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 260),
      builder: (_, value, __) => Opacity(
        opacity: value,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
              width: details.width.toDouble(),
              height: details.height.toDouble() * 1.001,
              child: Texture(textureId: details.textureId)),
        ),
      ),
    );
  }
}
