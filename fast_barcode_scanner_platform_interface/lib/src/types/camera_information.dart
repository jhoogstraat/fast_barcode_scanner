import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Controls the trade-off between camera resolution/frame rate and battery usage.
enum PerformanceMode {
  /// Balanced default chosen by the platform (typically 1080p @ 30–60fps).
  system,

  /// Favors lower power consumption and heat (typically 720p @ 30fps).
  economic,

  /// Favors highest resolution and frame rate for dense or distant barcodes
  /// such as PDF417 and small DataMatrix codes (up to 4K / 60fps).
  high,
}

/// Dictates how the native scanner reacts when one or more barcodes are detected.
enum DetectionMode {
  /// Pauses further barcode detection on detection while keeping the live
  /// camera preview running. Call `startDetector()` to resume scanning.
  pauseDetection,

  /// Pauses both the camera preview and barcode detection on detection.
  /// Call `start()` to resume.
  pauseVideo,

  /// Keeps scanning continuously without pausing.
  continuous,
}

/// The physical lens position of the camera.
enum CameraPosition {
  /// Front-facing (selfie) camera.
  front,

  /// Rear-facing (main) camera.
  back,
}

/// Metadata describing the initialized camera stream so the UI can lay out
/// the preview, map barcode coordinates, and clamp zoom controls.
@immutable
class CameraInformation {
  /// Creates a [CameraInformation] instance.
  const CameraInformation({
    required this.videoSize,
    required this.analysisFrame,
    this.textureId,
    this.sensorOrientation = 0,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
  });

  /// Creates a [CameraInformation] from the platform channel response map.
  factory CameraInformation.fromMap(Map<dynamic, dynamic> response) {
    final videoSizeRaw = response['video_size'] as List<dynamic>;
    final analysisFrameRaw = response['analysis_frame'] as List<dynamic>;

    return CameraInformation(
      videoSize: Size(
        (videoSizeRaw[0] as num).toDouble(),
        (videoSizeRaw[1] as num).toDouble(),
      ),
      analysisFrame: Rect.fromLTWH(
        (analysisFrameRaw[0] as num).toDouble(),
        (analysisFrameRaw[1] as num).toDouble(),
        (analysisFrameRaw[2] as num).toDouble(),
        (analysisFrameRaw[3] as num).toDouble(),
      ),
      textureId: (response['texture_id'] as num?)?.toInt(),
      sensorOrientation: (response['sensor_orientation'] as num?)?.toInt() ?? 0,
      minZoom: (response['min_zoom'] as num?)?.toDouble() ?? 1.0,
      maxZoom: (response['max_zoom'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// The native dimensions of the camera video stream in pixels/points.
  final Size videoSize;

  /// The frame inside [videoSize] in which barcode detection operates.
  final Rect analysisFrame;

  /// The Flutter texture ID used for zero-copy GPU preview rendering on Android.
  /// `null` on platforms that render via a platform view (e.g., iOS `UiKitView`).
  final int? textureId;

  /// Clockwise rotation angle (in degrees: 0, 90, 180, or 270) of the camera
  /// sensor relative to the natural device orientation.
  final int sensorOrientation;

  /// Minimum supported zoom factor for the active camera device.
  final double minZoom;

  /// Maximum supported zoom factor for the active camera device.
  final double maxZoom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraInformation &&
          runtimeType == other.runtimeType &&
          videoSize == other.videoSize &&
          analysisFrame == other.analysisFrame &&
          textureId == other.textureId &&
          sensorOrientation == other.sensorOrientation &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom;

  @override
  int get hashCode => Object.hash(
        videoSize,
        analysisFrame,
        textureId,
        sensorOrientation,
        minZoom,
        maxZoom,
      );

  @override
  String toString() =>
      'CameraInformation(videoSize: $videoSize, analysisFrame: $analysisFrame, '
      'textureId: $textureId, sensorOrientation: $sensorOrientation, '
      'zoom: $minZoom..$maxZoom)';
}

/// Selects the underlying barcode detection engine on Apple platforms (iOS).
@immutable
sealed class AppleApiMode {
  const AppleApiMode();

  /// Wire identifier for this API mode.
  String get name;

  /// Additional engine-specific options sent during initialization.
  Map<String, dynamic> get options;
}

/// Uses Apple's hardware-accelerated `AVCaptureMetadataOutput` (AVFoundation).
///
/// Fast, low-power, and supports continuous scanning out of the box.
@immutable
final class AVFoundationApiMode extends AppleApiMode {
  const AVFoundationApiMode();

  /// Convenience constant instance.
  static const avFoundation = AVFoundationApiMode();

  @override
  String get name => 'avfoundation';

  @override
  Map<String, dynamic> get options => const {};

  @override
  bool operator ==(Object other) => other is AVFoundationApiMode;

  @override
  int get hashCode => name.hashCode;
}

/// Uses Apple's `Vision` framework (`VNDetectBarcodesRequest`).
///
/// Recommended for dense barcodes (e.g., PDF417, GS1 DataMatrix), multiple
/// simultaneous barcodes, or when a custom confidence threshold is desired.
@immutable
final class VisionApiMode extends AppleApiMode {
  /// Creates a [VisionApiMode] with the minimum detection [confidence] in `[0.0, 1.0]`.
  const VisionApiMode({this.confidence = 0.6})
      : assert(
          confidence >= 0.0 && confidence <= 1.0,
          'confidence must be between 0.0 and 1.0',
        );

  /// Minimum observation confidence required to report a barcode (`0.0`–`1.0`).
  final double confidence;

  @override
  String get name => 'vision';

  @override
  Map<String, dynamic> get options => {'confidence': confidence};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisionApiMode &&
          runtimeType == other.runtimeType &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(name, confidence);
}

/// Selects the underlying barcode detection engine on Android.
enum AndroidApiMode {
  /// Google ML Kit Barcode Scanning paired with CameraX.
  mlKit,
}

/// Platform-specific scanner API configuration.
@immutable
class ApiMode {
  /// Creates an [ApiMode] with the desired native engines for Apple and Android.
  const ApiMode({
    this.apple = const AVFoundationApiMode(),
    this.android = AndroidApiMode.mlKit,
  });

  /// Detection engine used on iOS. Defaults to [AVFoundationApiMode].
  final AppleApiMode apple;

  /// Detection engine used on Android. Defaults to [AndroidApiMode.mlKit].
  final AndroidApiMode android;

  /// Serializes the API selection for the current [defaultTargetPlatform].
  Map<String, dynamic> toMap([TargetPlatform? platform]) {
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.android:
        return {'api': android.name, 'options': const <String, dynamic>{}};
      case TargetPlatform.iOS:
        return {'api': apple.name, 'options': apple.options};
      default:
        throw UnsupportedError(
          'fast_barcode_scanner is only supported on iOS and Android.',
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiMode &&
          runtimeType == other.runtimeType &&
          apple == other.apple &&
          android == other.android;

  @override
  int get hashCode => Object.hash(apple, android);
}
