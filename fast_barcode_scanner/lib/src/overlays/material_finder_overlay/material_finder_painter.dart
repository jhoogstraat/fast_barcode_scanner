import 'package:fast_barcode_scanner/src/overlays/rect_of_interest.dart';
import 'package:flutter/widgets.dart';

/// Draws the viewfinder cutout and optional animated sensing border for
/// [MaterialPreviewOverlay].
class MaterialFinderPainter extends CustomPainter {
  MaterialFinderPainter({
    required this.borderColor,
    required this.rectOfInterest,
    this.backgroundColor,
    this.inflateAnimation,
    this.opacityAnimation,
  }) : super(
          repaint: inflateAnimation != null && opacityAnimation != null
              ? Listenable.merge([inflateAnimation, opacityAnimation])
              : null,
        );

  final Color borderColor;
  final Color? backgroundColor;
  final RectOfInterest rectOfInterest;
  final Animation<double>? inflateAnimation;
  final Animation<double>? opacityAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Offset.zero & size;
    final cutOut = RRect.fromRectXY(rectOfInterest.rect(screenRect), 12, 12);

    final inflate = inflateAnimation?.value ?? 0.0;
    final opacity = opacityAnimation?.value ?? 1.0;

    if (backgroundColor != null) {
      final cutOutPath = Path.combine(
        PathOperation.difference,
        Path()..addRect(screenRect),
        Path()..addRRect(cutOut),
      );
      canvas.drawPath(cutOutPath, Paint()..color = backgroundColor!);
    }

    if (opacity <= 0.0) return;

    final strokeWidth = inflateAnimation != null ? 5.0 - 4.0 * inflate : 5.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = opacity < 1.0
          ? borderColor.withAlpha((255 * opacity).round())
          : borderColor;

    final base = cutOut.deflate(strokeWidth / 2.0);
    final drawn = inflate > 0.0
        ? RRect.fromRectAndRadius(
            base.outerRect.inflate(inflate * 20.0),
            base.blRadius,
          )
        : base;

    canvas.drawRRect(drawn, paint);
  }

  @override
  bool shouldRepaint(MaterialFinderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.rectOfInterest != rectOfInterest ||
      oldDelegate.inflateAnimation != inflateAnimation ||
      oldDelegate.opacityAnimation != opacityAnimation;
}
