package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.jhoogstraat.fast_barcode_scanner.types.*
import io.flutter.embedding.android.FlutterActivity

import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.collections.HashMap

class BarcodeScanner(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry, private val listener: (List<Barcode>) -> Unit) : RequestPermissionsResultListener {
    /* Android Lifecycle */
    private var activity: FlutterActivity? = null

    /* Scanner configuration */
    private lateinit var scannerConfiguration: ScannerConfiguration
    private lateinit var previewConfiguration: PreviewConfiguration

    /* Camera */
    private lateinit var camera: Camera
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider
    private lateinit var preview: Preview
    private lateinit var imageAnalysis: ImageAnalysis

    /* ML Kit */
    private lateinit var barcodeDetector: MLKitBarcodeDetector

    /* State */
    private var isInitialized = false
    private var pauseDetection = false
    private var pendingPermissionsResult: Result? = null

    fun attachToActivity(activity: FlutterActivity) {
        this.activity = activity
    }

    fun detachFromActivity() {
        stop(null)
        this.activity = null
    }

    fun initialize(args: HashMap<String, Any>, result: Result) {
        // Make sure we are connected to an activity
        if (activity == null)
            return ScannerError.ActivityNotConnected().throwFlutterError(result)

        // Stop running camera and start new
        stop(null)

        // Reset init state.
        isInitialized = false

        // Convert arguments to CameraConfig
        try {
            scannerConfiguration = ScannerConfiguration(
                (args["types"] as ArrayList<String>).mapNotNull { barcodeFormatMap[it] }.toIntArray(),
                DetectionMode.valueOf(args["mode"] as String),
                Resolution.valueOf(args["res"] as String),
                Framerate.valueOf(args["fps"] as String),
                CameraPosition.valueOf(args["pos"] as String)
            )
        } catch (e: ScannerError) {
            return e.throwFlutterError(result)
        } catch (e: Exception) {
            return ScannerError.InvalidArguments(args).throwFlutterError(result)
        }

        if (allPermissionsGranted(activity!!)) {
            initCamera(result)
        } else {
            pendingPermissionsResult = result
            activity?.requestPermissions(REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }
    }

    private fun allPermissionsGranted(activity: FlutterActivity) = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(activity.applicationContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                initCamera(pendingPermissionsResult)
            } else {
                pendingPermissionsResult?.let { ScannerError.Unauthorized().throwFlutterError(it) }
            }
        }

        return true
    }

    fun start(result: Result) {
        Log.d(TAG, "start: ")
        if (!isInitialized)
            return ScannerError.NotInitialized().throwFlutterError(result)
        if (cameraProvider.isBound(preview))
            return ScannerError.AlreadyRunning().throwFlutterError(result)

        bindCameraUseCases()
        result.success(null)
    }

    fun stop(result: Result? = null) {
        if (!isInitialized) {
            result?.let { ScannerError.NotInitialized().throwFlutterError(it) }
            return
        }

        cameraProvider.unbindAll()
        result?.success(null)
    }

    fun toggleTorch(result: Result) {
        if (!isInitialized)
            return ScannerError.NotInitialized().throwFlutterError(result)
        camera.cameraControl.enableTorch(camera.cameraInfo.torchState.value != TorchState.ON).addListener({
            result.success(camera.cameraInfo.torchState.value == TorchState.ON)
        }, ContextCompat.getMainExecutor(activity!!))
    }

    fun changeConfiguration(args: HashMap<String, Any>, result: Result) {
        try {
            val formats = if (args.containsKey("types")) (args["types"] as ArrayList<String>).map { barcodeFormatMap[it] ?: throw ScannerError.InvalidCodeType(it) }.toIntArray() else scannerConfiguration.formats
            val detectionMode = if (args.containsKey("mode")) DetectionMode.valueOf(args["mode"] as String) else scannerConfiguration.mode
            val resolution = if (args.containsKey("res")) Resolution.valueOf(args["res"] as String) else scannerConfiguration.resolution
            val framerate = if (args.containsKey("fps")) Framerate.valueOf(args["fps"] as String) else scannerConfiguration.framerate
            val position = if (args.containsKey("pos")) CameraPosition.valueOf(args["pos"] as String) else scannerConfiguration.position

            scannerConfiguration = scannerConfiguration.copy(
                formats = formats,
                mode = detectionMode,
                resolution = resolution,
                framerate = framerate,
                position = position
            )
        } catch (e: ScannerError) {
            return e.throwFlutterError(result)
        } catch (e: Exception) {
            return ScannerError.InvalidArguments(args).throwFlutterError(result)
        }

        initCamera(result)
    }

    private fun initCamera(result: Result?) {
        val options = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(0, *scannerConfiguration.formats)
                .build()

        barcodeDetector = MLKitBarcodeDetector(options, { codes ->
            if (!pauseDetection && codes.isNotEmpty()) {
                if (scannerConfiguration.mode == DetectionMode.pauseDetection) {
                    pauseDetection = true
                } else if (scannerConfiguration.mode == DetectionMode.pauseVideo) {
                    stop()
                }

                listener(codes)
            }
        }, {
            Log.e(TAG, "Error in Scanner", it)
        })

        // Select camera
        cameraSelector = CameraSelector.Builder()
            .requireLensFacing(
                if (scannerConfiguration.position == CameraPosition.back)
                    CameraSelector.LENS_FACING_BACK
                else
                    CameraSelector.LENS_FACING_FRONT
            )
            .build()

        // Create Camera Thread
        cameraExecutor = Executors.newSingleThreadExecutor()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity!!)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            isInitialized = true

            try {
                bindCameraUseCases()
            } catch (e: Exception) {
                result?.let { ScannerError.ConfigurationError(e).throwFlutterError(it) }
                Log.d(TAG, "initCamera: Error binding use cases")
                return@addListener
            }

            // Make sure detections are allowed
            pauseDetection = false

            result?.let {
                val previewRes = preview.resolutionInfo?.resolution ?: return@addListener ScannerError.NotInitialized().throwFlutterError(it)
                val analysisRes = imageAnalysis.resolutionInfo?.resolution ?: return@addListener ScannerError.NotInitialized().throwFlutterError(it)
                Log.d(TAG, "Preview resolution: ${previewRes.width}x${previewRes.height}")
                Log.d(TAG, "Analysis resolution: $analysisRes")
                // TODO: Handle Rotation properly

                previewConfiguration = PreviewConfiguration(flutterTextureEntry.id(), 0, previewRes.height, previewRes.width, analysis = analysisRes.toString())
                it.success(previewConfiguration.toMap())
            }
        }, ContextCompat.getMainExecutor(activity!!))
    }

    private fun bindCameraUseCases() {
        Log.d(TAG, "Requested Resolution: ${scannerConfiguration.resolution.portrait()}")

        // TODO: Handle rotation properly
        preview = Preview.Builder()
                .setTargetRotation(Surface.ROTATION_0)
                .setTargetResolution(scannerConfiguration.resolution.portrait())
                .build()

        imageAnalysis = ImageAnalysis.Builder()
                .setTargetRotation(Surface.ROTATION_0)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { it.setAnalyzer(cameraExecutor, barcodeDetector) }

        // As required by CameraX, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()

        // Bind camera to Lifecycle
        camera = cameraProvider.bindToLifecycle(activity!!, cameraSelector, preview, imageAnalysis)

        // Setup Surface
        cameraSurfaceProvider = Preview.SurfaceProvider {
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(it.resolution.width, it.resolution.height)
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, {})
        }

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)
    }

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

}