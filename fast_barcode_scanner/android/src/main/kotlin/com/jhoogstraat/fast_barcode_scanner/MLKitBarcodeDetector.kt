package com.jhoogstraat.fast_barcode_scanner

import android.annotation.SuppressLint
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage

class MLKitBarcodeDetector(
        private val options: BarcodeScannerOptions,
        private val successListener: OnSuccessListener<List<Barcode>>,
        private val failureListener: OnFailureListener
) : ImageAnalysis.Analyzer {
    private val scanner = BarcodeScanning.getClient(options)
    private var runningTask: Task<List<Barcode>>? = null

    @ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image

        // runningTask?.isComplete == true
        if (mediaImage != null) {
            val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees);
            runningTask = scanner.process(inputImage)
                    .addOnSuccessListener(successListener)
                    .addOnFailureListener(failureListener)
                    .addOnCompleteListener { imageProxy.close() }
        }
    }
}