package com.jhoogstraat.fast_barcode_scanner.types

import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.util.*
import kotlin.collections.HashMap

sealed class ScannerError : Throwable() {
    class NotInitialized : ScannerError()
    class NotRunning : ScannerError()
    class AlreadyRunning : ScannerError()
    class NoInputDeviceForConfig(val configuration: ScannerConfiguration) : ScannerError()
    class CameraNotSuitable(val resolution: Resolution, val framerate: Framerate) : ScannerError()
    class Unauthorized : ScannerError()
    class ConfigurationError(val error: Exception) : ScannerError()
    class InvalidArguments(val args: HashMap<String, Any>) : ScannerError()
    class InvalidCodeType(val type: String) : ScannerError()
    class LoadingFailed(val error: IOException) : ScannerError()
    class AnalysisFailed(val error: Exception) : ScannerError()

    /* Android specific */
    class ActivityNotConnected : ScannerError()

    fun throwFlutterError(result: Result) {
        return when(this) {
            is NotInitialized -> result.error("NOT_INITIALIZED", "Camera has not been initialized", null)
            is NotRunning -> result.error("NOT_RUNNING", "Camera is not running", null)
            is AlreadyRunning -> result.error("ALREADY_RUNNING", "Camera is already running", null)
            is CameraNotSuitable -> result.error("CAMERA_NOT_SUITABLE", "The camera does not support the requested resolution and framerate combination", "$resolution $framerate")
            is ConfigurationError -> result.error("CONFIGURATION_FAILED", "The configuration could not be applied", error.localizedMessage)
            is NoInputDeviceForConfig -> result.error("NO_INPUT_DEVICE", "No input device found for configuration. Are you using a simulator?", "$configuration")
            is Unauthorized -> result.error("UNAUTHORIZED", "The application is not authorized to use the camera device", null)
            is InvalidArguments -> result.error("INVALID_ARGUMENT", "Invalid arguments provided", args)
            is InvalidCodeType -> result.error("INVALID_CODE", "Invalid code type", type)
            is ActivityNotConnected -> result.error("NO_ACTIVITY", "No activity is connected", null)
            is LoadingFailed -> result.error("LOADING_FAILED", "Could not load asset", error.localizedMessage)
            is AnalysisFailed -> result.error("ANALYSIS_FAILED", "Could not analyse asset", error.localizedMessage)
        }
    }
}