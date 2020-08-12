import 'dart:ui';

import 'package:fast_barcode_scanner/overlays/material_barcode_frame_painter.dart';
import 'package:flutter/material.dart';

import '../preview_overlay.dart';

class BlurPreviewOverlay extends PreviewOverlay {
  final double blurAmount;
  final Duration duration;

  BlurPreviewOverlay(
      {Key key,
      this.blurAmount = 30,
      this.duration = const Duration(milliseconds: 270)})
      : super(key: key);

  @override
  BlurPreviewOverlayState createState() => BlurPreviewOverlayState();
}

class BlurPreviewOverlayState extends PreviewOverlayState<BlurPreviewOverlay> {
  final isBlurred = ValueNotifier(false);

  @override
  Future<void> didDetectBarcode() async {
    isBlurred.value = true;
  }

  @override
  Future<void> didResumePreview() async {
    isBlurred.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: Stack(children: [
      SizedBox.expand(
        child: CustomPaint(
          painter: MaterialBarcodeFramePainter(),
          willChange: false,
          isComplex: true,
        ),
      ),
      ValueListenableBuilder(
        valueListenable: isBlurred,
        builder: (context, value, child) => TweenAnimationBuilder(
          tween: Tween(begin: 0.0, end: value ? widget.blurAmount : 0.0),
          duration: widget.duration,
          curve: Curves.easeOut,
          child: Container(color: Colors.black.withOpacity(0.0)),
          builder: (_, value, child) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
              child: child),
        ),
      )
    ]));
  }
}
