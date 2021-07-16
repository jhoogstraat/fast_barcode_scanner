import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';

class ScannerConfiguration {
  const ScannerConfiguration(
    this.types,
    this.resolution,
    this.framerate,
    this.position,
    this.detectionMode,
  );

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

  /// The physical position of the camera being used.
  final CameraPosition position;

  /// Determines how the camera reacts to detected barcodes.
  final DetectionMode detectionMode;

  ScannerConfiguration copyWith({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) {
    return ScannerConfiguration(
      types ?? this.types,
      resolution ?? this.resolution,
      framerate ?? this.framerate,
      position ?? this.position,
      detectionMode ?? this.detectionMode,
    );
  }
}
