import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:fast_barcode_scanner_platform_interface/src/method_channel_fast_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/method_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.jhoogstraat/fast_barcode_scanner';
  const sampleCameraInfoMap = {
    'video_size': [1920.0, 1080.0],
    'analysis_frame': [0.0, 0.0, 1920.0, 1080.0],
    'texture_id': 42,
    'sensor_orientation': 90,
    'min_zoom': 1.0,
    'max_zoom': 6.0,
  };

  late MethodChannelMock mockChannel;
  late MethodChannelFastBarcodeScanner scanner;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    scanner = MethodChannelFastBarcodeScanner();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('Initialization and configuration', () {
    test('init sends serialized arguments and parses CameraInformation',
        () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {'init': sampleCameraInfoMap},
      );

      final info = await scanner.init(
        const [BarcodeType.ean13, BarcodeType.qr],
        PerformanceMode.high,
        DetectionMode.pauseDetection,
        CameraPosition.back,
        const ApiMode(),
      );

      expect(mockChannel.log, [
        isMethodCall('init', arguments: {
          'types': ['ean13', 'qr'],
          'mode': 'high',
          'detectionMode': 'pauseDetection',
          'pos': 'back',
          'api': 'mlKit',
          'options': const <String, dynamic>{},
        }),
      ]);

      expect(
        info,
        const CameraInformation(
          videoSize: Size(1920, 1080),
          analysisFrame: Rect.fromLTWH(0, 0, 1920, 1080),
          textureId: 42,
          sensorOrientation: 90,
          minZoom: 1.0,
          maxZoom: 6.0,
        ),
      );
    });

    test('init sends iOS Vision options when on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {'init': sampleCameraInfoMap},
      );

      await scanner.init(
        const [BarcodeType.pdf417],
        PerformanceMode.system,
        DetectionMode.continuous,
        CameraPosition.front,
        const ApiMode(apple: VisionApiMode(confidence: 0.8)),
      );

      expect(mockChannel.log, [
        isMethodCall('init', arguments: {
          'types': ['pdf417'],
          'mode': 'system',
          'detectionMode': 'continuous',
          'pos': 'front',
          'api': 'vision',
          'options': {'confidence': 0.8},
        }),
      ]);
    });

    test('changeConfiguration sends only non-null fields', () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {'config': sampleCameraInfoMap},
      );

      final info = await scanner.changeConfiguration(
        types: const [BarcodeType.dataMatrix],
        mode: PerformanceMode.economic,
        detectionMode: DetectionMode.continuous,
        position: CameraPosition.front,
      );

      expect(mockChannel.log, [
        isMethodCall('config', arguments: {
          'types': ['dataMatrix'],
          'mode': 'economic',
          'detectionMode': 'continuous',
          'pos': 'front',
        }),
      ]);
      expect(info.textureId, 42);
    });
  });

  group('Camera & detector controls', () {
    test('start, stop, startDetector, stopDetector, dispose', () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {
          'start': null,
          'stop': null,
          'startDetector': null,
          'stopDetector': null,
          'dispose': null,
        },
      );

      await scanner.start();
      await scanner.stop();
      await scanner.startDetector();
      await scanner.stopDetector();
      await scanner.dispose();

      expect(mockChannel.log, [
        isMethodCall('start', arguments: null),
        isMethodCall('stop', arguments: null),
        isMethodCall('startDetector', arguments: null),
        isMethodCall('stopDetector', arguments: null),
        isMethodCall('dispose', arguments: null),
      ]);
    });

    test('toggleTorch, setZoom, and canSwitchCamera', () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {
          'torch': true,
          'setZoom': 2.5,
          'canSwitchCamera': true,
        },
      );

      expect(await scanner.toggleTorch(), isTrue);
      expect(await scanner.setZoom(2.5), 2.5);
      expect(await scanner.canSwitchCamera(), isTrue);

      expect(mockChannel.log, [
        isMethodCall('torch', arguments: null),
        isMethodCall('setZoom', arguments: 2.5),
        isMethodCall('canSwitchCamera', arguments: null),
      ]);
    });
  });

  group('Detection events', () {
    test('parses valid barcode events and ignores malformed entries', () {
      List<Barcode>? received;
      scanner.setOnDetectionHandler((codes) => received = codes);

      scanner.handlePlatformBarcodeEvent([
        [
          'ean13',
          '1234567890128',
          [1.0, 2.0, 3.0, 4.0],
          [
            [1, 2],
            [3, 2],
            [3, 4],
            [1, 4],
          ],
        ],
        ['not_a_real_type', 'ignored'],
      ]);

      expect(received, isNotNull);
      expect(received!.length, 1);
      expect(received!.first.type, BarcodeType.ean13);
      expect(received!.first.value, '1234567890128');
      expect(received!.first.boundingBox, const Rect.fromLTRB(1, 2, 3, 4));
    });

    test('does not invoke handler when no valid barcodes are present', () {
      var called = false;
      scanner.setOnDetectionHandler((_) => called = true);

      scanner.handlePlatformBarcodeEvent([
        ['invalid_type', '123'],
      ]);

      expect(called, isFalse);
    });
  });

  group('Still image scanning', () {
    test('scanImage with picker returns decoded barcodes', () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {
          'scan': [
            ['qr', 'hello-world'],
          ],
        },
      );

      final result = await scanner.scanImage(const ImageSource.picker());

      expect(mockChannel.log, [isMethodCall('scan', arguments: null)]);
      expect(
          result, const [Barcode(type: BarcodeType.qr, value: 'hello-world')]);
    });

    test('scanImage with picker returns null on user cancel', () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {'scan': null},
      );

      final result = await scanner.scanImage(const ImageSource.picker());
      expect(result, isNull);
    });

    test('scanImage with binary bytes forwards bytes and rotation', () async {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {'scan': <dynamic>[]},
      );

      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final result = await scanner.scanImage(
        ImageSource.bytes(bytes, rotation: 90),
      );

      expect(mockChannel.log, [
        isMethodCall('scan', arguments: [bytes, 90]),
      ]);
      expect(result, isEmpty);
    });
  });

  group('Error forwarding', () {
    test('forwards PlatformException from native side', () {
      mockChannel = MethodChannelMock(
        channelName: channelName,
        methods: {
          'init': PlatformException(
            code: 'UNAUTHORIZED',
            message: 'Camera permission denied',
          ),
        },
      );

      expect(
        () => scanner.init(
          const [BarcodeType.qr],
          PerformanceMode.system,
          DetectionMode.pauseVideo,
          CameraPosition.back,
          const ApiMode(),
        ),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'UNAUTHORIZED')
              .having((e) => e.message, 'message', 'Camera permission denied'),
        ),
      );
    });
  });
}
