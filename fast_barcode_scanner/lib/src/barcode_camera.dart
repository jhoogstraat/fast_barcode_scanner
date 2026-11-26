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

  final List<BarcodeType> types;
  final PerformanceMode mode;
  final DetectionMode detectionMode;
  final CameraPosition position;
  final ApiMode api;
  final OnDetectionHandler? onScan;
  final List<Widget> children;
  final ErrorCallback onError;
  final bool dispose;
  final bool enablePinchToZoom;

  @override
  BarcodeCameraState createState() => BarcodeCameraState();
}

class BarcodeCameraState extends State<BarcodeCamera>
    with WidgetsBindingObserver {
  final Object _ownerToken = Object();
  double _opacity = 0.0;
  double _baseZoom = 1.0;
  bool _pausedByLifecycle = false;

  final CameraController cameraController = CameraController.shared;

  @override
  void initState() {
    super.initState();
    cameraController.attachOwner(_ownerToken);
    WidgetsBinding.instance.addObserver(this);
    _initOrConfigure();
  }

  void _initOrConfigure() {
    Future<void> future;
    if (cameraController.state.value.isInitialized) {
      cameraController.setOnScan(widget.onScan);
      future = cameraController.configure(
        types: widget.types,
        mode: widget.mode,
        detectionMode: widget.detectionMode,
        position: widget.position,
      );
      if (cameraController.eventNotifier.value == ScannerEvent.paused) {
        future = future.then((_) => cameraController.resumeCamera());
      }
    } else {
      future = cameraController.initialize(
        types: widget.types,
        mode: widget.mode,
        position: widget.position,
        detectionMode: widget.detectionMode,
        onScan: widget.onScan,
        api: widget.api,
      );
    }

    future.whenComplete(() {
      if (mounted && _opacity != 1.0) {
        setState(() => _opacity = 1.0);
      }
    }).catchError((_) {});
  }

  @override
  void didUpdateWidget(covariant BarcodeCamera oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.onScan != widget.onScan) {
      cameraController.setOnScan(widget.onScan);
    }

    final nativeConfigChanged = !listEquals(oldWidget.types, widget.types) ||
        oldWidget.mode != widget.mode ||
        oldWidget.detectionMode != widget.detectionMode ||
        oldWidget.position != widget.position;

    if (nativeConfigChanged) {
      cameraController
          .configure(
            types: widget.types,
            mode: widget.mode,
            detectionMode: widget.detectionMode,
            position: widget.position,
          )
          .catchError((_) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!cameraController.state.value.isInitialized ||
        !cameraController.isOwner(_ownerToken)) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        final event = cameraController.eventNotifier.value;
        if (event != ScannerEvent.paused &&
            event != ScannerEvent.uninitialized &&
            event != ScannerEvent.error) {
          _pausedByLifecycle = true;
          cameraController.pauseCamera().catchError((_) {});
        }
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          cameraController.resumeCamera().catchError((_) {});
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (cameraController.isOwner(_ownerToken)) {
      if (widget.dispose) {
        cameraController.dispose().catchError((_) {});
      } else {
        cameraController.pauseCamera().catchError((_) {});
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: widget.enablePinchToZoom
              ? (_) => _baseZoom = cameraController.state.value.zoom
              : null,
          onScaleUpdate: widget.enablePinchToZoom
              ? (details) {
                  if (details.pointerCount < 2) return;
                  cameraController
                      .setZoom(_baseZoom * details.scale)
                      .catchError((_) => _baseZoom);
                }
              : null,
          child: ValueListenableBuilder<ScannerState>(
            valueListenable: cameraController.state,
            child: Stack(fit: StackFit.expand, children: widget.children),
            builder: (context, cameraState, overlays) {
              if (cameraState.hasError) {
                return widget.onError(
                  context,
                  cameraState.error ?? 'Unknown error occurred',
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraState.isInitialized)
                    _CameraPreview(
                      cameraInformation: cameraState.cameraInformation!,
                    ),
                  overlays!,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.cameraInformation});

  final CameraInformation cameraInformation;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // PreviewView uses AVCaptureVideoPreviewLayer with .resizeAspectFill.
      return const UiKitView(
        viewType: 'fast_barcode_scanner.preview',
        creationParamsCodec: StandardMessageCodec(),
      );
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'fast_barcode_scanner is only supported on iOS and Android.',
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        final rawSize = cameraInformation.videoSize;
        final isPortrait = orientation == Orientation.portrait;
        final size = (isPortrait == (rawSize.width > rawSize.height))
            ? rawSize.flipped
            : rawSize;

        final textureId = cameraInformation.textureId;
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: textureId != null
                ? Texture(
                    textureId: textureId, filterQuality: FilterQuality.low)
                : const AndroidView(
                    viewType: 'fast_barcode_scanner.preview',
                    creationParamsCodec: StandardMessageCodec(),
                  ),
          ),
        );
      },
    );
  }
}
