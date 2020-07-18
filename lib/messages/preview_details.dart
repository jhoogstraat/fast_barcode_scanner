enum Resolution { sd480, hd720, hd1080, hd4k }

enum Framerate { fps30, fps60, fps120, fps240 }

enum DetectionMode { pauseDetection, pauseDetectionAndVideo, continuous }

class PreviewDetails {
  final int width;
  final int height;
  final num sensorOrientation;
  final int textureId;

  PreviewDetails(Map<dynamic, dynamic> response)
      : textureId = response["textureId"],
        sensorOrientation = response["surfaceOrientation"],
        height = response["surfaceHeight"],
        width = response["surfaceWidth"];
}
