import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';

import '../../camera_controller.dart';
import '../rect_of_interest/rect_of_interest.dart';
import 'material_finder_painter.dart';

/// returns a color for the finder boundary when codes are found inside
typedef OnScannedBoundaryColorSelector = Color? Function(
    List<Barcode> scannedCodes);

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
    required this.rectOfInterest,
    this.showSensing = false,
    this.sensingColor = Colors.white,
    this.backgroundColor = Colors.black38,
    this.cutOutBorderColor = Colors.black87,
    this.onScan,
    this.onScannedBoundaryColorSelector,
  }) : super(key: key);

  final bool showSensing;
  final Color? backgroundColor;
  final Color sensingColor;
  final Color cutOutBorderColor;
  final OnScannedBoundaryColorSelector? onScannedBoundaryColorSelector;
  final RectOfInterest rectOfInterest;

  /// This callback returns only the codes that are scanned within the boundary of the cutout
  final OnDetectionHandler? onScan;

  @override
  MaterialPreviewOverlayState createState() => MaterialPreviewOverlayState();
}

class MaterialPreviewOverlayState extends State<MaterialPreviewOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacitySequence;
  Animation<double>? _inflateSequence;

  @override
  void initState() {
    super.initState();
    final cameraController = CameraController();

    if (widget.showSensing) {
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
        // TweenSequenceItem(tween: ConstantTween(0.0), weight: wait),
      ]).animate(_controller!);

      _inflateSequence = TweenSequence([
        TweenSequenceItem(tween: ConstantTween(0.0), weight: fadeIn + wait),
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: expand),
        // TweenSequenceItem(tween: ConstantTween(0.0), weight: wait),
      ]).animate(_controller!);

      _controller!.addStatusListener((status) {
        if (status == AnimationStatus.completed && _filteredCodes.isEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _controller!.forward(from: _controller!.lowerBound);
            }
          });
        }
      });

      _controller!.forward();
    }
    cameraController.scannedBarcodes.addListener(_onCodesScanned);
  }

  @override
  void dispose() {
    var cameraController = CameraController();
    cameraController.scannedBarcodes.removeListener(_onCodesScanned);
    _controller?.dispose();
    super.dispose();
  }

  List<Barcode> _filteredCodes = [];

  /// Note: Not safe to call from build()
  void _filterCodes() {
    setState(() {
      final cameraController = CameraController();
      final analysisSize = cameraController.analysisSize;
      final previewSize = context.size;
      if (analysisSize != null && previewSize != null) {
        _filteredCodes = cameraController.scannedBarcodes.value
            .where(widget.rectOfInterest.buildCodeFilter(
              analysisSize: analysisSize,
              previewSize: previewSize,
            ))
            .toList();
      } else {
        _filteredCodes = [];
      }
    });
  }

  void _onCodesScanned() {
    _filterCodes();
    if (_filteredCodes.isEmpty) {
      _controller?.forward();
    } else {
      widget.onScan?.call(_filteredCodes);
      _controller?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.onScannedBoundaryColorSelector?.call(_filteredCodes) ??
            widget.cutOutBorderColor;
    final defaultBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 // strokeWidth is painted 50/50 outwards and inwards.
      ..color = borderColor;

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
                rectOfInterest: widget.rectOfInterest,
              ),
            ),
            if (widget.showSensing)
              AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) => CustomPaint(
                  foregroundPainter: MaterialFinderPainter(
                    inflate: _inflateSequence!.value,
                    opacity: _opacitySequence!.value,
                    sensingColor: widget.sensingColor,
                    borderPaint: sensingBorderPaint,
                    backgroundColor: widget.backgroundColor,
                    rectOfInterest: widget.rectOfInterest,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
