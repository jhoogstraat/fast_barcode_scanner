import 'dart:ui';

import 'package:flutter/material.dart';

import '../preview_overlay.dart';

class BlurPreviewOverlay extends PreviewOverlay {
  final double blurAmount;
  final Duration duration;

  BlurPreviewOverlay(
      {Key key,
      this.blurAmount = 30,
      this.duration = const Duration(milliseconds: 500)})
      : super(key: key);

  @override
  BlurPreviewOverlayState createState() => BlurPreviewOverlayState();
}

class BlurPreviewOverlayState extends PreviewOverlayState<BlurPreviewOverlay> {
  var isBlurred = false;

  @override
  void didDetectBarcode() async {
    setState(() => isBlurred = true);
  }

  @override
  void didResumePreview() async {
    setState(() => isBlurred = false);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: isBlurred ? widget.blurAmount : 0.0),
      duration: widget.duration,
      curve: Curves.easeOut,
      child: Container(color: Colors.black.withOpacity(0.0)),
      builder: (_, value, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: value, sigmaY: value), child: child),
    );
  }
}
