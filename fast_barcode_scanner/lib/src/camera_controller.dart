import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';

import 'types/scanner_configuration.dart';
import 'types/scanner_event.dart';

/// Immutable snapshot of the scanner's current state.
@immutable
class ScannerState {
  /// Creates a [ScannerState].
  const ScannerState({
    this.cameraInformation,
    this.scannerConfig,
    this.torch = false,
    this.zoom = 1.0,
    this.error,
  });

  /// Initial state before [CameraController.initialize] has completed.
  const ScannerState.uninitialized()
      : cameraInformation = null,
        scannerConfig = null,
        torch = false,
        zoom = 1.0,
        error = null;

  /// Metadata about the active camera stream, or `null` if uninitialized.
  final CameraInformation? cameraInformation;

  /// Current scanner configuration, or `null` if uninitialized.
  final ScannerConfiguration? scannerConfig;

  /// Whether the camera torch (flashlight) is currently enabled.
  final bool torch;

  /// Current camera zoom factor.
  final double zoom;

  /// Most recent error encountered by the controller, if any.
  final Object? error;

  /// Whether the camera and scanner have been initialized.
  bool get isInitialized => scannerConfig != null && cameraInformation != null;

  /// Whether the scanner is currently in an error state.
  bool get hasError => error != null;

  /// Returns a copy of this state with the torch state updated.
  ScannerState withTorch(bool active) => ScannerState(
        cameraInformation: cameraInformation,
        scannerConfig: scannerConfig,
        torch: active,
        zoom: zoom,
        error: error,
      );

  /// Returns a copy of this state with the zoom factor updated.
  ScannerState withZoom(double factor) => ScannerState(
        cameraInformation: cameraInformation,
        scannerConfig: scannerConfig,
        torch: torch,
        zoom: factor,
        error: error,
      );

  /// Returns a state carrying the given [error].
  ScannerState withError(Object error) => ScannerState(
        cameraInformation: null,
        scannerConfig: null,
        torch: false,
        zoom: 1.0,
        error: error,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannerState &&
          runtimeType == other.runtimeType &&
          cameraInformation == other.cameraInformation &&
          scannerConfig == other.scannerConfig &&
          torch == other.torch &&
          zoom == other.zoom &&
          error == other.error;

  @override
  int get hashCode =>
      Object.hash(cameraInformation, scannerConfig, torch, zoom, error);
}

/// High-level controller managing the native camera lifecycle, scanner
/// configuration, torch, zoom, and barcode detection events.
///
/// Use [CameraController.shared] for typical single-camera apps, or interact
/// directly with [FastBarcodeScannerPlatform.instance] for custom flows.
class CameraController {
  CameraController._internal();

  /// Creates an isolated [CameraController] instance for unit testing.
  @visibleForTesting
  CameraController.forTesting();

  /// Shared singleton controller used by [BarcodeCamera] and built-in overlays.
  static final CameraController shared = CameraController._internal();

  FastBarcodeScannerPlatform get _platform =>
      FastBarcodeScannerPlatform.instance;

  StreamSubscription<void>? _scanSilencerSubscription;
  DateTime? _lastScanTime;

  /// Notifies listeners whenever the camera state changes.
  final ValueNotifier<ScannerState> state =
      ValueNotifier(const ScannerState.uninitialized());

  /// Notifies listeners with the latest barcodes detected in the current frame.
  ///
  /// Automatically clears after [scannedCodeTimeout] when no codes are seen.
  final ValueNotifier<List<Barcode>> resultNotifier =
      ValueNotifier(const <Barcode>[]);

  /// Notifies listeners of high-level [ScannerEvent] transitions.
  final ValueNotifier<ScannerEvent> eventNotifier =
      ValueNotifier(ScannerEvent.uninitialized);

  /// Duration after which [resultNotifier] is cleared when no new barcodes
  /// are reported.
  static const Duration scannedCodeTimeout = Duration(milliseconds: 250);

  bool _isConfiguringLock = false;
  OnDetectionHandler? _onScan;

  OnDetectionHandler _buildScanHandler(OnDetectionHandler? onScan) {
    return (barcodes) {
      _lastScanTime = DateTime.now();
      resultNotifier.value = barcodes;
      onScan?.call(barcodes);
    };
  }

  /// Initializes and starts the camera and barcode scanner.
  Future<void> initialize({
    required List<BarcodeType> types,
    required PerformanceMode mode,
    required CameraPosition position,
    required DetectionMode detectionMode,
    required ApiMode api,
    OnDetectionHandler? onScan,
  }) async {
    try {
      final cameraInfo = await _platform.init(
        types,
        mode,
        detectionMode,
        position,
        api,
      );

      _onScan = _buildScanHandler(onScan);

      await _scanSilencerSubscription?.cancel();
      _scanSilencerSubscription =
          Stream<void>.periodic(scannedCodeTimeout).listen((_) {
        final scanTime = _lastScanTime;
        if (scanTime != null &&
            DateTime.now().difference(scanTime) > scannedCodeTimeout &&
            resultNotifier.value.isNotEmpty) {
          resultNotifier.value = const <Barcode>[];
        }
      });

      _platform.setOnDetectionHandler(_onDetectHandler);

      final scanner =
          ScannerConfiguration(types, mode, position, detectionMode);

      state.value = ScannerState(
        cameraInformation: cameraInfo,
        scannerConfig: scanner,
        torch: false,
        zoom: cameraInfo.minZoom,
      );
      eventNotifier.value = ScannerEvent.resumed;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    }
  }

