import 'dart:async';

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
  Timer? _restartTimer;

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

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: fadeIn),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: wait),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: expand,
      ),
    ]).animate(_controller);

    _inflateAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: fadeIn + wait),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: expand,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (widget.showSensing &&
          status == AnimationStatus.completed &&
          _filteredCodes.isEmpty) {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && widget.showSensing && _filteredCodes.isEmpty) {
            _controller.forward(from: _controller.lowerBound);
          }
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
      _restartTimer?.cancel();
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    CameraController.shared.resultNotifier.removeListener(_onCodesScanned);
    _controller.dispose();
    super.dispose();
  }

  void _onCodesScanned() {
    if (!mounted) return;
    final cameraInfo = CameraController.shared.state.value.cameraInformation;
    final analysisSize =
        cameraInfo?.analysisFrame.size ?? cameraInfo?.videoSize;
    final ro = context.findRenderObject();
    final previewSize = ro is RenderBox && ro.hasSize ? ro.size : null;

    final nextCodes = analysisSize != null && previewSize != null
        ? widget.rectOfInterest.filterCodes(
            codes: CameraController.shared.resultNotifier.value,
            analysisSize: analysisSize,
            previewSize: previewSize,
          )
        : const <Barcode>[];

    setState(() => _filteredCodes = nextCodes);

    if (nextCodes.isEmpty) {
      if (widget.showSensing && !_controller.isAnimating) {
        _controller.forward();
      }
    } else {
      _restartTimer?.cancel();
      widget.onScan?.call(nextCodes);
      if (widget.showSensing) {
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.onScannedBoundsColor?.call(_filteredCodes) ??
        widget.cutOutBorderColor;

    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: MaterialFinderPainter(
            borderColor: borderColor,
            backgroundColor: widget.backgroundColor,
            rectOfInterest: widget.rectOfInterest,
          ),
          foregroundPainter: widget.showSensing
              ? MaterialFinderPainter(
                  borderColor: widget.sensingColor,
                  rectOfInterest: widget.rectOfInterest,
                  inflateAnimation: _inflateAnimation,
                  opacityAnimation: _opacityAnimation,
                )
              : null,
        ),
      ),
    );
  }
}
