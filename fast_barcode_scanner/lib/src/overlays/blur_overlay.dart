import 'dart:ui';

import '../camera_controller.dart';
import '../types/scanner_event.dart';
import 'package:flutter/material.dart';

/// Blurs the preview when a barcode is detected
///
/// NOTICE: Does not work on iOS currently
/// (see: https://github.com/flutter/flutter/issues/43902)
class BlurPreviewOverlay extends StatelessWidget {
  final double blurAmount;
  final Duration duration;

  const BlurPreviewOverlay({
    Key? key,
    this.blurAmount = 30,
    this.duration = const Duration(milliseconds: 500),
  }) : super(key: key);

  bool shouldBlur(event) => event == ScannerEvent.codeFound;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CameraController().events,
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
      },
    );
  }
}
