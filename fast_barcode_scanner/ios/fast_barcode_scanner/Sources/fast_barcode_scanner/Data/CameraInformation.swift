struct CameraInformation {
  let videoWidth: Int32
  let videoHeight: Int32
  let analysisWidth: Double
  let analysisHeight: Double
  let sensorOrientation: Int
  let minZoom: Double
  let maxZoom: Double

  init(
    videoWidth: Int32,
    videoHeight: Int32,
    analysisWidth: Int32,
    analysisHeight: Int32,
    sensorOrientation: Int = 90,
    minZoom: Double = 1.0,
    maxZoom: Double = 1.0
  ) {
    self.videoWidth = videoWidth
    self.videoHeight = videoHeight
    self.analysisWidth = Double(analysisWidth)
    self.analysisHeight = Double(analysisHeight)
    self.sensorOrientation = sensorOrientation
    self.minZoom = minZoom
    self.maxZoom = maxZoom
  }

  var serialized: [String: Any] {
    let offsetX = max(0, Double(videoWidth) - analysisWidth)
    let offsetY = max(0, Double(videoHeight) - analysisHeight)

    return [
      "video_size": [Double(videoWidth), Double(videoHeight)],
      "analysis_frame": [offsetX / 2.0, offsetY / 2.0, analysisWidth, analysisHeight],
      "sensor_orientation": sensorOrientation,
      "min_zoom": minZoom,
      "max_zoom": maxZoom,
    ]
  }
}
