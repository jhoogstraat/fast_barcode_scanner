import 'package:flutter/material.dart';

import 'material_scanner_painter/material_barcode_frame_painter.dart';
import 'material_scanner_painter/material_sensing_painter.dart';

class MaterialPreviewOverlay extends StatefulWidget {
  const MaterialPreviewOverlay(
      {Key? key, this.animateDetection = true, this.aspectRatio = 16 / 9})
      : super(key: key);

  final bool animateDetection;
  final double aspectRatio;

  @override
  MaterialPreviewOverlayState createState() => MaterialPreviewOverlayState();
}

class MaterialPreviewOverlayState extends State<MaterialPreviewOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacitySequence;
  late Animation<double> _inflateSequence;

  @override
  void initState() {
    super.initState();

    if (widget.animateDetection) {
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
  }

  // @override
  // void didDetectBarcode() async {
  //   if (widget.animateDetection) {
  //     await _controller.forward();
  //     _controller.reset();
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
          child: widget.animateDetection
              ? _buildAnimation(context)
              : CustomPaint(
                  painter: MaterialBarcodeFramePainter(widget.aspectRatio))),
    );
  }

  Widget _buildAnimation(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: MaterialBarcodeFramePainter(widget.aspectRatio),
        foregroundPainter: MaterialBarcodeSensingPainter(
            inflate: _inflateSequence.value, opacity: _opacitySequence.value),
      ),
    );
  }
}
