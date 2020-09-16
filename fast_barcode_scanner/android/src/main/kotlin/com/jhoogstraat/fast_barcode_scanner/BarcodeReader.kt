package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.core.util.Consumer
import androidx.lifecycle.Lifecycle
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import io.flutter.embedding.android.FlutterActivity

import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.TextureRegistry
import java.util.ArrayList
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

data class CameraConfig(val formats: IntArray, val mode: DetectionMode, val resolution: Resolution, val framerate: Framerate)

class BarcodeReader(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry, private val listener: (List<Barcode>) -> Unit) : PluginRegistry.RequestPermissionsResultListener {
    /* Android Lifecycle */
    private var activity: FlutterActivity? = null
    private var lifecycle: Lifecycle? = null

    /* Use Cases */
    private lateinit var previewUseCase: Preview
    private lateinit var analysisUseCase: ImageAnalysis

    /* Camera */
    private lateinit var camera: Camera
    private lateinit var cameraConfig: CameraConfig
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider

    /* ML Kit */
    private lateinit var imageProcessor: MLKitBarcodeDetector

    /* State */
    private var isInitialized = false

    fun attachToActivity(activity: FlutterActivity, lifecycle: Lifecycle) {
        this.activity = activity
        this.lifecycle = lifecycle
    }

    fun detachFromActivity() {
        stop(null)
        this.activity = null
        this.lifecycle = null
    }

    fun start(args: HashMap<String, Any>, result: Result) {
        // Make sure we are connected to an activity
        if (activity == null)
            return result.error("0", "Activity not connected!", null)

        // Stop running camera and start new
        stop(null)

        // Reset init state.
        isInitialized = false

        // Convert arguments to CameraConfig
        cameraConfig = CameraConfig(
                (args["types"] as ArrayList<String>).map { barcodeFormatMap[it]!! }.toIntArray(),
                DetectionMode.valueOf(args["mode"] as String),
                Resolution.valueOf(args["res"] as String),
                Framerate.valueOf(args["fps"] as String)
        )

        if (allPermissionsGranted()) {
            initCamera()
        } else {
            activity?.requestPermissions(REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }

        result.success(hashMapOf("textureId" to flutterTextureEntry.id(), "surfaceOrientation" to 0, "surfaceHeight" to 1280, "surfaceWidth" to 720))
    }

    fun stop(result: Result? = null) {
        if (!isInitialized) return
        cameraProvider.unbindAll()
        result?.success(null)
    }

    fun resume(result: Result) {
        if (!isInitialized) return
        bindCameraUseCases()
        result.success(null)
    }

    fun toggleTorch(result: Result) {
        if (!isInitialized) return
        camera.cameraControl.enableTorch(camera.cameraInfo.torchState.value != TorchState.ON).addListener(Runnable {
            result.success(camera.cameraInfo.torchState.value == TorchState.ON)
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(activity!!.applicationContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                initCamera()
            }
        }

        return true
    }

    private fun initCamera() {
        // Init barcode Detector
        val options = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_UNKNOWN, *cameraConfig.formats)
                .build()

        imageProcessor = MLKitBarcodeDetector(options, OnSuccessListener { barcodes ->
            if (cameraConfig.mode.pause() && barcodes.isNotEmpty()) { stop() }
            listener(barcodes)
        }, OnFailureListener {
            Log.e(TAG, "Error in MLKit", it)
        })

        // Select back camera
        cameraSelector = CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                .build()

        // Create Camera Thread
        cameraExecutor = Executors.newSingleThreadExecutor()

        // Setup Surface
        cameraSurfaceProvider = Preview.SurfaceProvider {
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(it.resolution.width, it.resolution.height)
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, Consumer<SurfaceRequest.Result> {})
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity!!)
        cameraProviderFuture.addListener(Runnable {
            cameraProvider = cameraProviderFuture.get()
            isInitialized = true
            try { bindCameraUseCases() }
            catch (exc: Exception) { Log.e(TAG, "Use case binding failed", exc) }
        }, ContextCompat.getMainExecutor(activity!!))
    }

    private fun buildPreviewUseCase() : Preview {
        previewUseCase = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                //.setTargetResolution(cameraConfig.resolution.size())
                .setTargetRotation(Surface.ROTATION_90)
                .build()

        previewUseCase.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)

        return previewUseCase
    }

    private fun buildAnalysisUseCase() : ImageAnalysis {
        val analyserBuilder = ImageAnalysis.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                // .setTargetResolution(cameraConfig.resolution.size())
                .setTargetRotation(Surface.ROTATION_90)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)

        // Set Framerate via Camera2 Interop
        // val interop = Camera2Interop.Extender(analyserBuilder)
        // interop.setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(cameraConfig.framerate.intValue(), cameraConfig.framerate.intValue()))

        analysisUseCase = analyserBuilder.build()
                .also { it.setAnalyzer(Executors.newSingleThreadExecutor(), imageProcessor) }

        return analysisUseCase
    }

    private fun bindCameraUseCases() {
        // As required by CameraX API, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()
        camera = cameraProvider.bindToLifecycle(activity!!, cameraSelector, buildPreviewUseCase(), buildAnalysisUseCase())
    }

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

}