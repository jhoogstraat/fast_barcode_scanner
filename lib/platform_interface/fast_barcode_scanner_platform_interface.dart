import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../messages/preview_configuration.dart';
import 'method_channel_fast_barcode_scanner.dart';

/// The interface that implementations of fast_barcode_scanner must implement.
abstract class FastBarcodeScannerPlatform extends PlatformInterface {
  FastBarcodeScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FastBarcodeScannerPlatform _instance =
      MethodChannelFastBarcodeScanner();

  static FastBarcodeScannerPlatform get instance => _instance;

  static set instance(FastBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<PreviewConfiguration> init(List<String> types, String resolution,
      String framerate, String detectionMode) async {
    throw UnimplementedError('start() has not been implemented');
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

  void setOnReadHandler(void Function(dynamic) handler) {
    throw UnimplementedError('setOnReadHandler() has not been implemented');
  }
}
