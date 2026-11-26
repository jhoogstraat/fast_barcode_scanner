import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'barcode_type.dart';

/// Describes a detected barcode with its symbology [type], decoded [value],
/// and optional spatial coordinates ([boundingBox] and [cornerPoints]).
///
/// [Barcode] is immutable and value-equatable.
@immutable
class Barcode {
  /// Creates a [Barcode] with the given properties.
  const Barcode({
    required this.type,
    required this.value,
    this.boundingBox,
    this.cornerPoints,
  });

  /// Creates a [Barcode] from the serialized platform wire payload.
  ///
  /// Expected wire format:
  /// `[type, value]` or `[type, value, boundingBox, cornerPoints]`
  /// where:
  /// - `type` is a [String] matching a [BarcodeType.name]
  /// - `value` is the decoded [String]
  /// - `boundingBox` (optional) is `[left, top, right, bottom]` of [num]
  /// - `cornerPoints` (optional) is `[[x, y], ...]` of [num] pairs
  factory Barcode.fromPlatform(List<dynamic> data) {
    if (data.length < 2) {
      throw FormatException(
        'Expected at least 2 elements for Barcode payload, got ${data.length}.',
      );
    }

    final typeName = data[0] as String;
    final type = BarcodeType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => throw FormatException('Unknown BarcodeType: $typeName'),
    );

    final value = data[1] as String;

    Rect? boundingBox;
    if (data.length >= 3 && data[2] is List) {
      final box = data[2] as List<dynamic>;
      if (box.length == 4) {
        boundingBox = Rect.fromLTRB(
          (box[0] as num).toDouble(),
          (box[1] as num).toDouble(),
          (box[2] as num).toDouble(),
          (box[3] as num).toDouble(),
        );
      }
    }

    List<Offset>? cornerPoints;
    if (data.length >= 4 && data[3] is List) {
      final rawCorners = data[3] as List<dynamic>;
      final parsed = <Offset>[];
      for (final point in rawCorners) {
        if (point is List && point.length >= 2) {
          parsed.add(
            Offset(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ),
          );
        }
      }
      if (parsed.isNotEmpty) {
        cornerPoints = List<Offset>.unmodifiable(parsed);
      }
    }

    return Barcode(
      type: type,
      value: value,
      boundingBox: boundingBox,
      cornerPoints: cornerPoints,
    );
  }

  /// The symbology type of the barcode.
  final BarcodeType type;

  /// The decoded raw string value of the barcode.
  final String value;

  /// The bounding rectangle of the barcode in the camera's analysis coordinate
  /// space, if reported by the native scanner.
  final Rect? boundingBox;

  /// The corner vertices of the barcode in clockwise order (starting from
  /// top-left) in the camera's analysis coordinate space, if reported.
  final List<Offset>? cornerPoints;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Barcode &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          boundingBox == other.boundingBox &&
          listEquals(cornerPoints, other.cornerPoints);

  @override
  int get hashCode => Object.hash(
        type,
        value,
        boundingBox,
        cornerPoints == null ? null : Object.hashAll(cornerPoints!),
      );

  @override
  String toString() =>
      'Barcode(type: ${type.name}, value: $value, boundingBox: $boundingBox, cornerPoints: $cornerPoints)';
}
