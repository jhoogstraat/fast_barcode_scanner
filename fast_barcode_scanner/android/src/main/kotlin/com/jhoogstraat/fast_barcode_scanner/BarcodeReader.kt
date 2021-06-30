package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.content.pm.PackageManager
import android.content.res.Resources
import android.util.DisplayMetrics
import android.util.Log
import android.util.Rational
import android.view.Display
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import io.flutter.embedding.android.FlutterActivity

import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.util.ArrayList
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

data class CameraConfig(val formats: IntArray, val mode: DetectionMode, val resolution: Resolution, val framerate: Framerate, val position: CameraPosition)

class BarcodeReader(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry, private val listener: (List<Barcode>) -> Unit) : RequestPermissionsResultListener {
    /* Android Lifecycle */
    private var activity: FlutterActivity? = null

    /* Camera */
    private lateinit var camera: Camera
    private lateinit var cameraConfig: CameraConfig
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider
    private lateinit var usecases: UseCaseGroup

    /* ML Kit */
    private lateinit var barcodeDetector: MLKitBarcodeDetector

    /* State */
    private var isInitialized = false
    private var pauseDetection = false

    fun attachToActivity(activity: FlutterActivity) {
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
            initCamera(result)
        } else {
            // Requires API Level 23
            //activity?.requestPermissions(REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
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
        camera.cameraControl.enableTorch(camera.cameraInfo.torchState.value != TorchState.ON).addListener({
            result.success(camera.cameraInfo.torchState.value == TorchState.ON)
        }, ContextCompat.getMainExecutor(activity))
    }

    fun changeConfiguration(args: HashMap<String, Any>, result: Result) {
        val formats = if (args.containsKey("types")) (args["types"] as ArrayList<String>).map { barcodeFormatMap[it]!! }.toIntArray() else cameraConfig.formats
        val detectionMode = if (args.containsKey("mode")) DetectionMode.valueOf(args["mode"] as String) else cameraConfig.mode
        val resolution = if (args.containsKey("res")) Resolution.valueOf(args["res"] as String) else cameraConfig.resolution
        val framerate = if (args.containsKey("fps")) Framerate.valueOf(args["fps"] as String) else cameraConfig.framerate
        val position = if (args.containsKey("pos")) CameraPosition.valueOf(args["pos"] as String) else cameraConfig.position

        cameraConfig = cameraConfig.copy(formats = formats,
            mode = detectionMode,
            resolution = resolution,
            framerate = framerate,
            position = position
        )

        initCamera(result)
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(activity!!.applicationContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                initCamera(null)
            }
        }

        return true
    }

    private fun initCamera(result: Result?) {
        val options = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(0, *cameraConfig.formats)
                .build()

        barcodeDetector = MLKitBarcodeDetector(options, { codes ->
            if (!pauseDetection && codes.isNotEmpty()) {
                if (cameraConfig.mode == DetectionMode.pauseDetection) {
                    pauseDetection = true
                } else if (cameraConfig.mode == DetectionMode.pauseVideo) {
                    stop()
                }

                listener(codes)
            }
        }, {
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
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, {})
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity!!)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            isInitialized = true
            try { bindCameraUseCases() }
            catch (exc: Exception) { Log.e(TAG, "Use case binding failed", exc) }
            result?.let {
                val res = (usecases.useCases.first() as Preview).resolutionInfo!!
                Log.d(TAG, "initCamera: ${res.resolution} ${res.cropRect.width()}x${res.cropRect.height()}")
                it.success(hashMapOf("textureId" to flutterTextureEntry.id(), "orientation" to 0, "height" to res.cropRect.height(), "width" to res.cropRect.width()))
            }
        }, ContextCompat.getMainExecutor(activity!!))
    }

    private fun bindCameraUseCases() {
        val preview = Preview.Builder()
                .setTargetResolution(cameraConfig.resolution.size())
                .setTargetRotation(Surface.ROTATION_90)
                .build()

        val imageAnalyzer = ImageAnalysis.Builder()
                .setTargetResolution(cameraConfig.resolution.size())
                .setTargetRotation(Surface.ROTATION_90)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { it.setAnalyzer(cameraExecutor, barcodeDetector) }

        val metrics = DisplayMetrics()
        activity!!.windowManager.defaultDisplay.getRealMetrics(metrics);

        Log.d(TAG, "bindCameraUseCases: ${metrics.widthPixels}x${metrics.heightPixels}")

        usecases = UseCaseGroup.Builder()
                .addUseCase(preview)
                .addUseCase(imageAnalyzer)
                .setViewPort(ViewPort.Builder(Rational(metrics.widthPixels, metrics.heightPixels), Surface.ROTATION_90).build())
                .build()

        // As required by CameraX, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()

        // Bind camera to Lifecycle
        camera = cameraProvider.bindToLifecycle(activity!!, cameraSelector, usecases)

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)

        // Make sure detections are allowed
        pauseDetection = false
    }

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

}