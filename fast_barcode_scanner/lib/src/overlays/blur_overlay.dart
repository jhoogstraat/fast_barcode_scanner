import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../camera_controller.dart';
import '../types/scanner_event.dart';

/// Blurs the camera preview when a barcode is detected.
class BlurPreviewOverlay extends StatelessWidget {
  /// Creates a [BlurPreviewOverlay].
  const BlurPreviewOverlay({
    super.key,
    this.blurAmount = 30,
    this.duration = const Duration(milliseconds: 500),
  });

  /// Maximum Gaussian blur sigma applied on detection.
  final double blurAmount;

  /// Animation duration for fading the blur in and out.
  final Duration duration;

  bool _shouldBlur(ScannerEvent event) => event == ScannerEvent.detected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScannerEvent>(
      valueListenable: CameraController.shared.eventNotifier,
      builder: (context, event, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: _shouldBlur(event) ? blurAmount : 0.0),
          duration: duration,
          curve: Curves.easeOut,
          child: const SizedBox.expand(),
          builder: (_, value, child) {
            if (value <= 0.01) {
              return child!;
            }
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
              child: child,
            );
          },
        );
      },
    );
  }
}
