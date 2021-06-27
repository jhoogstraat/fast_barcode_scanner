//
//  ScannerError.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 27.06.21.
//

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
    case notRunning
    case notInitialized
    case alreadyRunning
    case noInputDeviceForConfig(CameraConfiguration)
    case cameraNotSuitable(Resolution, Framerate)
    case unauthorized
    case configurationLockError(Error)
    case invalidArguments(Any?)
    
    var flutterError: FlutterError {
        switch self {
        case .notInitialized:
            return FlutterError(code: "NOT_INITIALIZED",
                                message: "Camera has not been initialized",
                                details: nil)
        case .notRunning:
            return FlutterError(code: "NOT_RUNNING",
                                message: "Camera cannot be changed when not running",
                                details: nil)
        case .alreadyRunning:
            return FlutterError(code: "ALREADY_RUNNING",
                                message: "Start cannot be called when already running",
                                details: nil)
        case .cameraNotSuitable(let res, let fps):
            return FlutterError(code: "CAMERA_NOT_SUITABLE",
                                message: """
                                    The camera does not support the requested resolution (\(res)) \
                                    and framerate (\(fps)) combination
                                    """,
                                details: "Try to lower your settings")
        case .configurationLockError(let error):
            return FlutterError(code: "CONFIGURATION_FAILED",
                                message: "The configuration could not be applied (\(error))",
                                details: nil)
        case .noInputDeviceForConfig(let config):
            return FlutterError(code: "AV_NO_INPUT_DEVICE",
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
        }
    }
}
