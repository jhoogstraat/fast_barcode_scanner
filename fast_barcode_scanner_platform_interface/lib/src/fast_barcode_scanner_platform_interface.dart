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

  static final Object _token = Object();

  static FastBarcodeScannerPlatform _instance =
      MethodChannelFastBarcodeScanner();

  /// The default instance of [FastBarcodeScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFastBarcodeScanner].
  static FastBarcodeScannerPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [FastBarcodeScannerPlatform] when they register themselves.
  static set instance(FastBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a [PreviewConfiguration] containing the parameters with wich the camera is set up.
  ///
  ///
  Future<PreviewConfiguration> init(List<BarcodeType> types,
      Resolution resolution, Framerate framerate, DetectionMode detectionMode) {
    throw UnimplementedError('init() has not been implemented');
  }

  Future<void> dispose() {
    throw UnimplementedError('stop() has not been implemented');
  }

  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented');
  }

  Future<void> resume() {
    throw UnimplementedError('resume() has not been implemented');
  }

  Future<void> toggleFlash() {
    throw UnimplementedError('toggleFlash() has not been implemented');
  }

  void setOnDetectHandler(void Function(Barcode) handler) {
    throw UnimplementedError('setOnReadHandler() has not been implemented');
  }
}
