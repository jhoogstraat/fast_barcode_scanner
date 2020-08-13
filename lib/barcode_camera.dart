import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'fast_barcode_scanner.dart';
import 'messages/barcode_type.dart';
import 'messages/preview_configuration.dart';
import 'preview_overlay.dart';

final ErrorCallback _defaultOnError = (BuildContext context, Object error) {
  print("Error reading from camera: $error");
  return Text("Error reading from camera...");
};

typedef PreviewOverlay OverlayBuilder(GlobalKey<PreviewOverlayState> key);
typedef Widget ErrorCallback(BuildContext context, Object error);

class BarcodeCamera extends StatefulWidget {
  BarcodeCamera(
      {Key key,
      @required this.types,
      this.detectionMode,
      this.resolution = Resolution.hd720,
      this.framerate = Framerate.fps60,
      this.fadeInOnReady = true,
      this.overlays = const [],
      ErrorCallback onError})
      : onError = onError ?? _defaultOnError,
        super(key: key);

  final List<BarcodeType> types;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode detectionMode;
  final bool fadeInOnReady;
  final List<OverlayBuilder> overlays;
  final ErrorCallback onError;

  @override
  BarcodeCameraState createState() => BarcodeCameraState(overlays.length);
}

class BarcodeCameraState extends State<BarcodeCamera>
    with WidgetsBindingObserver {
  BarcodeCameraState(int overlays)
      : overlayKeys = List.generate(overlays, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDetector();
  }

  @override
  dispose() {
    FastBarcodeScanner.stop();
    _eventStreamToken?.cancel();
    _codeStreamToken?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        FastBarcodeScanner.resume();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        FastBarcodeScanner.pause();
        break;
    }
  }

  final List<GlobalKey<PreviewOverlayState>> overlayKeys;

  // State
  Future<PreviewConfiguration> _previewConfiguration;
  StreamSubscription _eventStreamToken;
  StreamSubscription _codeStreamToken;

  void _initDetector() {
    // Only start the Scanner once.
    if (_previewConfiguration == null) {
      _previewConfiguration = FastBarcodeScanner.start(
          types: widget.types,
          resolution: widget.resolution,
          framerate: widget.framerate,
          detectionMode: widget.detectionMode);
    }

    // Notify the overlay when a barcode is detected.
    // Only happens when the detection mode is not continous,
    // because that would required throttling the incoming barcodes.
    if (widget.detectionMode != DetectionMode.continuous &&
        widget.overlays.isNotEmpty)
      _codeStreamToken = FastBarcodeScanner.detections.listen((_) {
        overlayKeys.forEach((key) => key.currentState.didDetectBarcode());
      });
  }

  Future<void> resumeDetector() async {
    await FastBarcodeScanner.resume();
    overlayKeys.forEach((key) => key.currentState.didDetectBarcode());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreviewConfiguration>(
      future: _previewConfiguration,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Container(color: Colors.black);
          case ConnectionState.done:
            if (snapshot.hasError) {
              debugPrint(snapshot.error.toString());
              return widget.onError(context, snapshot.error);
            }

            return Stack(
              children: [
                _fittedPreview(snapshot.data),
                if (widget.fadeInOnReady) previewFader(),
                ...widget.overlays
                    .asMap()
                    .entries
                    .map((entry) => entry.value(overlayKeys[entry.key]))
              ],
            );
            break;
          default:
            throw AssertionError("${snapshot.connectionState} not supported.");
        }
      },
    );
  }

  /// TODO: [FittedBox] produces a wrong height (666.7 instead of 667 on iPhone 6 screen size).
  /// This results in a white line at the bottom.
  Widget _fittedPreview(PreviewConfiguration details) {
    print(details.height.toDouble());
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
          width: details.width.toDouble(),
          height: details.height.toDouble() * 1.001,
          child: Texture(textureId: details.textureId)),
    );
  }

  Widget previewFader() {
    return TweenAnimationBuilder(
      tween: ColorTween(begin: Colors.black, end: Colors.transparent),
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 260),
      builder: (_, value, __) => Container(color: value),
    );
  }
}
