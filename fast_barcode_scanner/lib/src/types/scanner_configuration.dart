import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// The active configuration of the camera and barcode scanner.
@immutable
class ScannerConfiguration {
  /// Creates a [ScannerConfiguration].
  const ScannerConfiguration(
    this.types,
    this.mode,
    this.position,
    this.detectionMode,
  );

  /// The barcode symbologies the scanner should detect.
  final List<BarcodeType> types;

  /// The performance / resolution target of the camera.
  final PerformanceMode mode;

  /// The physical lens position of the camera being used.
  final CameraPosition position;

  /// Determines how the scanner reacts when barcodes are detected.
  final DetectionMode detectionMode;

  /// Returns a copy of this configuration with the given fields replaced.
  ScannerConfiguration copyWith({
    List<BarcodeType>? types,
    PerformanceMode? mode,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) {
    return ScannerConfiguration(
      types ?? this.types,
      mode ?? this.mode,
      position ?? this.position,
      detectionMode ?? this.detectionMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannerConfiguration &&
          runtimeType == other.runtimeType &&
          listEquals(types, other.types) &&
          mode == other.mode &&
          position == other.position &&
          detectionMode == other.detectionMode;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(types),
        mode,
        position,
        detectionMode,
      );

  @override
  String toString() =>
      'ScannerConfiguration(types: $types, mode: $mode, position: $position, detectionMode: $detectionMode)';
}
