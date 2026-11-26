import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFastBarcodeScannerPlatform extends FastBarcodeScannerPlatform {
  CameraInformation nextInfo = const CameraInformation(
    videoSize: Size(1920, 1080),
    analysisFrame: Rect.fromLTWH(0, 0, 1920, 1080),
    textureId: 1,
    sensorOrientation: 90,
    minZoom: 1.0,
    maxZoom: 5.0,
  );

  bool torchOn = false;
  bool canSwitch = true;
  Object? errorToThrow;
  OnDetectionHandler? detectionHandler;
  final List<String> calls = [];

  @override
  Future<CameraInformation> init(
    List<BarcodeType> types,
    PerformanceMode mode,
    DetectionMode detectionMode,
    CameraPosition position,
    ApiMode api,
  ) async {
    calls.add('init:${position.name}:${mode.name}:${detectionMode.name}');
    if (errorToThrow != null) throw errorToThrow!;
    return nextInfo;
  }

  @override
  void setOnDetectionHandler(OnDetectionHandler handler) {
    calls.add('setOnDetectionHandler');
    detectionHandler = handler;
  }

  @override
  Future<void> start() async {
    calls.add('start');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> startDetector() async {
    calls.add('startDetector');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> stopDetector() async {
    calls.add('stopDetector');
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<bool> toggleTorch() async {
    calls.add('toggleTorch');
    if (errorToThrow != null) throw errorToThrow!;
    torchOn = !torchOn;
    return torchOn;
  }

  @override
  Future<double> setZoom(double zoomFactor) async {
    calls.add('setZoom:$zoomFactor');
    if (errorToThrow != null) throw errorToThrow!;
    return zoomFactor.clamp(nextInfo.minZoom, nextInfo.maxZoom);
  }

  @override
  Future<bool> canSwitchCamera() async {
    calls.add('canSwitchCamera');
    return canSwitch;
  }

  @override
  Future<CameraInformation> changeConfiguration({
    List<BarcodeType>? types,
    PerformanceMode? mode,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) async {
    calls.add('config:${position?.name}');
    if (errorToThrow != null) throw errorToThrow!;
    return nextInfo;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    detectionHandler = null;
  }

  @override
  Future<List<Barcode>?> scanImage(ImageSource source) async {
    calls.add('scanImage');
    return const [Barcode(type: BarcodeType.qr, value: 'still-image')];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFastBarcodeScannerPlatform fakePlatform;
  late CameraController controller;

  setUp(() {
    fakePlatform = _FakeFastBarcodeScannerPlatform();
    FastBarcodeScannerPlatform.instance = fakePlatform;
    controller = CameraController.forTesting();
  });

  tearDown(() async {
    await controller.dispose();
  });

  group('CameraController', () {
    test('initializes, updates state, and handles detection events', () async {
      final scanned = <Barcode>[];

      await controller.initialize(
        types: const [BarcodeType.ean13, BarcodeType.qr],
        mode: PerformanceMode.system,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        api: const ApiMode(),
        onScan: scanned.addAll,
      );

      expect(controller.state.value.isInitialized, isTrue);
      expect(controller.eventNotifier.value, ScannerEvent.resumed);
      expect(controller.state.value.zoom, 1.0);

      const sample = Barcode(type: BarcodeType.qr, value: 'https://dart.dev');
      fakePlatform.detectionHandler?.call(const [sample]);

      expect(controller.eventNotifier.value, ScannerEvent.detected);
      expect(controller.resultNotifier.value, const [sample]);
      expect(scanned, const [sample]);
    });

    test('captures PlatformException into ScannerState.error', () async {
      fakePlatform.errorToThrow = PlatformException(
        code: 'UNAUTHORIZED',
        message: 'Permission denied',
      );

      await expectLater(
        () => controller.initialize(
          types: const [BarcodeType.qr],
          mode: PerformanceMode.system,
          position: CameraPosition.back,
          detectionMode: DetectionMode.pauseVideo,
          api: const ApiMode(),
        ),
        throwsA(isA<PlatformException>()),
      );

      expect(controller.state.value.hasError, isTrue);
      expect(controller.state.value.error, isA<PlatformException>());
      expect(controller.eventNotifier.value, ScannerEvent.error);
    });

    test('toggles torch and releases lock even on failure', () async {
      await controller.initialize(
        types: const [BarcodeType.qr],
        mode: PerformanceMode.system,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        api: const ApiMode(),
      );

      expect(await controller.toggleTorch(), isTrue);
      expect(controller.state.value.torch, isTrue);

      fakePlatform.errorToThrow = PlatformException(code: 'TORCH_ERROR');
      await expectLater(
          controller.toggleTorch, throwsA(isA<PlatformException>()));

      // Re-initialize and ensure lock was properly released.
      fakePlatform.errorToThrow = null;
      await controller.initialize(
        types: const [BarcodeType.qr],
        mode: PerformanceMode.system,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        api: const ApiMode(),
      );
      expect(await controller.toggleTorch(), isFalse);
    });

    test('clamps zoom to CameraInformation min/max bounds', () async {
      await controller.initialize(
        types: const [BarcodeType.qr],
        mode: PerformanceMode.system,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        api: const ApiMode(),
      );

      expect(await controller.setZoom(3.5), 3.5);
      expect(controller.state.value.zoom, 3.5);

      expect(await controller.setZoom(99.0), 5.0);
      expect(controller.state.value.zoom, 5.0);

      expect(await controller.setZoom(0.2), 1.0);
      expect(controller.state.value.zoom, 1.0);
    });

    test('switches camera position via switchCamera()', () async {
      await controller.initialize(
        types: const [BarcodeType.qr],
        mode: PerformanceMode.system,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        api: const ApiMode(),
      );

      expect(await controller.canSwitchCamera(), isTrue);
      await controller.switchCamera();
      expect(
          controller.state.value.scannerConfig?.position, CameraPosition.front);

      await controller.switchCamera();
      expect(
          controller.state.value.scannerConfig?.position, CameraPosition.back);
    });

    test('pauses and resumes camera and detector', () async {
      await controller.initialize(
        types: const [BarcodeType.qr],
        mode: PerformanceMode.system,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        api: const ApiMode(),
      );

      await controller.pauseScanner();
      expect(controller.eventNotifier.value, ScannerEvent.paused);
      await controller.resumeScanner();
      expect(controller.eventNotifier.value, ScannerEvent.resumed);

      await controller.pauseCamera();
      expect(controller.eventNotifier.value, ScannerEvent.paused);
      await controller.resumeCamera();
      expect(controller.eventNotifier.value, ScannerEvent.resumed);

      expect(
        fakePlatform.calls,
        containsAllInOrder(['stopDetector', 'startDetector', 'stop', 'start']),
      );
    });
  });

  group('RectOfInterest and coordinate scaling', () {
    test('scaleCodeCornerPoint maps center point consistently', () {
      final mapped = scaleCodeCornerPoint(
        cornerPoint: const Offset(540, 960),
        analysisImageSize: const Size(1920, 1080),
        widgetSize: const Size(400, 800),
      );

      expect(mapped.dx, closeTo(200, 0.5));
      expect(mapped.dy, closeTo(400, 0.5));
    });

    test('RectOfInterest.square filters codes inside vs outside', () {
      final roi = RectOfInterest.square(size: 200);
      const inside = Barcode(
        type: BarcodeType.qr,
        value: 'in',
        boundingBox: Rect.fromLTRB(500, 920, 580, 1000),
      );
      const outside = Barcode(
        type: BarcodeType.qr,
        value: 'out',
        boundingBox: Rect.fromLTRB(0, 0, 50, 50),
      );

      final filtered = roi.filterCodes(
        codes: const [inside, outside],
        analysisSize: const Size(1920, 1080),
        previewSize: const Size(400, 800),
      );

      expect(filtered, const [inside]);
    });
  });
}
