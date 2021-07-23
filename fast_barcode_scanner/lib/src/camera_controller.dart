import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'types/scanner_configuration.dart';
import 'types/scanner_event.dart';

class CameraState {
  PreviewConfiguration? _previewConfig;
  ScannerConfiguration? _scannerConfig;
  bool _torchState = false;
  Object? _error;

  PreviewConfiguration? get previewConfig => _previewConfig;
  ScannerConfiguration? get scannerConfig => _scannerConfig;
  bool get torchState => _torchState;
  bool get isInitialized => _previewConfig != null;
  bool get hasError => _error != null;
  Object? get error => _error;
}

abstract class CameraController {
  static final _instance = _CameraController._internal();

  factory CameraController() => _instance;

  /// The cumulated state of the barcode scanner.
  ///
  /// Contains information about the configuration, torch,
  /// errors and events.
  final state = CameraState();

  /// A [ValueNotifier] for camera events.
  ///
  ///
  final ValueNotifier<ScannerEvent> events =
      ValueNotifier(ScannerEvent.uninitialized);

  /// Informs the platform to initialize the camera.
  ///
  /// The camera is disposed and reinitialized when calling this
  /// method repeatedly.
  /// Events and errors are received via the current state's eventNotifier.
  Future<void> initialize(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    CameraPosition position,
    DetectionMode detectionMode,
    void Function(Barcode)? onScan,
  );

  /// Disposed the platform camera and resets the whole system.
  ///
  ///
  // Future<void> dispose();

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
  }) {
    throw UnimplementedError();
  }

  /// Analyze a still image, which can be chosen from an image picker.
  ///
  /// It is recommended to pause the live scanner before calling this.
  Future<List<Barcode>> scanImage(ImageSource source);
}

class _CameraController implements CameraController {
  _CameraController._internal() : super();

  final FastBarcodeScannerPlatform _platform =
      FastBarcodeScannerPlatform.instance;

  @override
  final state = CameraState();

  @override
  final events = ValueNotifier(ScannerEvent.uninitialized);

  bool _togglingTorch = false;
  bool _configuring = false;

  @override
  Future<void> initialize(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    CameraPosition position,
    DetectionMode detectionMode,
    void Function(Barcode)? onScan,
  ) async {
    events.value = ScannerEvent.init;

    try {
      state._previewConfig = await _platform.init(
          types, resolution, framerate, detectionMode, position);

      _platform.setOnDetectHandler((code) {
        events.value = ScannerEvent.codeFound;
        onScan?.call(code);
      });

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

  // @override
  // Future<void> dispose() async {
  //   try {
  //     await _platform.dispose();
  //     state._scannerConfig = null;
  //     state._previewConfig = null;
  //     events.value = ScannerEvent.uninitialized;
  //   } catch (error) {
  //     state._error = error;
  //     events.value = ScannerEvent.error;
  //     rethrow;
  //   }
  // }

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
        state._torchState = await _platform.toggleTorch();
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _togglingTorch = false;
    }

    return state._torchState;
  }

  @override
  Future<void> configure({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
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
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _configuring = false;
    }
  }

  @override
  Future<List<Barcode>> scanImage(ImageSource source) async {
    try {
      return _platform.scanImage(source);
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }
}
