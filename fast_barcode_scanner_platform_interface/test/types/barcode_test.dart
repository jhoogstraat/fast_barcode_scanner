import 'dart:ui';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Barcode', () {
    test('parses minimal payload [type, value]', () {
      final barcode = Barcode.fromPlatform(['ean13', '4006381333931']);

      expect(barcode.type, BarcodeType.ean13);
      expect(barcode.value, '4006381333931');
      expect(barcode.boundingBox, isNull);
      expect(barcode.cornerPoints, isNull);
    });

    test('parses full payload with boundingBox and cornerPoints', () {
      final barcode = Barcode.fromPlatform([
        'qr',
        'https://example.com',
        [10.0, 20.0, 110.0, 120.0],
        [
          [10, 20],
          [110, 20],
          [110, 120],
          [10, 120],
        ],
      ]);

      expect(barcode.type, BarcodeType.qr);
      expect(barcode.value, 'https://example.com');
      expect(barcode.boundingBox, const Rect.fromLTRB(10, 20, 110, 120));
      expect(barcode.cornerPoints, const [
        Offset(10, 20),
        Offset(110, 20),
        Offset(110, 120),
        Offset(10, 120),
      ]);
    });

    test('throws FormatException for unknown type or short payload', () {
      expect(() => Barcode.fromPlatform(['ean13']), throwsFormatException);
      expect(
        () => Barcode.fromPlatform(['unknown_type', '123']),
        throwsFormatException,
      );
    });

    test('implements value equality and consistent hashCode', () {
      const a = Barcode(
        type: BarcodeType.code128,
        value: 'ABC-123',
        boundingBox: Rect.fromLTRB(1, 2, 3, 4),
        cornerPoints: [Offset(1, 2), Offset(3, 4)],
      );
      const b = Barcode(
        type: BarcodeType.code128,
        value: 'ABC-123',
        boundingBox: Rect.fromLTRB(1, 2, 3, 4),
        cornerPoints: [Offset(1, 2), Offset(3, 4)],
      );
      const c = Barcode(type: BarcodeType.code128, value: 'DIFF');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('CameraInformation', () {
    test('parses map with all fields', () {
      final info = CameraInformation.fromMap({
        'video_size': [1920, 1080],
        'analysis_frame': [0, 0, 1920, 1080],
        'texture_id': 7,
        'sensor_orientation': 90,
        'min_zoom': 1.0,
        'max_zoom': 8.5,
      });

      expect(info.videoSize, const Size(1920, 1080));
      expect(info.analysisFrame, const Rect.fromLTWH(0, 0, 1920, 1080));
      expect(info.textureId, 7);
      expect(info.sensorOrientation, 90);
      expect(info.minZoom, 1.0);
      expect(info.maxZoom, 8.5);
    });

    test('uses sensible defaults for optional fields', () {
      final info = CameraInformation.fromMap({
        'video_size': [1280.0, 720.0],
        'analysis_frame': [10.0, 20.0, 640.0, 480.0],
      });

      expect(info.textureId, isNull);
      expect(info.sensorOrientation, 0);
      expect(info.minZoom, 1.0);
      expect(info.maxZoom, 1.0);
    });

    test('implements value equality and hashCode', () {
      const a = CameraInformation(
        videoSize: Size(1920, 1080),
        analysisFrame: Rect.fromLTWH(0, 0, 1920, 1080),
        textureId: 1,
        sensorOrientation: 90,
        minZoom: 1.0,
        maxZoom: 5.0,
      );
      const b = CameraInformation(
        videoSize: Size(1920, 1080),
        analysisFrame: Rect.fromLTWH(0, 0, 1920, 1080),
        textureId: 1,
        sensorOrientation: 90,
        minZoom: 1.0,
        maxZoom: 5.0,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ApiMode', () {
    test('serializes iOS AVFoundation and Vision modes', () {
      const avMode = ApiMode(apple: AVFoundationApiMode.avFoundation);
      expect(avMode.toMap(TargetPlatform.iOS), {
        'api': 'avfoundation',
        'options': const <String, dynamic>{},
      });

      const visionMode = ApiMode(apple: VisionApiMode(confidence: 0.75));
      expect(visionMode.toMap(TargetPlatform.iOS), {
        'api': 'vision',
        'options': {'confidence': 0.75},
      });
    });

    test('serializes Android ML Kit mode', () {
      const mode = ApiMode(android: AndroidApiMode.mlKit);
      expect(mode.toMap(TargetPlatform.android), {
        'api': 'mlKit',
        'options': const <String, dynamic>{},
      });
    });

    test('throws UnsupportedError on desktop platforms', () {
      const mode = ApiMode();
      expect(
        () => mode.toMap(TargetPlatform.linux),
        throwsUnsupportedError,
      );
    });
  });

  group('ImageSource', () {
    test('picker source has null data', () {
      const source = ImageSource.picker();
      expect(source.data, isNull);
      expect(source, equals(const ImageSource.picker()));
    });

    test('binary source serializes bytes and rotation', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final byteData = ByteData.sublistView(bytes);
      final source = ImageSource.binary(byteData, rotation: 90);

      expect(source.data, [bytes, 90]);
      expect(source, equals(ImageSource.bytes(bytes, rotation: 90)));
    });
  });
}
