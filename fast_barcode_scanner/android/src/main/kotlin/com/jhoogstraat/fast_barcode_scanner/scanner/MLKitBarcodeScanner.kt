package com.jhoogstraat.fast_barcode_scanner.scanner

import android.content.Context
import android.net.Uri
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

class MLKitBarcodeScanner(
        options: BarcodeScannerOptions,
        private val successListener: OnSuccessListener<List<Barcode>>,
        private val failureListener: OnFailureListener
) : ImageAnalysis.Analyzer {
    private val scanner = BarcodeScanning.getClient(options)

    @ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        scanner.process(InputImage.fromMediaImage(imageProxy.image!!, imageProxy.imageInfo.rotationDegrees))
                .addOnSuccessListener(successListener)
                .addOnFailureListener(failureListener)
                .addOnCompleteListener { imageProxy.close() }
    }

    fun analyze(image: InputImage) : Task<List<Barcode>> {
        return scanner.process(image)
    }

    fun analyze(context: Context, uri: Uri) : Task<List<Barcode>> {
        return scanner.process(InputImage.fromFilePath(context, uri))
    }
}