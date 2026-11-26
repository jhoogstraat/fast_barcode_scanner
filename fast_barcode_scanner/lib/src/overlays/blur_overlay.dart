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

  final double blurAmount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScannerEvent>(
      valueListenable: CameraController.shared.eventNotifier,
      builder: (context, event, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0.0,
            end: event == ScannerEvent.detected ? blurAmount : 0.0,
          ),
          duration: duration,
          curve: Curves.easeOut,
          child: const SizedBox.expand(),
          builder: (_, value, child) {
            if (value <= 0.01) return child!;
            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}
