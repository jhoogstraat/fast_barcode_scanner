import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'camera_controller.dart';
import 'types/scanner_event.dart';

/// Builder for rendering an error state inside [BarcodeCamera].
typedef ErrorCallback = Widget Function(BuildContext context, Object? error);

Widget _defaultOnError(BuildContext context, Object? error) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Center(
      child: Text(
        'Error:\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFFFFFFF)),
      ),
    ),
  );
}

/// A live camera preview widget with integrated native barcode scanning.
///
/// Automatically manages initialization, configuration updates, app lifecycle
/// pause/resume, orientation layout, optional pinch-to-zoom, and disposal.
class BarcodeCamera extends StatefulWidget {
  /// Creates a [BarcodeCamera].
  const BarcodeCamera({
    super.key,
    required this.types,
    this.mode = PerformanceMode.system,
    this.detectionMode = DetectionMode.pauseVideo,
    this.position = CameraPosition.back,
    this.api = const ApiMode(),
    this.onScan,
    this.children = const [],
    this.dispose = true,
    this.enablePinchToZoom = true,
    ErrorCallback? onError,
  }) : onError = onError ?? _defaultOnError;

  /// The barcode symbologies to detect.
  final List<BarcodeType> types;

  /// Camera performance/resolution preset.
  final PerformanceMode mode;

  /// How the scanner behaves after detecting a barcode.
  final DetectionMode detectionMode;

  /// Initial camera lens position.
  final CameraPosition position;

  /// Platform-specific native scanning API selection.
  final ApiMode api;

  /// Callback invoked when one or more barcodes are detected.
  final OnDetectionHandler? onScan;

  /// Overlay widgets stacked above the camera preview.
  final List<Widget> children;

  /// Builder displayed if camera initialization or scanning fails.
  final ErrorCallback onError;

  /// Whether to dispose the shared [CameraController] when this widget is
  /// removed from the tree. If `false`, the camera is only paused.
  final bool dispose;

  /// Enables pinch-to-zoom gestures on the camera preview.
  final bool enablePinchToZoom;

  @override
  BarcodeCameraState createState() => BarcodeCameraState();
}

class BarcodeCameraState extends State<BarcodeCamera>
    with WidgetsBindingObserver {
  double _opacity = 0.0;
  double _baseZoom = 1.0;
  bool _pausedByLifecycle = false;

  final CameraController cameraController = CameraController.shared;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initOrConfigure();
  }

  void _initOrConfigure() {
    final Future<void> future = cameraController.state.value.isInitialized
        ? cameraController.configure(
            types: widget.types,
            mode: widget.mode,
            detectionMode: widget.detectionMode,
            position: widget.position,
            onScan: widget.onScan,
          )
        : cameraController.initialize(
            types: widget.types,
            mode: widget.mode,
            position: widget.position,
            detectionMode: widget.detectionMode,
            onScan: widget.onScan,
            api: widget.api,
          );

    future.then<void>(
      (_) {
        if (mounted) {
          setState(() => _opacity = 1.0);
        }
      },
      onError: (_, __) {
        if (mounted) {
          setState(() => _opacity = 1.0);
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant BarcodeCamera oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!cameraController.state.value.isInitialized) return;

    final configChanged = !listEquals(oldWidget.types, widget.types) ||
        oldWidget.mode != widget.mode ||
        oldWidget.detectionMode != widget.detectionMode ||
        oldWidget.position != widget.position ||
        oldWidget.onScan != widget.onScan;

    if (configChanged) {
      cameraController
          .configure(
            types: widget.types,
            mode: widget.mode,
            detectionMode: widget.detectionMode,
            position: widget.position,
            onScan: widget.onScan,
          )
          .catchError((_) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!cameraController.state.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (cameraController.eventNotifier.value == ScannerEvent.resumed) {
          _pausedByLifecycle = true;
          cameraController.pauseCamera().catchError((_) {});
        }
        break;
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          cameraController.resumeCamera().catchError((_) {});
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.dispose) {
      cameraController.dispose().catchError((_) {});
    } else {
      cameraController.pauseCamera().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: ValueListenableBuilder<ScannerState>(
        valueListenable: cameraController.state,
        builder: (context, cameraState, _) {
          return AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 250),
            child: cameraState.hasError
                ? widget.onError(
                    context,
                    cameraState.error ?? 'Unknown error occurred',
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: widget.enablePinchToZoom
                        ? (_) {
                            _baseZoom = cameraController.state.value.zoom;
                          }
                        : null,
                    onScaleUpdate: widget.enablePinchToZoom
                        ? (details) {
                            if (details.pointerCount < 2) return;
                            cameraController
                                .setZoom(_baseZoom * details.scale)
                                .catchError((_) => _baseZoom);
                          }
                        : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cameraState.isInitialized)
                          _CameraPreview(
                            cameraInformation: cameraState.cameraInformation!,
                          ),
                        ...widget.children,
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.cameraInformation});

  final CameraInformation cameraInformation;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final rawSize = cameraInformation.videoSize;
        final isPortrait = orientation == Orientation.portrait;

        // Native video buffers are typically landscape (width > height).
        // Swap dimensions in portrait mode so BoxFit.cover preserves aspect ratio.
        final double previewWidth;
        final double previewHeight;
        if (isPortrait && rawSize.width > rawSize.height) {
          previewWidth = rawSize.height;
          previewHeight = rawSize.width;
        } else if (!isPortrait && rawSize.height > rawSize.width) {
          previewWidth = rawSize.height;
          previewHeight = rawSize.width;
        } else {
          previewWidth = rawSize.width;
          previewHeight = rawSize.height;
        }

        final Widget nativePreview;
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final textureId = cameraInformation.textureId;
            if (textureId != null) {
              nativePreview = Texture(
                textureId: textureId,
                filterQuality: FilterQuality.low,
              );
            } else {
              nativePreview = const AndroidView(
                viewType: 'fast_barcode_scanner.preview',
                creationParamsCodec: StandardMessageCodec(),
              );
            }
          case TargetPlatform.iOS:
            // On iOS, PreviewView uses AVCaptureVideoPreviewLayer with
            // videoGravity = .resizeAspectFill, so filling the parent directly
            // avoids double-scaling across portrait/landscape rotations.
            return const UiKitView(
              viewType: 'fast_barcode_scanner.preview',
              creationParamsCodec: StandardMessageCodec(),
            );
          default:
            throw UnsupportedError(
              'fast_barcode_scanner is only supported on iOS and Android.',
            );
        }

        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: nativePreview,
          ),
        );
      },
    );
  }
}
