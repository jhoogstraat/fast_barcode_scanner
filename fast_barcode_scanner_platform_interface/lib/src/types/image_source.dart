import 'dart:typed_data';

class ImageSource {
  /// Directly forwarded to
  /// https://developers.google.com/android/reference/com/google/mlkit/vision/common/InputImage#fromByteArray(byte[],%20int,%20int,%20int,%20int)
  ImageSource.binary(ByteData data, {int rotation = 0})
      : data = [data.buffer.asUint8List(), rotation];

  /// Directly forwarded to
  /// https://developers.google.com/android/reference/com/google/mlkit/vision/common/InputImage#fromFilePath(android.content.Context,%20android.net.Uri)
  // ignore: prefer_initializing_formals
  ImageSource.path(String path) : data = path;

  /// Opens a native picker
  ImageSource.picker() : data = null;

  final dynamic data;
}
