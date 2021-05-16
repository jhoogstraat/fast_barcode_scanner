/// Supported resolutions. Not all devices support all resolutions!
enum Resolution { sd480, hd720, hd1080, hd4k }

/// Supported Framerates. Not all devices support all framerates!
enum Framerate { fps30, fps60, fps120, fps240 }

enum DetectionMode {
  /// Pauses the detection of further barcodes when a barcode is detected.
  pauseDetection,

  /// Pauses the camera feed on detection.
  pauseVideo,

  /// Does nothing on detection. May need to throttle detections using continuous.
  continuous
}

/// The position of the camera.
enum CameraPosition { front, back }

/// The configuration by which the camera feed can be laid out in the UI.
class PreviewConfiguration {
  /// The width of the camera feed in points.
  final int width;

  /// The height of the camera feed in points.
  final int height;

  /// The orientation of the camera feed.
  final num sensorOrientation;

  /// A id of a texture which contains the camera feed.
  ///
  /// Can be consumed by a [Texture] widget.
  final int textureId;

  PreviewConfiguration(Map<dynamic, dynamic> response)
      : textureId = response["textureId"],
        sensorOrientation = response["surfaceOrientation"],
        height = response["surfaceHeight"],
        width = response["surfaceWidth"];
}
