package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.util.Consumer
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions

import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.util.ArrayList
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

data class CameraConfig(val formats: IntArray, val mode: DetectionMode, val resolution: Resolution, val framerate: Framerate, val position: CameraPosition)

class BarcodeReader(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry, private val listener: (List<Barcode>) -> Unit) : RequestPermissionsResultListener {
    /* Android Lifecycle */
    private var activity: Activity? = null

    /* Camera */
    private lateinit var camera: Camera
    private lateinit var cameraConfig: CameraConfig
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider

    /* ML Kit */
    private lateinit var barcodeDetector: MLKitBarcodeDetector

    /* State */
    private var isInitialized = false
    private var pauseDetection = false
    private var pendingResult: Result? = null

    fun attachToActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachFromActivity() {
        stop(null)
        this.activity = null
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
                Framerate.valueOf(args["fps"] as String),
                CameraPosition.valueOf(args["pos"] as String)
        )

        if (allPermissionsGranted()) {
            initCamera()
            result.success(hashMapOf("textureId" to flutterTextureEntry.id(), "surfaceOrientation" to 0, "surfaceHeight" to 1280, "surfaceWidth" to 720))
        } else {
            pendingResult = result
            ActivityCompat.requestPermissions(
                activity!!,
                REQUIRED_PERMISSIONS,
                REQUEST_CODE_PERMISSIONS
            )
        }
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
            } else {
                pendingResult?.let {
                    it.error("UNAUTHORIZED", "The application is not authorized to use the camera device", null)
                    pendingResult = null
                }
            }
        }

        return true
    }

    private fun initCamera() {
        // Init barcode Detector
        val options = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(0, *cameraConfig.formats)
                .build()

        barcodeDetector = MLKitBarcodeDetector(options, OnSuccessListener { codes ->
            if (!pauseDetection && codes.isNotEmpty()) {
                if (cameraConfig.mode == DetectionMode.pauseDetection) {
                    pauseDetection = true
                } else if (cameraConfig.mode == DetectionMode.pauseVideo) {
                    stop()
                }

                listener(codes)
            }
        }, OnFailureListener {
            Log.e(TAG, "Error in MLKit", it)
        })

        // Select camera
        val selectorBuilder = CameraSelector.Builder()
        when (cameraConfig.position) {
            CameraPosition.front -> {
                selectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            }
            CameraPosition.back -> {
                selectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_BACK)
            }
        }
        cameraSelector = selectorBuilder.build()

        // Create Camera Thread
        cameraExecutor = Executors.newSingleThreadExecutor()

        // Setup Surface
        cameraSurfaceProvider = Preview.SurfaceProvider {
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(it.resolution.width, it.resolution.height)
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, Consumer {})
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity!!)
        cameraProviderFuture.addListener(Runnable {
            cameraProvider = cameraProviderFuture.get()
            isInitialized = true
            try { bindCameraUseCases() }
            catch (exc: Exception) { Log.e(TAG, "Use case binding failed", exc) }
        }, ContextCompat.getMainExecutor(activity!!))
    }

    private fun bindCameraUseCases() {
        // Preview
        val preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                //.setTargetResolution(cameraConfig.resolution.size())
                .setTargetRotation(Surface.ROTATION_90)
                .build()

        val imageAnalyzer = ImageAnalysis.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                // .setTargetResolution(cameraConfig.resolution.size())
                .setTargetRotation(Surface.ROTATION_90)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
//                .also {
//                    Set Framerate via Camera2 Interop
//                    val interop = Camera2Interop.Extender(analyserBuilder)
//                    interop.setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(cameraConfig.framerate.intValue(), cameraConfig.framerate.intValue()))
//                }
                .build()
                .also { it.setAnalyzer(cameraExecutor, barcodeDetector) }

        // As required by CameraX, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)

        // Bind camera to Lifecycle
        camera = cameraProvider.bindToLifecycle(activity!! as LifecycleOwner, cameraSelector, preview, imageAnalyzer)

        // Make sure detections are allowed
        pauseDetection = false
    }

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

}