import 'package:flutter/material.dart';

import 'material_scanner_painter/material_barcode_frame_painter.dart';
import 'material_scanner_painter/material_sensing_painter.dart';

class MaterialPreviewOverlay extends StatefulWidget {
  const MaterialPreviewOverlay(
      {Key? key,
      this.animateDetection = true,
      this.aspectRatio = 16 / 9,
      this.backgroundColor = Colors.black38,
      this.scanViewBorderColor = Colors.black87,
      this.squareScanView = false})
      : super(key: key);

  final bool animateDetection;
  final double aspectRatio;
  final Color backgroundColor;
  final Color scanViewBorderColor;
  final bool squareScanView;

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
          duration: const Duration(milliseconds: 1100), vsync: this);

      const fadeIn = 20.0;
      const wait = 2.0;
      const expand = 25.0;

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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
          child: widget.animateDetection
              ? _buildAnimation(context)
              : CustomPaint(
                  painter: MaterialBarcodeFramePainter(
                      widget.aspectRatio,
                      widget.backgroundColor,
                      widget.scanViewBorderColor,
                      widget.squareScanView))),
    );
  }

  Widget _buildAnimation(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: MaterialBarcodeFramePainter(
            widget.aspectRatio,
            widget.backgroundColor,
            widget.scanViewBorderColor,
            widget.squareScanView),
        foregroundPainter: MaterialBarcodeSensingPainter(
            inflate: _inflateSequence.value, opacity: _opacitySequence.value),
      ),
    );
  }
}
