import 'dart:ui';

import 'package:fast_barcode_scanner/src/camera_controller.dart';
import 'package:flutter/material.dart';

class BlurPreviewOverlay extends StatelessWidget {
  final double blurAmount;
  final Duration duration;

  const BlurPreviewOverlay({
    Key? key,
    this.blurAmount = 30,
    this.duration = const Duration(milliseconds: 500),
  }) : super(key: key);

  bool shouldBlur(event) => event == CameraEvent.codeFound;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: CameraController.instance.state.eventNotifier,
        builder: (context, event, child) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: shouldBlur(event) ? blurAmount : 0.0),
            duration: duration,
            curve: Curves.easeOut,
            child: Container(color: Colors.black.withOpacity(0.0)),
            builder: (_, value, child) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
                child: child),
          );
        });
  }
}
