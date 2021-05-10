import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class CameraConfiguration {
  const CameraConfiguration(this.types, this.resolution, this.framerate,
      this.detectionMode, this.position);

  final List<BarcodeType> types;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode detectionMode;
  final CameraPosition position;
}

enum CameraEvent { uninitialized, init, paused, resumed, codeFound, error }

class CameraController {
  CameraController._() : this.state = CameraState();

  static final _instance = CameraController._();
  static CameraController get instance => _instance;

  // Data
  final CameraState state;

  FastBarcodeScannerPlatform get _platform =>
      FastBarcodeScannerPlatform.instance;

  // Intents

  /// Informs the platform to initialize the camera.
  ///
  /// The camera is initialized only once per session.
  /// All susequent calls to this method will be dropped.
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
      print(error);
      debugPrintStack(stackTrace: stack);
      state.eventNotifier.value = CameraEvent.error;
      return;
    }
  }

  Future<void> dispose() async {
    try {
      await _platform.dispose();
      state._previewConfig = null;
      state.eventNotifier.value = CameraEvent.uninitialized;
    } catch (error, stack) {
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> pauseDetector() async {
    try {
      await _platform.pause();
      state.eventNotifier.value = CameraEvent.paused;
    } catch (error, stack) {
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> resumeDetector() async {
    try {
      await _platform.resume();
      state.eventNotifier.value = CameraEvent.resumed;
    } catch (error, stack) {
      print(error);
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> toggleTorch() async {
    if (!state._togglingTorch) {
      state._togglingTorch = true;

      try {
        await _platform.toggleTorch();
      } catch (error, stack) {
        print(error);
        debugPrintStack(stackTrace: stack);
      }

      state._togglingTorch = false;
    }
  }
}

class CameraState {
  PreviewConfiguration? _previewConfig;
  bool _togglingTorch = false;
  Object? error;

  final eventNotifier = ValueNotifier(CameraEvent.uninitialized);
  bool get isInitialized => _previewConfig != null;
  bool get hasError => error != null;
  PreviewConfiguration? get previewConfig => _previewConfig;
}
