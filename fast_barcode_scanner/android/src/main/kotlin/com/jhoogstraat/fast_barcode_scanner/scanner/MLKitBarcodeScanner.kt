package com.jhoogstraat.fast_barcode_scanner.scanner

import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.io.Closeable
import java.util.concurrent.Executor

class MLKitBarcodeScanner(
    options: BarcodeScannerOptions,
    private val mainExecutor: Executor,
    private val onBarcodes: (List<Barcode>) -> Unit,
    private val onFailure: (Exception) -> Unit
) : ImageAnalysis.Analyzer, Closeable {
    private val scanner: BarcodeScanner = BarcodeScanning.getClient(options)
    private val lock = Any()
    private val directExecutor = Executor { it.run() }
    private var isClosed = false

    @ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val task = synchronized(lock) {
            if (isClosed) {
                imageProxy.close()
                return
            }
            try {
                val inputImage = InputImage.fromMediaImage(
                    mediaImage,
                    imageProxy.imageInfo.rotationDegrees
                )
                scanner.process(inputImage)
            } catch (e: Exception) {
                imageProxy.close()
                onFailure(e)
                return
            }
        }

        task
            .addOnSuccessListener(directExecutor) { codes ->
                if (codes.isNotEmpty()) {
                    mainExecutor.execute { onBarcodes(codes) }
                }
            }
            .addOnFailureListener(directExecutor) { onFailure(it) }
            .addOnCompleteListener(directExecutor) { imageProxy.close() }
    }

    override fun close() {
        synchronized(lock) {
            if (!isClosed) {
                isClosed = true
                scanner.close()
            }
        }
    }
}
