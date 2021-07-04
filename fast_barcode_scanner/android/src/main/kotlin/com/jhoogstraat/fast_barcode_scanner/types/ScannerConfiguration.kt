package com.jhoogstraat.fast_barcode_scanner.types

import android.util.Size
import com.google.mlkit.vision.barcode.Barcode

data class ScannerConfiguration(val formats: IntArray, val mode: DetectionMode, val resolution: Resolution, val framerate: Framerate, val position: CameraPosition)

enum class Framerate {
    fps30, fps60, fps120, fps240;

    fun intValue() : Int = when(this) {
        fps30 -> 30
        fps60 -> 60
        fps120 -> 120
        fps240 -> 240
    }

    fun duration() : Long = 1 / intValue().toLong()
}

enum class Resolution {
    sd480, hd720, hd1080, hd4k;

    private fun width() : Int = when(this) {
        sd480 -> 640
        hd720 -> 1280
        hd1080 -> 1920
        hd4k -> 3840
    }

    private fun height() : Int = when(this) {
        sd480 -> 480
        hd720 -> 720
        hd1080 -> 1080
        hd4k -> 2160
    }

    fun landscape() : Size = Size(width(), height())
    fun portrait() : Size = Size(height(), width())
}

enum class DetectionMode {
    pauseDetection, pauseVideo, continuous;
}

enum class CameraPosition {
    front, back;
}

val barcodeFormatMap = hashMapOf(
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

val barcodeStringMap = barcodeFormatMap.entries.associateBy({ it.value }) { it.key }