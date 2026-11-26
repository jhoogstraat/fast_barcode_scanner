import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/widgets.dart';

import 'material_finder_painter.dart';

/// Mimics the Material Design Barcode Scanner viewfinder overlay.
class MaterialPreviewOverlay extends StatefulWidget {
  /// Creates a Material barcode finder overlay.
  const MaterialPreviewOverlay({
    super.key,
    required this.rectOfInterest,
    this.showSensing = false,
    this.sensingColor = const Color(0xFFFFFFFF),
    this.backgroundColor = const Color(0x61000000),
    this.cutOutBorderColor = const Color(0xDD000000),
    this.onScan,
    this.onScannedBoundsColor,
  });

  final bool showSensing;
  final Color? backgroundColor;
  final Color sensingColor;
  final Color cutOutBorderColor;
  final Color? Function(List<Barcode> scannedCodes)? onScannedBoundsColor;
  final RectOfInterest rectOfInterest;
  final OnDetectionHandler? onScan;

  @override
  State<MaterialPreviewOverlay> createState() => MaterialPreviewOverlayState();
}

class MaterialPreviewOverlayState extends State<MaterialPreviewOverlay>
    with SingleTickerProviderStateMixin {
  List<Barcode> _filteredCodes = const [];

  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _inflateAnimation;

  @override
  void initState() {
    super.initState();

    const fadeIn = 20.0;
    const wait = 2.0;
    const expand = 25.0;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    final opacitySequence = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: fadeIn),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: wait),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: expand,
      ),
    ]);

    final inflateSequence = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: fadeIn + wait),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: expand,
      ),
    ]);

    _opacityAnimation = opacitySequence.animate(_controller);
    _inflateAnimation = inflateSequence.animate(_controller);

    _controller.addStatusListener((status) {
      if (widget.showSensing &&
          status == AnimationStatus.completed &&
          _filteredCodes.isEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || !widget.showSensing) return;
          _controller.forward(from: _controller.lowerBound);
        });
      }
    });

    if (widget.showSensing) {
      _controller.forward();
    }

    CameraController.shared.resultNotifier.addListener(_onCodesScanned);
  }

  @override
  void didUpdateWidget(covariant MaterialPreviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSensing && !oldWidget.showSensing) {
      _controller.forward(from: _controller.lowerBound);
    } else if (!widget.showSensing && oldWidget.showSensing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    CameraController.shared.resultNotifier.removeListener(_onCodesScanned);
    _controller.dispose();
    super.dispose();
  }

  void _onCodesScanned() {
    if (!mounted) return;
    final cameraInfo = CameraController.shared.state.value.cameraInformation;
    final analysisSize =
        cameraInfo?.analysisFrame.size ?? cameraInfo?.videoSize;
    final previewSize = context.size;

    setState(() {
      if (analysisSize != null && previewSize != null) {
        _filteredCodes = widget.rectOfInterest.filterCodes(
          codes: CameraController.shared.resultNotifier.value,
          analysisSize: analysisSize,
          previewSize: previewSize,
        );
      } else {
        _filteredCodes = const [];
      }
    });

    if (_filteredCodes.isEmpty) {
      if (widget.showSensing) {
        _controller.forward();
      }
    } else {
      widget.onScan?.call(_filteredCodes);
      if (widget.showSensing) {
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.onScannedBoundsColor?.call(_filteredCodes) ??
        widget.cutOutBorderColor;

    final defaultBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = borderColor;

    final sensingBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

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
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  foregroundPainter: MaterialFinderPainter(
                    inflate: _inflateAnimation.value,
                    opacity: _opacityAnimation.value,
                    sensingColor: widget.sensingColor,
                    borderPaint: sensingBorderPaint,
                    backgroundColor: null,
                    rectOfInterest: widget.rectOfInterest,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
