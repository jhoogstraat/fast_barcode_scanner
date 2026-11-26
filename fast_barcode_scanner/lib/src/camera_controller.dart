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
  const ScannerState.uninitialized() : this();

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
  ScannerState withError(Object error) => ScannerState(error: error);

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
class CameraController {
  CameraController._internal();

  /// Creates an isolated [CameraController] instance for unit testing.
  @visibleForTesting
  CameraController.forTesting();

  /// Shared singleton controller used by [BarcodeCamera] and built-in overlays.
  static final CameraController shared = CameraController._internal();

  FastBarcodeScannerPlatform get _platform =>
      FastBarcodeScannerPlatform.instance;

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

  Timer? _scanSilencerTimer;
  Future<void> _opQueue = Future<void>.value();
  int _generation = 0;
  int _zoomRequestId = 0;
  Object? _ownerToken;
  OnDetectionHandler? _onScan;

  /// Claims widget ownership of this controller so overlapping route
  /// transitions do not let a departing widget dispose a newly mounted one.
  void attachOwner(Object token) => _ownerToken = token;

  /// Returns `true` if [token] is the active owner (or no owner is attached).
  bool isOwner(Object token) => _ownerToken == null || _ownerToken == token;

  /// Updates the detection callback without invoking any native reconfiguration.
  void setOnScan(OnDetectionHandler? onScan) {
    _onScan = onScan;
  }

  /// Serializes mutating platform calls so concurrent requests (e.g. torch +
  /// configure) never drop or race each other.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _opQueue = _opQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<T> _runGuarded<T>(int gen, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (gen == _generation) {
        state.value = state.value.withError(error);
        eventNotifier.value = ScannerEvent.error;
      }
      rethrow;
    }
  }

  Future<void> _setEvent(
    Future<void> Function() action,
    ScannerEvent nextEvent,
  ) {
    final gen = _generation;
    return _enqueue(() async {
      if (gen != _generation || !state.value.isInitialized) return;
      await _runGuarded(gen, () async {
        await action();
        if (gen == _generation) {
          if (nextEvent == ScannerEvent.paused) _clearResults();
          eventNotifier.value = nextEvent;
        }
      });
    });
  }

  void _clearResults() {
    _scanSilencerTimer?.cancel();
    _scanSilencerTimer = null;
    if (resultNotifier.value.isNotEmpty) {
      resultNotifier.value = const <Barcode>[];
    }
  }

  /// Initializes and starts the camera and barcode scanner.
  Future<void> initialize({
    required List<BarcodeType> types,
    required PerformanceMode mode,
    required CameraPosition position,
    required DetectionMode detectionMode,
    required ApiMode api,
    OnDetectionHandler? onScan,
  }) {
    final gen = ++_generation;
    _onScan = onScan;
    return _enqueue(() => _runGuarded(gen, () async {
          final cameraInfo = await _platform.init(
            types,
            mode,
            detectionMode,
            position,
            api,
          );
          if (gen != _generation) return;

          _platform.setOnDetectionHandler(_onDetectHandler);

          state.value = ScannerState(
            cameraInformation: cameraInfo,
            scannerConfig:
                ScannerConfiguration(types, mode, position, detectionMode),
            torch: false,
            zoom: cameraInfo.minZoom,
          );
          eventNotifier.value = ScannerEvent.resumed;
        }));
  }

  /// Stops the camera and releases all native resources.
  Future<void> dispose() {
    final gen = ++_generation;
    _clearResults();
    _onScan = null;
    return _enqueue(() => _runGuarded(gen, () async {
          await _platform.dispose();
          if (gen == _generation) {
            state.value = const ScannerState.uninitialized();
            eventNotifier.value = ScannerEvent.uninitialized;
          }
        }));
  }

  /// Pauses both the camera preview and barcode detector.
  Future<void> pauseCamera() => _setEvent(_platform.stop, ScannerEvent.paused);

  /// Resumes the camera preview and barcode detector.
  Future<void> resumeCamera() =>
      _setEvent(_platform.start, ScannerEvent.resumed);

  /// Pauses barcode detection while keeping the camera preview active.
  Future<void> pauseScanner() =>
      _setEvent(_platform.stopDetector, ScannerEvent.paused);

  /// Resumes barcode detection while the camera preview is active.
  Future<void> resumeScanner() =>
      _setEvent(_platform.startDetector, ScannerEvent.resumed);

  /// Toggles the camera torch and returns the new state (`true` = on).
  Future<bool> toggleTorch() {
    final gen = _generation;
    return _enqueue(() async {
      if (gen != _generation || !state.value.isInitialized) {
        return state.value.torch;
      }
      return _runGuarded(gen, () async {
        final torchState = await _platform.toggleTorch();
        if (gen == _generation) {
          state.value = state.value.withTorch(torchState);
        }
        return torchState;
      });
    });
  }

  /// Sets the camera zoom factor, clamped to the device's supported range.
  Future<double> setZoom(double zoomFactor) async {
    final gen = _generation;
    final info = state.value.cameraInformation;
    if (!state.value.isInitialized || info == null) {
      return state.value.zoom;
    }

    final maxZoom = info.maxZoom < info.minZoom ? info.minZoom : info.maxZoom;
    final clamped = zoomFactor.clamp(info.minZoom, maxZoom);
    final reqId = ++_zoomRequestId;

    final applied = await _platform.setZoom(clamped);
    if (gen == _generation && reqId == _zoomRequestId) {
      state.value = state.value.withZoom(applied);
    }
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
    await configure(
      position: currentPosition == CameraPosition.back
          ? CameraPosition.front
          : CameraPosition.back,
    );
  }

  /// Dynamically updates one or more scanner configuration parameters.
  Future<void> configure({
    List<BarcodeType>? types,
    PerformanceMode? mode,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  }) {
    if (onScan != null) _onScan = onScan;
    final gen = _generation;
    return _enqueue(() async {
      if (gen != _generation || !state.value.isInitialized) return;
      final scannerConfig = state.value.scannerConfig!;

      await _runGuarded(gen, () async {
        final cameraInfo = await _platform.changeConfiguration(
          types: types,
          mode: mode,
          detectionMode: detectionMode,
          position: position,
        );
        if (gen != _generation) return;

        state.value = ScannerState(
          cameraInformation: cameraInfo,
          scannerConfig: scannerConfig.copyWith(
            types: types,
            mode: mode,
            detectionMode: detectionMode,
            position: position,
          ),
          torch: state.value.torch,
          zoom: cameraInfo.minZoom,
        );
      });
    });
  }

  /// Scans a still image from [source] independently of the live camera.
  Future<List<Barcode>?> scanImage(ImageSource source) =>
      _platform.scanImage(source);

  void _onDetectHandler(List<Barcode> codes) {
    _scanSilencerTimer?.cancel();
    _scanSilencerTimer = Timer(scannedCodeTimeout, () {
      if (resultNotifier.value.isNotEmpty) {
        resultNotifier.value = const <Barcode>[];
      }
    });
    resultNotifier.value = codes;
    eventNotifier.value = ScannerEvent.detected;
    _onScan?.call(codes);
  }
}
