import 'package:flutter/material.dart';

import '../preview_overlay.dart';
import 'material_barcode_frame_painter.dart';

class MaterialPreviewOverlay extends PreviewOverlay {
  MaterialPreviewOverlay({Key key}) : super(key: key);

  @override
  MaterialPreviewOverlayState createState() => MaterialPreviewOverlayState();
}

class MaterialPreviewOverlayState
    extends PreviewOverlayState<MaterialPreviewOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _opacitySequence;
  Animation<double> _inflateSequence;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: Duration(milliseconds: 1100), vsync: this);

    final fadeIn = 20.0;
    final wait = 2.0;
    final expand = 25.0;

    _opacitySequence = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: fadeIn),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: wait),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: expand),
      // TweenSequenceItem(tween: ConstantTween(0.0), weight: idle),
    ]).animate(_controller);

    _inflateSequence = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: fadeIn + wait),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: expand),
      // TweenSequenceItem(tween: ConstantTween(0.0), weight: idle),
    ]).animate(_controller);
  }

  @override
  Future<void> didDetectBarcode() async {
    await _controller.forward();
    _controller.reset();
  }

  @override
  Future<void> didResumePreview() async {
    return;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => _buildAnimation(context)),
    );
  }

  Widget _buildAnimation(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
          painter: MaterialBarcodeFramePainter(),
          foregroundPainter: MaterialBarcodeSensingPainter(
              inflate: _inflateSequence.value,
              opacity: _opacitySequence.value)),
    );
  }
}

class MaterialBarcodeSensingPainter extends CustomPainter {
  MaterialBarcodeSensingPainter({this.inflate, this.opacity});

  final double inflate;
  final double opacity;

  final sensingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5; // strokeWidth is painted 50/50 outwards and inwards.

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final cutOut = RRect.fromRectXY(
        Rect.fromCenter(
            center: rect.center, width: rect.width - 45, height: 165),
        12,
        12);

    sensingPaint.color = Colors.white.withAlpha((255 * opacity).toInt());
    sensingPaint.strokeWidth = 5 - 4 * inflate;

    canvas.drawRRect(
        _inflate(cutOut.deflate(sensingPaint.strokeWidth / 2)), sensingPaint);
  }

  /// Inflates a rect, but keeps the border radius.
  RRect _inflate(RRect rect) {
    return RRect.fromRectAndRadius(
        rect.outerRect.inflate(inflate * 20), rect.blRadius);
  }

  @override
  bool shouldRepaint(MaterialBarcodeSensingPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.inflate != inflate;
  }
}
