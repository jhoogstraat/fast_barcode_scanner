import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fast_barcode_scanner_platform_interface.dart';
import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/camera_information.dart';
import 'types/image_source.dart';

/// Default [FastBarcodeScannerPlatform] implementation using Flutter's
/// [MethodChannel] and [EventChannel].
class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  /// The method channel used for camera commands.
  @visibleForTesting
  static const MethodChannel channel =
      MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  /// The event channel used to stream detected barcodes from native code.
  @visibleForTesting
  static const EventChannel detectionEventsChannel =
      EventChannel('com.jhoogstraat/fast_barcode_scanner/detections');

  Stream<dynamic>? _detectionEventStream;
  StreamSubscription<dynamic>? _barcodeEventStreamSubscription;
  OnDetectionHandler? _onDetectionHandler;

  @override
  Future<CameraInformation> init(
    List<BarcodeType> types,
    PerformanceMode mode,
    DetectionMode detectionMode,
    CameraPosition position,
    ApiMode api,
  ) async {
    final response = await channel.invokeMapMethod<dynamic, dynamic>('init', {
      'types': types.map((e) => e.name).toList(growable: false),
      'mode': mode.name,
      'detectionMode': detectionMode.name,
      'pos': position.name,
      ...api.toMap(),
    });

    if (response == null) {
      throw PlatformException(
        code: 'INVALID_RESPONSE',
        message: 'Native init() returned null CameraInformation.',
      );
    }

    return CameraInformation.fromMap(response);
  }

  @override
  void setOnDetectionHandler(OnDetectionHandler handler) {
    _onDetectionHandler = handler;
    _detectionEventStream ??= detectionEventsChannel.receiveBroadcastStream();
    _barcodeEventStreamSubscription ??=
        _detectionEventStream!.listen(handlePlatformBarcodeEvent);
  }

  @override
  Future<void> start() => channel.invokeMethod<void>('start');

  @override
  Future<void> stop() => channel.invokeMethod<void>('stop');

  @override
  Future<void> startDetector() => channel.invokeMethod<void>('startDetector');

  @override
  Future<void> stopDetector() => channel.invokeMethod<void>('stopDetector');

  @override
  Future<bool> toggleTorch() async {
    final isOn = await channel.invokeMethod<bool>('torch');
    return isOn ?? false;
  }

  @override
  Future<double> setZoom(double zoomFactor) async {
    final applied = await channel.invokeMethod<num>('setZoom', zoomFactor);
    return applied?.toDouble() ?? zoomFactor;
  }

  @override
  Future<bool> canSwitchCamera() async {
    final result = await channel.invokeMethod<bool>('canSwitchCamera');
    return result ?? false;
  }

  @override
  Future<CameraInformation> changeConfiguration({
    List<BarcodeType>? types,
    PerformanceMode? mode,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) async {
    final response = await channel.invokeMapMethod<dynamic, dynamic>('config', {
      if (types != null)
        'types': types.map((e) => e.name).toList(growable: false),
      if (mode != null) 'mode': mode.name,
      if (detectionMode != null) 'detectionMode': detectionMode.name,
      if (position != null) 'pos': position.name,
    });

    if (response == null) {
      throw PlatformException(
        code: 'INVALID_RESPONSE',
        message: 'Native config() returned null CameraInformation.',
      );
    }

    return CameraInformation.fromMap(response);
  }

  @override
  Future<void> dispose() async {
    await _barcodeEventStreamSubscription?.cancel();
    _barcodeEventStreamSubscription = null;
    _onDetectionHandler = null;
    await channel.invokeMethod<void>('dispose');
  }

  @override
  Future<List<Barcode>?> scanImage(ImageSource source) async {
    final response = await channel.invokeMethod<List<dynamic>>(
      'scan',
      source.data,
    );
    if (response == null) return null;

    return response
        .map((e) => Barcode.fromPlatform(e as List<dynamic>))
        .toList(growable: false);
  }

  /// Parses an incoming EventChannel payload and forwards it to the registered
  /// [OnDetectionHandler].
  @visibleForTesting
  void handlePlatformBarcodeEvent(dynamic data) {
    if (data is! List) return;

    final barcodes = <Barcode>[];
    for (final item in data) {
      if (item is! List) continue;
      try {
        barcodes.add(Barcode.fromPlatform(item));
      } catch (e) {
        debugPrint(
            'fast_barcode_scanner: skipping invalid barcode payload: $e');
      }
    }

    if (barcodes.isNotEmpty) {
      _onDetectionHandler?.call(barcodes);
    }
  }
}
