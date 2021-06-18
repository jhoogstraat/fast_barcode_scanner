import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class CameraConfiguration {
  const CameraConfiguration(this.types, this.resolution, this.framerate,
      this.detectionMode, this.position);

  /// The types the scanner should look out for.
  ///
  /// If a barcode type is not in this list, it will not be detected.
  final List<BarcodeType> types;

  /// The target resolution of the camera feed.
  ///
  /// This is experimental, but functional. Should not be set higher
  /// than necessary.
  final Resolution resolution;

  /// The target framerate of the camera feed.
  ///
  /// This is experimental, but functional on iOS. Should not be set higher
  /// than necessary.
  final Framerate framerate;

  /// Determines how the camera reacts to detected barcodes.
  final DetectionMode detectionMode;

  /// The physical position of the camera being used.
  final CameraPosition position;
}

enum CameraEvent { uninitialized, init, paused, resumed, codeFound, error }

class CameraState {
  PreviewConfiguration? _previewConfig;
  bool _torchState = false;
  bool _togglingTorch = false;
  Object? _error;

  Object? get error => _error;
  PreviewConfiguration? get previewConfig => _previewConfig;

  final eventNotifier = ValueNotifier(CameraEvent.uninitialized);

  bool get torchState => _torchState;
  bool get isInitialized => _previewConfig != null;
  bool get hasError => error != null;
}

class CameraController {
  CameraController._() : this.state = CameraState();

  static final _instance = CameraController._();
  static CameraController get instance => _instance;

  /// The cumulated state of the barcode scanner.
  ///
  /// Contains information about the configuration, torch,
  /// errors and events.
  final CameraState state;

  FastBarcodeScannerPlatform get _platform =>
      FastBarcodeScannerPlatform.instance;

  // Intents

  /// Informs the platform to initialize the camera.
  ///
  /// The camera is disposed and reinitialized when calling this
  /// method repeatedly.
  /// Events and errors are received via the current state's eventNotifier.
  Future<void> initialize(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position,
      void Function(Barcode)? onScan) async {
    state.eventNotifier.value = CameraEvent.init;

    try {
      if (state.isInitialized) await _platform.dispose();
      state._previewConfig = await _platform.init(
          types, resolution, framerate, detectionMode, position);

      /// Notify the overlays when a barcode is detected and then call [onDetect].
      _platform.setOnDetectHandler((code) {
        state.eventNotifier.value = CameraEvent.codeFound;
        onScan?.call(code);
      });

      state.eventNotifier.value = CameraEvent.resumed;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      print(error);
      debugPrintStack(stackTrace: stack);
      return;
    }
  }

  /// Disposed the platform camera and resets the whole system.
  ///
  ///
  Future<void> dispose() async {
    try {
      await _platform.dispose();
      state._previewConfig = null;
      state.eventNotifier.value = CameraEvent.uninitialized;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Pauses the scanner and preview on the platform level.
  ///
  ///
  Future<void> pauseDetector() async {
    try {
      await _platform.pause();
      state.eventNotifier.value = CameraEvent.paused;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Resumes the scanner and preview on the platform level.
  ///
  ///
  Future<void> resumeDetector() async {
    try {
      await _platform.resume();
      state.eventNotifier.value = CameraEvent.resumed;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Toggles the torch, if available.
  ///
  ///
  Future<void> toggleTorch() async {
    if (!state._togglingTorch) {
      state._togglingTorch = true;

      try {
        state._torchState = await _platform.toggleTorch();
      } catch (error, stack) {
        state._error = error;
        state.eventNotifier.value = CameraEvent.error;
        print(error);
        debugPrintStack(stackTrace: stack);
      }

      state._togglingTorch = false;
    }
  }

  Future<void> changeCamera(CameraPosition position) async {
    try {
      await _platform.changeCamera(position);
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }
}
