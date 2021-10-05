import '../../camera_controller.dart';
import '../../types/scanner_event.dart';
import 'package:flutter/material.dart';

import 'material_finder_painter.dart';

enum CutOutShape { square, wide }

/// Mimics the official Material Design Barcode Scanner
/// (https://material.io/design/machine-learning/barcode-scanning.html)
///
class MaterialPreviewOverlay extends StatefulWidget {
  /// Creates a material barcode overlay.
  ///
  /// * `showSensing` animates the finder border.
  /// (Increased cpu usage confirmed on iOS when enabled)
  ///
  /// * `aspectRatio` of the finder border.
  ///
  const MaterialPreviewOverlay({
    Key? key,
    this.showSensing = false,
    this.sensingColor = Colors.white,
    this.backgroundColor = Colors.black38,
    this.cutOutShape = CutOutShape.wide,
    this.cutOutBorderColor = Colors.black87,
  }) : super(key: key);

  final bool showSensing;
  final Color backgroundColor;
  final Color sensingColor;
  final CutOutShape cutOutShape;
  final Color cutOutBorderColor;

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
    if (widget.showSensing) {
      _controller = AnimationController(
          duration: const Duration(milliseconds: 1100), vsync: this);

      const fadeIn = 20.0;
      const wait = 2.0;
      const expand = 25.0;

      final cameraController = CameraController();

      _opacitySequence = TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: fadeIn),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: wait),
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.0)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: expand),
        // TweenSequenceItem(tween: ConstantTween(0.0), weight: wait),
      ]).animate(_controller);

      _inflateSequence = TweenSequence([
        TweenSequenceItem(tween: ConstantTween(0.0), weight: fadeIn + wait),
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: expand),
        // TweenSequenceItem(tween: ConstantTween(0.0), weight: wait),
      ]).animate(_controller);

      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            cameraController.events.value == ScannerEvent.resumed) {
          Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
            _controller.forward(from: _controller.lowerBound);
          });
        }
      });

      cameraController.events.addListener(() {
        if (cameraController.events.value == ScannerEvent.resumed) {
          _controller.forward();
        } else {
          _controller.reset();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 // strokeWidth is painted 50/50 outwards and inwards.
      ..color = widget.cutOutBorderColor;

    final sensingBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5; // strokeWidth is painted 50/50 outwards and inwards.

    return RepaintBoundary(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: MaterialFinderPainter(
                borderPaint: defaultBorderPaint,
                backgroundColor: widget.backgroundColor,
                cutOutShape: widget.cutOutShape,
              ),
            ),
            if (widget.showSensing)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => CustomPaint(
                  foregroundPainter: MaterialFinderPainter(
                    inflate: _inflateSequence.value,
                    opacity: _opacitySequence.value,
                    sensingColor: widget.sensingColor,
                    drawBackground: false,
                    borderPaint: sensingBorderPaint,
                    backgroundColor: widget.backgroundColor,
                    cutOutShape: widget.cutOutShape,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
