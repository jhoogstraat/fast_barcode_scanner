import 'dart:typed_data';

class ImageSource {
  ImageSource.binary(ByteData data, {int rotation = 0})
      : data = [data.buffer.asUint8List(), rotation];

  /// Opens a native picker
  ImageSource.picker() : data = null;

  final dynamic data;
}
