import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_fast_barcode_scanner.dart';
import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/camera_information.dart';
import 'types/image_source.dart';

/// A callback that receives all uniquely scanned barcodes in a camera frame.
typedef OnDetectionHandler = void Function(List<Barcode> barcodes);

/// The common platform interface for `fast_barcode_scanner`.
///
/// Platform implementations should `extend` this class rather than `implement`
/// it so that newly added methods provide default implementations.
abstract class FastBarcodeScannerPlatform extends PlatformInterface {
  /// Constructs a [FastBarcodeScannerPlatform].
  FastBarcodeScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FastBarcodeScannerPlatform _instance =
      MethodChannelFastBarcodeScanner();

  /// The active [FastBarcodeScannerPlatform] implementation.
  ///
  /// Defaults to [MethodChannelFastBarcodeScanner].
  static FastBarcodeScannerPlatform get instance => _instance;

  /// Sets a custom [FastBarcodeScannerPlatform] implementation (for example,
  /// a platform-specific package or a mock in tests).
  static set instance(FastBarcodeScannerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Initializes and starts the native camera and barcode scanner.
  ///
  /// Returns the [CameraInformation] describing the active stream.
  Future<CameraInformation> init(
    List<BarcodeType> types,
    PerformanceMode mode,
    DetectionMode detectionMode,
    CameraPosition position,
    ApiMode api,
  ) {
    throw UnimplementedError('init() has not been implemented.');
  }

  /// Registers the callback invoked whenever barcodes are detected.
  void setOnDetectionHandler(OnDetectionHandler handler) {
    throw UnimplementedError(
        'setOnDetectionHandler() has not been implemented.');
  }

  /// Starts (or resumes) the camera preview and barcode detector.
  Future<void> start() {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Stops (or pauses) the camera preview and barcode detector.
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Resumes the barcode detector while the camera preview is running.
  Future<void> startDetector() {
    throw UnimplementedError('startDetector() has not been implemented.');
  }

  /// Pauses the barcode detector while keeping the camera preview running.
  Future<void> stopDetector() {
    throw UnimplementedError('stopDetector() has not been implemented.');
  }

  /// Toggles the camera torch (flashlight), if available on the active camera.
  ///
  /// Returns `true` if the torch is now turned on, `false` otherwise.
  Future<bool> toggleTorch() {
    throw UnimplementedError('toggleTorch() has not been implemented.');
  }

  /// Sets the camera zoom factor.
  ///
  /// The value is clamped on the native side to `[minZoom, maxZoom]` reported
  /// in [CameraInformation]. Returns the applied zoom factor.
  Future<double> setZoom(double zoomFactor) {
    throw UnimplementedError('setZoom() has not been implemented.');
  }

  /// Returns `true` if the device supports switching between front and back
  /// cameras.
  Future<bool> canSwitchCamera() {
    throw UnimplementedError('canSwitchCamera() has not been implemented.');
  }

  /// Updates the active camera and scanner configuration.
  ///
  /// Any `null` parameter retains its current value. Returns the updated
  /// [CameraInformation].
  Future<CameraInformation> changeConfiguration({
    List<BarcodeType>? types,
    PerformanceMode? mode,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) {
    throw UnimplementedError('changeConfiguration() has not been implemented.');
  }

  /// Stops the camera and releases all native resources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Scans a still image from [source] independently of the live camera.
  ///
  /// Returns `null` if the user cancelled the native image picker, an empty
  /// list if no barcodes were found, or the list of detected [Barcode]s.
  Future<List<Barcode>?> scanImage(ImageSource source) {
    throw UnimplementedError('scanImage() has not been implemented.');
  }
}
