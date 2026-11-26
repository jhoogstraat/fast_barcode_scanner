struct CameraInformation {
  let videoWidth: Int32
  let videoHeight: Int32
  let sensorOrientation: Int
  let minZoom: Double
  let maxZoom: Double

  var serialized: [String: Any] {
    let w = Double(videoWidth)
    let h = Double(videoHeight)
    return [
      "video_size": [w, h],
      "analysis_frame": [0.0, 0.0, w, h],
      "sensor_orientation": sensorOrientation,
      "min_zoom": minZoom,
      "max_zoom": maxZoom,
    ]
  }
}
