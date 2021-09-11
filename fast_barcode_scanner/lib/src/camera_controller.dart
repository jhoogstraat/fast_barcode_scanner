import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../fast_barcode_scanner.dart';
import 'types/scanner_configuration.dart';

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
  /// errors and events.
  final state = ScannerState();

  /// A [ValueNotifier] for camera state events.
  ///
  ///
  final ValueNotifier<ScannerEvent> events =
      ValueNotifier(ScannerEvent.uninitialized);

  /// Informs the platform to initialize the camera.
  ///
  /// Events and errors are received via the current state's eventNotifier.
  Future<void> initialize(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    CameraPosition position,
    DetectionMode detectionMode,
    void Function(Barcode)? onScan,
  );

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
    void Function(Barcode)? onScan,
  });

  /// Analyze a still image, which can be chosen from an image picker.
  ///
  /// It is recommended to pause the live scanner before calling this.
  Future<List<Barcode>?> scanImage(ImageSource source);
}

class _CameraController implements CameraController {
  _CameraController._internal() : super();

  final FastBarcodeScannerPlatform _platform =
      FastBarcodeScannerPlatform.instance;

  @override
  final state = ScannerState();

  @override
  final events = ValueNotifier(ScannerEvent.uninitialized);

  /// Indicates if the torch is currently switching.
  ///
  /// Used to prevent command-spamming.
  bool _togglingTorch = false;

  /// Indicates if the camera is currently configuring itself.
  ///
  /// Used to prevent command-spamming.
  bool _configuring = false;

  /// User-defined handler, called when a barcode is detected
  void Function(Barcode)? _onScan;

  @override
  Future<void> initialize(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    CameraPosition position,
    DetectionMode detectionMode,
    void Function(Barcode)? onScan,
  ) async {
    try {
      state._previewConfig = await _platform.init(
          types, resolution, framerate, detectionMode, position);

      _onScan = onScan;

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
    void Function(Barcode)? onScan,
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

        if (onScan != null) {
          _onScan = onScan;
        }
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

  void _onDetectHandler(Barcode code) {
    events.value = ScannerEvent.detected;
    _onScan?.call(code);
  }
}
