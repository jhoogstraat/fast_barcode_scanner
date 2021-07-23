import 'package:fast_barcode_scanner_platform_interface/src/types/image_source.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';
import 'method_channel_fast_barcode_scanner.dart';

/// The interface that implementations of fast_barcode_scanner must implement.
///
/// Platform implementations should extend this class rather than implement it as `fast_barcode_scanner`
/// Extending this class (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [FastBarcodeScannerPlatform] methods.
abstract class FastBarcodeScannerPlatform extends PlatformInterface {
  FastBarcodeScannerPlatform() : super(token: _token);

  static const Object _token = Object();

  static FastBarcodeScannerPlatform _instance =
      MethodChannelFastBarcodeScanner();

  /// The default instance of [FastBarcodeScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFastBarcodeScanner].
  static FastBarcodeScannerPlatform get instance => _instance;

  /// Platform specific plugins should set this with their own platform-specific
  /// class that extends [FastBarcodeScannerPlatform] when they register themselves.
  static set instance(FastBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes and starts the native camera interface.
  /// Returns a [PreviewConfiguration] the camera is setup with.
  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position) {
    throw UnimplementedError('init() has not been implemented');
  }

  /// Resumes the camera from the stopped state on the platform.
  Future<void> start() {
    throw UnimplementedError('resume() has not been implemented');
  }

  /// Stops the camera on the platform.
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented');
  }

  // Starts the detector, if it was paused.
  Future<void> startDetector() {
    throw UnimplementedError('startDetector() has not been implemented');
  }

  // Stops the detector. Keeps the preview running.
  Future<void> stopDetector() {
    throw UnimplementedError('stopDetector() has not been implemented');
  }

  /// Stops and clears the camera resources.
  // Future<void> dispose() {
  //   throw UnimplementedError('dispose() has not been implemented');
  // }

  /// Toggles the torch, if available.
  Future<bool> toggleTorch() {
    throw UnimplementedError('toggleTorch() has not been implemented');
  }

  /// Changes the supplied camera settings.
  /// Nil values are ignored and stay unchanged.
  Future<PreviewConfiguration> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) {
    throw UnimplementedError('changeConfiguration() has not been implemented');
  }

  /// Set the method to be called when a barcode is detected
  void setOnDetectHandler(void Function(Barcode) handler) {
    throw UnimplementedError('setOnDetectHandler() has not been implemented');
  }

  Future<List<Barcode>> scanImage(ImageSource source) {
    throw UnimplementedError('scanImage() has not been implemented');
  }
}
