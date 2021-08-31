package com.jhoogstraat.fast_barcode_scanner.types

import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException

sealed class ScannerException : Exception() {
    class NotInitialized : ScannerException()
    class AlreadyInitialized : ScannerException()
    class NotRunning : ScannerException()
    class AlreadyRunning : ScannerException()
    class NoInputDeviceForConfig(val configuration: ScannerConfiguration) : ScannerException()
    class Unauthorized : ScannerException()
    class ConfigurationException(val error: Exception) : ScannerException()
    class InvalidArguments(val args: HashMap<String, Any>) : ScannerException()
    class InvalidCodeType(val type: String) : ScannerException()
    class LoadingFailed(val error: IOException) : ScannerException()
    class AnalysisFailed(val error: Exception) : ScannerException()
    class AlreadyPicking() : ScannerException()
    class Unknown(val error: Exception) : ScannerException()
    class CameraNotSuitable(val resolution: Resolution, val framerate: Framerate) :
        ScannerException()

    /* Android specific */
    class ActivityNotConnected : ScannerException()

    fun throwFlutterError(result: Result) {
        return when (this) {
            is AlreadyInitialized -> result.error(
                "ALREADY_INITIALIZED",
                "Camera is already initialized",
                null
            )
            is NotInitialized -> result.error(
                "NOT_INITIALIZED",
                "Camera has not been initialized",
                null
            )
            is NotRunning -> result.error("NOT_RUNNING", "Camera is not running", null)
            is AlreadyRunning -> result.error("ALREADY_RUNNING", "Camera is already running", null)
            is CameraNotSuitable -> result.error(
                "CAMERA_NOT_SUITABLE",
                "The camera does not support the requested resolution and framerate combination",
                "$resolution $framerate"
            )
            is ConfigurationException -> result.error(
                "CONFIGURATION_FAILED",
                "The configuration could not be applied",
                error.localizedMessage
            )
            is NoInputDeviceForConfig -> result.error(
                "NO_INPUT_DEVICE",
                "No input device found for configuration. Are you using a simulator?",
                "$configuration"
            )
            is Unauthorized -> result.error(
                "UNAUTHORIZED",
                "The application is not authorized to use the camera device",
                null
            )
            is InvalidArguments -> result.error(
                "INVALID_ARGUMENT",
                "Invalid arguments provided",
                args
            )
            is InvalidCodeType -> result.error("INVALID_CODE", "Invalid code type", type)
            is ActivityNotConnected -> result.error("NO_ACTIVITY", "No activity is connected", null)
            is LoadingFailed -> result.error(
                "LOADING_FAILED",
                "Could not load asset",
                error.localizedMessage
            )
            is AnalysisFailed -> result.error(
                "ANALYSIS_FAILED",
                "Could not analyse asset",
                error.localizedMessage
            )
            is AlreadyPicking -> result.error(
                "ALREADY_PICKING",
                "Already picking an image to analyze",
                null
            )
            is Unknown -> result.error(
                "UNKNOWN",
                "Unknown error occurred",
                error.localizedMessage
            )
        }
    }
}