package com.jhoogstraat.fast_barcode_scanner.types

import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException

sealed class ScannerException(
    val code: String,
    val errorMessage: String,
    val details: Any? = null
) : Exception(errorMessage) {
    class NotInitialized : ScannerException("NOT_INITIALIZED", "Camera has not been initialized")
    class NotRunning : ScannerException("NOT_RUNNING", "Camera is not running")
    class Unauthorized : ScannerException(
        "UNAUTHORIZED",
        "The application is not authorized to use the camera device"
    )
    class ActivityNotConnected : ScannerException("NO_ACTIVITY", "No activity is connected")
    class InvalidImageData : ScannerException(
        "INVALID_IMAGEDATA",
        "Could not parse image byte array"
    )
    class AlreadyPicking : ScannerException("ALREADY_PICKING", "Already picking an image to analyze")
    class NoInputDeviceForConfig(configuration: ScannerConfiguration) : ScannerException(
        "NO_INPUT_DEVICE",
        "No input device found for configuration. Are you using an emulator without a camera?",
        configuration.toString()
    )
    class ConfigurationException(error: Exception) : ScannerException(
        "CONFIGURATION_FAILED",
        "The configuration could not be applied",
        error.localizedMessage
    )
    class InvalidArguments(args: Any?) : ScannerException(
        "INVALID_ARGUMENT",
        "Invalid arguments provided",
        args?.toString()
    )
    class LoadingFailed(error: IOException) : ScannerException(
        "LOADING_FAILED",
        "Could not load image",
        error.localizedMessage
    )
    class Unknown(error: Exception) : ScannerException(
        "UNKNOWN",
        "Unknown error occurred",
        error.localizedMessage
    )

    fun throwFlutterError(result: Result) {
        result.error(code, errorMessage, details)
    }
}
