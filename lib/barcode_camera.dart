import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'fast_barcode_scanner.dart';
import 'messages/barcode_format.dart';
import 'messages/preview_details.dart';
import 'overlays/preview_overlay_base.dart';

final ErrorCallback _defaultOnError = (BuildContext context, Object error) {
  print("Error reading from camera: $error");
  return Text("Error reading from camera...");
};

typedef PreviewOverlay OverlayBuilder(GlobalKey<PreviewOverlayState> key);
typedef Widget ErrorCallback(BuildContext context, Object error);

class BarcodeCamera extends StatefulWidget {
  BarcodeCamera(
      {Key key,
      @required this.formats,
      this.resolution,
      this.framerate,
      this.detectionMode,
      this.fadeInOnReady,
      this.overlayBuilder,
      ErrorCallback onError})
      : onError = onError ?? _defaultOnError,
        super(key: key);

  final List<BarcodeFormat> formats;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode detectionMode;
  final bool fadeInOnReady;
  final OverlayBuilder overlayBuilder;
  final ErrorCallback onError;

  @override
  BarcodeCameraState createState() => BarcodeCameraState();
}

class BarcodeCameraState extends State<BarcodeCamera>
    with WidgetsBindingObserver {
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

  // State
  Future<PreviewDetails> _previewDetails;
  StreamSubscription _eventStreamToken;
  StreamSubscription _codeStreamToken;
  final GlobalKey<PreviewOverlayState> overlayKey = GlobalKey();

  void _initDetector() {
    if (_previewDetails == null)
      _previewDetails = FastBarcodeScanner.start(
          formats: widget.formats,
          resolution: widget.resolution,
          framerate: widget.framerate,
          detectionMode: widget.detectionMode);

    if (widget.detectionMode != DetectionMode.continuous &&
        widget.overlayBuilder != null)
      _codeStreamToken = FastBarcodeScanner.codeStream.listen((_) {
        overlayKey.currentState.didDetectBarcode();
      });
  }

  Future<void> resumeDetector() async {
    await FastBarcodeScanner.resume();
    overlayKey?.currentState?.didResumePreview();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreviewDetails>(
      future: _previewDetails,
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
                if (widget.overlayBuilder != null)
                  widget.overlayBuilder(overlayKey),
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
  Widget _fittedPreview(PreviewDetails details) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
          width: details.width.toDouble(),
          height: details.height.toDouble(),
          child: Texture(textureId: details.textureId)),
    );
  }

  Widget previewFader() {
    return TweenAnimationBuilder(
      tween: ColorTween(begin: Colors.black, end: Colors.transparent),
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 260),
      builder: (_, value, __) => Container(
        color: value,
      ),
    );
  }
}
