package com.jhoogstraat.fast_barcode_scanner.types

import android.util.Size
import com.google.mlkit.vision.barcode.common.Barcode

data class ScannerConfiguration(
    val types: IntArray,
    val mode: PerformanceMode,
    val position: CameraPosition,
    val detectionMode: DetectionMode
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ScannerConfiguration) return false
        return types.contentEquals(other.types) &&
            mode == other.mode &&
            position == other.position &&
            detectionMode == other.detectionMode
    }

    override fun hashCode(): Int {
        var result = types.contentHashCode()
        result = 31 * result + mode.hashCode()
        result = 31 * result + position.hashCode()
        result = 31 * result + detectionMode.hashCode()
        return result
    }
}

enum class PerformanceMode(val wireName: String) {
    System("system"),
    Economic("economic"),
    High("high");

    fun targetSize(): Size = when (this) {
        Economic -> Size(1280, 720)
        System -> Size(1920, 1080)
        High -> Size(3840, 2160)
    }

    companion object {
        fun fromString(value: String?): PerformanceMode =
            entries.firstOrNull { it.wireName == value }
                ?: throw IllegalArgumentException("Unknown PerformanceMode: $value")
    }
}

enum class DetectionMode(val wireName: String) {
    PauseDetection("pauseDetection"),
    PauseVideo("pauseVideo"),
    Continuous("continuous");

    companion object {
        fun fromString(value: String?): DetectionMode =
            entries.firstOrNull { it.wireName == value }
                ?: throw IllegalArgumentException("Unknown DetectionMode: $value")
    }
}

enum class CameraPosition(val wireName: String) {
    Front("front"),
    Back("back");

    companion object {
        fun fromString(value: String?): CameraPosition =
            entries.firstOrNull { it.wireName == value }
                ?: throw IllegalArgumentException("Unknown CameraPosition: $value")
    }
}

val barcodeFormatMap: Map<String, Int> = hashMapOf(
    "aztec" to Barcode.FORMAT_AZTEC,
    "code128" to Barcode.FORMAT_CODE_128,
    "code39" to Barcode.FORMAT_CODE_39,
    "code93" to Barcode.FORMAT_CODE_93,
    "codabar" to Barcode.FORMAT_CODABAR,
    "dataMatrix" to Barcode.FORMAT_DATA_MATRIX,
    "ean13" to Barcode.FORMAT_EAN_13,
    "ean8" to Barcode.FORMAT_EAN_8,
    "itf" to Barcode.FORMAT_ITF,
    "pdf417" to Barcode.FORMAT_PDF417,
    "qr" to Barcode.FORMAT_QR_CODE,
    "upcA" to Barcode.FORMAT_UPC_A,
    "upcE" to Barcode.FORMAT_UPC_E
)

val barcodeStringMap: Map<Int, String> =
    barcodeFormatMap.entries.associateBy({ it.value }) { it.key }
