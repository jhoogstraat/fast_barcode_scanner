import 'dart:io';
import 'dart:ui';

Future<Image> loadBarcodeImage() async {
  // Test did not catch errors while loading the file... now it does.
  try {
    final bytes = await File("./test/resources/barcode.jpg").readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  } catch (error) {
    rethrow;
  }
}
