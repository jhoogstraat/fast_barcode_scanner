package com.jhoogstraat.fast_barcode_scanner.scanner

import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.io.Closeable

class MLKitBarcodeScanner(
    options: BarcodeScannerOptions,
    private val successListener: OnSuccessListener<List<Barcode>>,
    private val failureListener: OnFailureListener
) : ImageAnalysis.Analyzer, Closeable {
    private val scanner: BarcodeScanner = BarcodeScanning.getClient(options)

    @Volatile
    private var isClosed = false

    @ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (isClosed || mediaImage == null) {
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees
        )

        scanner.process(inputImage)
            .addOnSuccessListener(successListener)
            .addOnFailureListener(failureListener)
            .addOnCompleteListener { imageProxy.close() }
    }

    override fun close() {
        if (!isClosed) {
            isClosed = true
            scanner.close()
        }
    }
}
