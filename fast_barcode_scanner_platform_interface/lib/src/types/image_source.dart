import 'package:flutter/foundation.dart';

/// Describes a still image source to be scanned for barcodes via
/// `FastBarcodeScannerPlatform.scanImage`.
@immutable
sealed class ImageSource {
  const ImageSource();

  /// Scans an encoded image (JPEG, PNG, etc.) provided as raw bytes.
  ///
  /// [rotation] is an optional clockwise rotation in degrees (`0`, `90`, `180`,
  /// or `270`), used on Android when the buffer is not EXIF-oriented.
  factory ImageSource.binary(ByteData data, {int rotation = 0}) =>
      BinaryImageSource(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        rotation: rotation,
      );

  /// Scans an encoded image (JPEG, PNG, etc.) provided directly as a [Uint8List].
  factory ImageSource.bytes(Uint8List bytes, {int rotation = 0}) =>
      BinaryImageSource(bytes, rotation: rotation);

  /// Opens the platform's native photo picker and scans the chosen image.
  const factory ImageSource.picker() = PickerImageSource;

  /// Serialized payload passed over the platform method channel.
  Object? get data;
}

/// An [ImageSource] backed by in-memory encoded image bytes.
@immutable
final class BinaryImageSource extends ImageSource {
  const BinaryImageSource(this.bytes, {this.rotation = 0});

  /// Encoded image bytes (e.g. PNG or JPEG).
  final Uint8List bytes;

  /// Clockwise rotation in degrees (`0`, `90`, `180`, `270`).
  final int rotation;

  @override
  List<Object> get data => [bytes, rotation];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinaryImageSource &&
          runtimeType == other.runtimeType &&
          rotation == other.rotation &&
          listEquals(bytes, other.bytes);

  @override
  int get hashCode => Object.hash(rotation, Object.hashAll(bytes));
}

/// An [ImageSource] that opens the native photo picker.
@immutable
final class PickerImageSource extends ImageSource {
  const PickerImageSource();

  @override
  Object? get data => null;

  @override
  bool operator ==(Object other) => other is PickerImageSource;

  @override
  int get hashCode => runtimeType.hashCode;
}