  /// Stops the camera and releases all native resources.
  Future<void> dispose() async {
    await _scanSilencerSubscription?.cancel();
    _scanSilencerSubscription = null;
    _lastScanTime = null;
    _onScan = null;
    resultNotifier.value = const <Barcode>[];

    try {
      await _platform.dispose();
      state.value = const ScannerState.uninitialized();
      eventNotifier.value = ScannerEvent.uninitialized;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    }
  }

  /// Pauses both the camera preview and barcode detector.
  Future<void> pauseCamera() async {
    if (!state.value.isInitialized) return;
    try {
      await _platform.stop();
      eventNotifier.value = ScannerEvent.paused;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    }
  }

  /// Resumes the camera preview and barcode detector.
  Future<void> resumeCamera() async {
    if (!state.value.isInitialized) return;
    try {
      await _platform.start();
      eventNotifier.value = ScannerEvent.resumed;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    }
  }

  /// Pauses barcode detection while keeping the camera preview active.
  Future<void> pauseScanner() async {
    if (!state.value.isInitialized) return;
    try {
      await _platform.stopDetector();
      eventNotifier.value = ScannerEvent.paused;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    }
  }

  /// Resumes barcode detection while the camera preview is active.
  Future<void> resumeScanner() async {
    if (!state.value.isInitialized) return;
    try {
      await _platform.startDetector();
      eventNotifier.value = ScannerEvent.resumed;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    }
  }

  /// Toggles the camera torch and returns the new state (`true` = on).
  Future<bool> toggleTorch() async {
    if (!state.value.isInitialized || _isConfiguringLock) {
      return state.value.torch;
    }

    _isConfiguringLock = true;
    try {
      final torchState = await _platform.toggleTorch();
      state.value = state.value.withTorch(torchState);
      return torchState;
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    } finally {
      _isConfiguringLock = false;
    }
  }

  /// Sets the camera zoom factor, clamped to the device's supported range.
  Future<double> setZoom(double zoomFactor) async {
    final info = state.value.cameraInformation;
    if (!state.value.isInitialized || info == null) {
      return state.value.zoom;
    }

    final clamped = zoomFactor.clamp(info.minZoom, info.maxZoom);
    final applied = await _platform.setZoom(clamped);
    state.value = state.value.withZoom(applied);
    return applied;
  }

  /// Returns `true` if the device has both front and back cameras available.
  Future<bool> canSwitchCamera() async {
    if (!state.value.isInitialized) return false;
    return _platform.canSwitchCamera();
  }

  /// Convenience method that toggles between [CameraPosition.back] and
  /// [CameraPosition.front].
  Future<void> switchCamera() async {
    final currentPosition = state.value.scannerConfig?.position;
    if (currentPosition == null) return;
    final nextPosition = currentPosition == CameraPosition.back
        ? CameraPosition.front
        : CameraPosition.back;
    await configure(position: nextPosition);
  }

  /// Dynamically updates one or more scanner configuration parameters.
  Future<void> configure({
    List<BarcodeType>? types,
    PerformanceMode? mode,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  }) async {
    if (!state.value.isInitialized || _isConfiguringLock) return;

    _isConfiguringLock = true;
    final scannerConfig = state.value.scannerConfig!;

    try {
      final cameraInfo = await _platform.changeConfiguration(
        types: types,
        mode: mode,
        detectionMode: detectionMode,
        position: position,
      );

      final updatedConfig = scannerConfig.copyWith(
        types: types,
        mode: mode,
        detectionMode: detectionMode,
        position: position,
      );

      if (onScan != null) {
        _onScan = _buildScanHandler(onScan);
      }

      state.value = ScannerState(
        cameraInformation: cameraInfo,
        scannerConfig: updatedConfig,
        torch: state.value.torch,
        zoom: cameraInfo.minZoom,
      );
    } catch (error) {
      state.value = state.value.withError(error);
      eventNotifier.value = ScannerEvent.error;
      rethrow;
    } finally {
      _isConfiguringLock = false;
    }
  }

  /// Scans a still image from [source] independently of the live camera.
  ///
  /// Returns `null` if the user cancelled the native image picker, or the list
  /// of detected [Barcode]s.
  Future<List<Barcode>?> scanImage(ImageSource source) {
    return _platform.scanImage(source);
  }

  void _onDetectHandler(List<Barcode> codes) {
    eventNotifier.value = ScannerEvent.detected;
    _onScan?.call(codes);
  }
}
