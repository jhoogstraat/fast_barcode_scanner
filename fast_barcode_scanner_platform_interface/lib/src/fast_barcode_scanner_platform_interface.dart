import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';
import 'method_channel_fast_barcode_scanner.dart';

/// The interface that implementations of fast_barcode_scanner must implement.
///
/// Platform implementations should extend this class rather than implement it as `fast_barcode_scanner`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
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

  /// Returns a [PreviewConfiguration] containing the parameters with
  /// which the camera is set up.
  ///
  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position) {
    throw UnimplementedError('init() has not been implemented');
  }

  /// Pauses the camera on the platform.
  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented');
  }

  /// Resumes the camera from the paused state on the platform.
  Future<void> resume() {
    throw UnimplementedError('resume() has not been implemented');
  }

  /// Stops and clears the camera ressources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented');
  }

  /// Toggles the torch, if available.
  Future<bool> toggleTorch() {
    throw UnimplementedError('toggleTorch() has not been implemented');
  }

  Future<bool> changeCamera(CameraPosition position) {
    throw UnimplementedError('changeCamera() has not been implemented');
  }

  /// Set the method to be called when a barcode is detected
  void setOnDetectHandler(void Function(Barcode) handler) {
    throw UnimplementedError('setOnReadHandler() has not been implemented');
  }
}
