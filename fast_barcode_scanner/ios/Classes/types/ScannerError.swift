import Flutter

extension Error {
    var flutterError: FlutterError {
        if let error = self as? ScannerError {
            return error.flutterError
        } else {
            return FlutterError(code: "UNEXPECTED_ERROR",
                                message: "Unknown error occured.",
                                details: nil)
        }
    }
}

enum ScannerError: Error {
    case notInitialized
    case alreadyInitialized
    case notRunning
    case alreadyRunning
    case noInputDeviceForConfig(ScannerConfiguration)
    case cameraNotSuitable(Resolution, Framerate)
    case unauthorized
    case configurationError(String)
    case invalidArguments(Any?)
    case invalidCodeType(String)
    case loadingFailed
    case analysisFailed(Error)
    case minimumTarget
    case loadingURLFailed(String)
    case loadingDataFailed

    var flutterError: FlutterError {
        switch self {
        case .notInitialized:
            return FlutterError(code: "NOT_INITIALIZED",
                                message: "Camera has not been initialized",
                                details: nil)
        case .alreadyInitialized:
            return FlutterError(code: "ALREADY_INITIALIZED",
                                message: "Camera is already initialized",
                                details: nil)
        case .notRunning:
            return FlutterError(code: "NOT_RUNNING",
                                message: "Camera is not running",
                                details: nil)
        case .alreadyRunning:
            return FlutterError(code: "ALREADY_RUNNING",
                                message: "Camera is already running",
                                details: nil)
        case .cameraNotSuitable(let res, let fps):
            return FlutterError(code: "CAMERA_NOT_SUITABLE",
                                message: """
                                    The camera does not support the requested resolution (\(res)) \
                                    and framerate (\(fps)) combination
                                    """,
                                details: "Try to lower your settings")
        case .configurationError(let error):
            return FlutterError(code: "CONFIGURATION_FAILED",
                                message: "Configuration failed (\(error))",
                                details: nil)
        case .noInputDeviceForConfig(let config):
            return FlutterError(code: "NO_INPUT_DEVICE",
                                message: "No input device found for configuration (\(config)",
                                details: "Are you using a simulator?")
        case .unauthorized:
            return FlutterError(code: "UNAUTHORIZED",
                                message: "The application is not authorized to use the camera device",
                                details: nil)
        case .invalidArguments(let args):
            return FlutterError(code: "INVALID_ARGUMENT",
                                message: "Invalid arguments provided (\(String(describing: args)))",
                                details: nil)
        case .invalidCodeType(let type):
            return FlutterError(code: "INVALID_CODE",
                                message: "Invalid code type \(type)",
                                details: nil)
        case .loadingFailed:
            return FlutterError(code: "LOADING_FAILED",
                                message: "Could not load asset",
                                details: nil)
        case .analysisFailed(let error):
            return FlutterError(code: "ANALYSIS_FAILED",
                                message: "Could not analyse asset",
                                details: error.localizedDescription)
        case .minimumTarget:
            return FlutterError(code: "MINIMUM_TARGET",
                                message: "iOS 11 or higher required",
                                details: nil)
        case .loadingURLFailed(let url):
            return FlutterError(code: "LOADING_URL_FAILED",
                                message: "Loading image from url failed",
                                details: url)
        case .loadingDataFailed:
            return FlutterError(code: "LOADING_DATA_FAILED",
                                message: "Loading image from data failed",
                                details: nil)
        }
    }
}
