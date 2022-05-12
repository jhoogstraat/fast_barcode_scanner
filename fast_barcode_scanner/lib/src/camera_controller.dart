import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../fast_barcode_scanner.dart';

class ScannerState {
  PreviewConfiguration? _previewConfig;
  ScannerConfiguration? _scannerConfig;
  bool _torch = false;
  Object? _error;

  PreviewConfiguration? get previewConfig => _previewConfig;

  ScannerConfiguration? get scannerConfig => _scannerConfig;

  bool get torchState => _torch;

  bool get isInitialized => _previewConfig != null;

  bool get hasError => _error != null;

  Object? get error => _error;
}

/// Middleman, handling the communication with native platforms.
///
/// Allows for custom backends.
abstract class CameraController {
  static final _instance = _CameraController._internal();

  factory CameraController() => _instance;

  /// The cumulated state of the barcode scanner.
  ///
  /// Contains information about the configuration, torch,
  /// and errors
  final state = ScannerState();

  /// reports most recently scanned codes
  ValueNotifier<List<Barcode>> get scannedBarcodes;

  /// the size of the image used by the native analysis system to scan the code
  /// scanned codes have coordinate information that is based on this image size
  Size? get analysisSize;

  /// A [ValueNotifier] for camera state events.
  ///
  ///
  final ValueNotifier<ScannerEvent> events =
      ValueNotifier(ScannerEvent.uninitialized);

  /// Informs the platform to initialize the camera.
  ///
  /// Events and errors are received via the current state's eventNotifier.
  Future<void> initialize({
    required List<BarcodeType> types,
    required Resolution resolution,
    required Framerate framerate,
    required CameraPosition position,
    required DetectionMode detectionMode,
    IOSApiMode? apiMode,
    OnDetectionHandler? onScan,
  });

  /// Stops the camera and disposes all associated resources.
  ///
  ///
  Future<void> dispose();

  /// Resumes the preview on the platform level.
  ///
  ///
  Future<void> resumeCamera();

  /// Pauses the preview on the platform level.
  ///
  ///
  Future<void> pauseCamera();

  /// Resumes the scanner on the platform level.
  ///
  ///
  Future<void> resumeScanner();

  /// Pauses the scanner on the platform level.
  ///
  ///
  Future<void> pauseScanner();

  /// Toggles the torch, if available.
  ///
  ///
  Future<bool> toggleTorch();

  /// Reconfigure the scanner.
  ///
  /// Can be called while running.
  Future<void> configure({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  });

  /// Analyze a still image, which can be chosen from an image picker.
  ///
  /// It is recommended to pause the live scanner before calling this.
  Future<List<Barcode>?> scanImage(ImageSource source);
}

class _CameraController implements CameraController {
  _CameraController._internal() : super();

  StreamSubscription? _scanSilencerSubscription;

  final FastBarcodeScannerPlatform _platform =
      FastBarcodeScannerPlatform.instance;

  @override
  final state = ScannerState();

  @override
  final events = ValueNotifier(ScannerEvent.uninitialized);

  static const scannedCodeTimeout = Duration(milliseconds: 250);
  DateTime? _lastScanTime;
  @override
  ValueNotifier<List<Barcode>> scannedBarcodes = ValueNotifier([]);

  @override
  Size? get analysisSize {
    final previewConfig = state.previewConfig;
    if (previewConfig != null) {
      return Size(previewConfig.analysisWidth.toDouble(),
          previewConfig.analysisHeight.toDouble());
    }
    return null;
  }

  /// Indicates if the torch is currently switching.
  ///
  /// Used to prevent command-spamming.
  bool _togglingTorch = false;

  /// Indicates if the camera is currently configuring itself.
  ///
  /// Used to prevent command-spamming.
  bool _configuring = false;

  /// User-defined handler, called when a barcode is detected
  OnDetectionHandler? _onScan;

  /// Curried function for [_onScan]. This ensures that each scan receipt is done
  /// consistently. We log [_lastScanTime] and update the [scannedBarcodes] ValueNotifier
  OnDetectionHandler _buildScanHandler(OnDetectionHandler? onScan) {
    return (barcodes) {
      _lastScanTime = DateTime.now();
      scannedBarcodes.value = barcodes;
      onScan?.call(barcodes);
    };
  }

  @override
  Future<void> initialize({
    required List<BarcodeType> types,
    required Resolution resolution,
    required Framerate framerate,
    required CameraPosition position,
    required DetectionMode detectionMode,
    IOSApiMode? apiMode,
    OnDetectionHandler? onScan,
  }) async {
    try {
      state._previewConfig = await _platform.init(
        types,
        resolution,
        framerate,
        detectionMode,
        position,
        apiMode: apiMode,
      );

      _onScan = _buildScanHandler(onScan);
      _scanSilencerSubscription =
          Stream.periodic(scannedCodeTimeout).listen((event) {
        final scanTime = _lastScanTime;
        if (scanTime != null &&
            DateTime.now().difference(scanTime) > scannedCodeTimeout) {
          // it's been too long since we've seen a scanned code, clear the list
          scannedBarcodes.value = const <Barcode>[];
        }
      });

      _platform.setOnDetectHandler(_onDetectHandler);

      state._scannerConfig = ScannerConfiguration(
          types, resolution, framerate, position, detectionMode);

      state._error = null;

      events.value = ScannerEvent.resumed;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _platform.dispose();
      state._scannerConfig = null;
      state._previewConfig = null;
      state._torch = false;
      state._error = null;
      events.value = ScannerEvent.uninitialized;
      _scanSilencerSubscription?.cancel();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> pauseCamera() async {
    try {
      await _platform.stop();
      events.value = ScannerEvent.paused;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> resumeCamera() async {
    try {
      await _platform.start();
      events.value = ScannerEvent.resumed;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> pauseScanner() async {
    try {
      await _platform.stopDetector();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> resumeScanner() async {
    try {
      await _platform.startDetector();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<bool> toggleTorch() async {
    if (!_togglingTorch) {
      _togglingTorch = true;

      try {
        state._torch = await _platform.toggleTorch();
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _togglingTorch = false;
    }

    return state._torch;
  }

  @override
  Future<void> configure({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  }) async {
    if (state.isInitialized && !_configuring) {
      final _scannerConfig = state._scannerConfig!;
      _configuring = true;

      try {
        state._previewConfig = await _platform.changeConfiguration(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );

        state._scannerConfig = _scannerConfig.copyWith(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );

        _onScan = _buildScanHandler(onScan);
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _configuring = false;
    }
  }

  @override
  Future<List<Barcode>?> scanImage(ImageSource source) async {
    try {
      return _platform.scanImage(source);
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  void _onDetectHandler(List<Barcode> codes) {
    events.value = ScannerEvent.detected;
    _onScan?.call(codes);
  }
}

class ScannedBarcodes {
  final List<Barcode> barcodes;
  final DateTime scannedAt;

  ScannedBarcodes(this.barcodes) : scannedAt = DateTime.now();

  ScannedBarcodes.none() : this([]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedBarcodes &&
          runtimeType == other.runtimeType &&
          barcodes == other.barcodes &&
          scannedAt == other.scannedAt;

  @override
  int get hashCode => barcodes.hashCode ^ scannedAt.hashCode;
}
