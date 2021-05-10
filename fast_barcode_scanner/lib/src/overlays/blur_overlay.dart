import 'dart:ui';

import 'package:fast_barcode_scanner/src/camera_state.dart';
import 'package:flutter/material.dart';

class BlurPreviewOverlay extends StatelessWidget {
  final double blurAmount;
  final Duration duration;

  const BlurPreviewOverlay({
    Key? key,
    this.blurAmount = 30,
    this.duration = const Duration(milliseconds: 500),
  }) : super(key: key);

  bool blur(BuildContext context) =>
      CameraController.of(context) == CameraEvent.codeFound;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: blur(context) ? blurAmount : 0.0),
      duration: duration,
      curve: Curves.easeOut,
      child: Container(color: Colors.black.withOpacity(0.0)),
      builder: (_, value, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: value, sigmaY: value), child: child),
    );
  }
}
