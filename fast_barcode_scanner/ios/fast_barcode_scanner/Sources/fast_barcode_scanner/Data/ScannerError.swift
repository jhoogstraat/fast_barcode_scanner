import Flutter

extension Error {
  var flutterError: FlutterError {
    if let error = self as? ScannerError {
      return error.flutterError
    }
    return FlutterError(code: "UNEXPECTED_ERROR", message: localizedDescription, details: nil)
  }
}

enum ScannerError: Error {
  case notInitialized
  case noInputDeviceForConfig(CameraConfiguration)
  case unauthorized
  case configurationError(String)
  case invalidArguments(Any?)
  case analysisFailed(Error)
  case loadingDataFailed

  var flutterError: FlutterError {
    switch self {
    case .notInitialized:
      return FlutterError(
        code: "NOT_INITIALIZED", message: "Camera has not been initialized", details: nil)
    case .configurationError(let error):
      return FlutterError(
        code: "CONFIGURATION_FAILED", message: "Configuration failed (\(error))", details: nil)
    case .noInputDeviceForConfig(let config):
      return FlutterError(
        code: "NO_INPUT_DEVICE",
        message: "No input device found for configuration (\(config.position))",
        details: "Are you running on a simulator without a camera?")
    case .unauthorized:
      return FlutterError(
        code: "UNAUTHORIZED",
        message: "The application is not authorized to use the camera device",
        details: nil)
    case .invalidArguments(let args):
      return FlutterError(
        code: "INVALID_ARGUMENT",
        message: "Invalid arguments provided (\(String(describing: args)))",
        details: nil)
    case .analysisFailed(let error):
      return FlutterError(
        code: "ANALYSIS_FAILED",
        message: "Could not analyze image",
        details: error.localizedDescription)
    case .loadingDataFailed:
      return FlutterError(
        code: "LOADING_DATA_FAILED", message: "Loading image from data failed", details: nil)
    }
  }
}
