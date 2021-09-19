package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.core.Camera
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.jhoogstraat.fast_barcode_scanner.scanner.MLKitBarcodeScanner
import com.jhoogstraat.fast_barcode_scanner.types.*
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Camera(
    val activity: Activity,
    private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry,
    args: HashMap<String, Any>,
    private val listener: (List<Barcode>) -> Unit
) : RequestPermissionsResultListener {

    /* Scanner configuration */
    private var scannerConfiguration: ScannerConfiguration

    /* Camera */
    private lateinit var camera: Camera
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider
    private lateinit var preview: Preview
    private lateinit var imageAnalysis: ImageAnalysis

    /* ML Kit */
    private var barcodeScanner: MLKitBarcodeScanner

    /* State */
    private var isInitialized = false
    private val isRunning: Boolean
        get() = cameraProvider.isBound(preview)
    val torchState: Boolean
        get() = camera.cameraInfo.torchState.value == TorchState.ON

    private var permissionsCompleter: TaskCompletionSource<Unit>? = null

    /* Companion */
    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val PERMISSIONS_REQUEST_CODE = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

    init {
        try {
            scannerConfiguration = ScannerConfiguration(
                (args["types"] as ArrayList<String>).mapNotNull { barcodeFormatMap[it] }
                    .toIntArray(),
                DetectionMode.valueOf(args["mode"] as String),
                Resolution.valueOf(args["res"] as String),
                Framerate.valueOf(args["fps"] as String),
                CameraPosition.valueOf(args["pos"] as String)
            )
        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(args)
        }

        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(0, *scannerConfiguration.formats)
            .build()

        barcodeScanner = MLKitBarcodeScanner(options, { codes ->
            if (codes.isNotEmpty()) {
                if (scannerConfiguration.mode == DetectionMode.pauseDetection) {
                    stopDetector()
                } else if (scannerConfiguration.mode == DetectionMode.pauseVideo) {
                    stopCamera()
                }

                listener(codes)
            }
        }, {
            Log.e(TAG, "Error in Scanner", it)
        })

        // Create Camera Thread
        cameraExecutor = Executors.newSingleThreadExecutor()
    }

    fun requestPermissions(): Task<Unit> {
        permissionsCompleter = TaskCompletionSource<Unit>()

        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_DENIED
        ) {
            ActivityCompat.requestPermissions(
                activity,
                REQUIRED_PERMISSIONS,
                PERMISSIONS_REQUEST_CODE
            )
        } else {
            permissionsCompleter!!.setResult(null)
        }

        return permissionsCompleter!!.task
    }

    /**
     * Fetching the camera is an async task.
     * Separating it into a dedicated method
     * allows to load the camera at any time.
     */
    fun loadCamera(): Task<PreviewConfiguration> {
        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_DENIED
        ) {
            throw ScannerException.Unauthorized()
        }

        // ProcessCameraProvider.configureInstance(Camera2Config.defaultConfig())
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)

        val loadingCompleter = TaskCompletionSource<PreviewConfiguration>()
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            isInitialized = true
            bindCameraUseCases()
            loadingCompleter.setResult(getPreviewConfiguration())
        }, ContextCompat.getMainExecutor(activity))

        return loadingCompleter.task
    }

    private fun buildSelectorAndUseCases() {
        cameraSelector = CameraSelector.Builder()
            .requireLensFacing(
                if (scannerConfiguration.position == CameraPosition.back)
                    CameraSelector.LENS_FACING_BACK
                else
                    CameraSelector.LENS_FACING_FRONT
            )
            .build()

        // TODO: Handle rotation properly
        preview = Preview.Builder()
            .setTargetRotation(Surface.ROTATION_0)
            .setTargetResolution(scannerConfiguration.resolution.portrait())
            .build()

        imageAnalysis = ImageAnalysis.Builder()
            .setTargetRotation(Surface.ROTATION_0)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { it.setAnalyzer(cameraExecutor, barcodeScanner) }
    }

    private fun bindCameraUseCases() {
        Log.d(TAG, "Requested Resolution: ${scannerConfiguration.resolution.portrait()}")

        // Selector and UseCases need to be rebuild when rebinding them
        buildSelectorAndUseCases()

        // As required by CameraX, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()

        // Bind camera to Lifecycle
        camera = cameraProvider.bindToLifecycle(
            activity as LifecycleOwner,
            cameraSelector,
            preview,
            imageAnalysis
        )

        // Setup Surface
        cameraSurfaceProvider = Preview.SurfaceProvider {
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(it.resolution.width, it.resolution.height)
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, {})
        }

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)
    }

    fun startCamera() {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (isRunning)
            return

        bindCameraUseCases()
    }

    fun stopCamera() {
        if (!isInitialized) {
            throw ScannerException.NotInitialized()
        } else if (!isRunning) {
            return
        }

        cameraProvider.unbindAll()
    }

    fun startDetector() {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (!isRunning)
            throw ScannerException.NotRunning()
        else if (cameraProvider.isBound(imageAnalysis))
            return

        imageAnalysis.setAnalyzer(cameraExecutor, barcodeScanner)
    }

    fun stopDetector() {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (!isRunning)
            throw ScannerException.NotRunning()
        else if (!cameraProvider.isBound(imageAnalysis))
            return

        imageAnalysis.clearAnalyzer()
    }

    fun toggleTorch(): ListenableFuture<Void> {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (!isRunning)
            throw ScannerException.NotRunning()

        return camera.cameraControl.enableTorch(!torchState)
    }

    fun changeConfiguration(args: HashMap<String, Any>): PreviewConfiguration {
        if (!isInitialized)
            throw ScannerException.NotInitialized()

        try {
            val formats = if (args.containsKey("types")) (args["types"] as ArrayList<String>).map {
                barcodeFormatMap[it] ?: throw ScannerException.InvalidCodeType(it)
            }.toIntArray() else scannerConfiguration.formats
            val detectionMode =
                if (args.containsKey("mode")) DetectionMode.valueOf(args["mode"] as String) else scannerConfiguration.mode
            val resolution =
                if (args.containsKey("res")) Resolution.valueOf(args["res"] as String) else scannerConfiguration.resolution
            val framerate =
                if (args.containsKey("fps")) Framerate.valueOf(args["fps"] as String) else scannerConfiguration.framerate
            val position =
                if (args.containsKey("pos")) CameraPosition.valueOf(args["pos"] as String) else scannerConfiguration.position

            scannerConfiguration = scannerConfiguration.copy(
                formats = formats,
                mode = detectionMode,
                resolution = resolution,
                framerate = framerate,
                position = position
            )
        } catch (e: ScannerException) {
            throw e
        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(args)
        }

        bindCameraUseCases()
        return getPreviewConfiguration()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            permissionsCompleter?.also { completer ->
                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    completer.setResult(null)
                } else {
                    completer.setException(ScannerException.Unauthorized())
                }
            }
        }

        return true
    }

    private fun getPreviewConfiguration(): PreviewConfiguration {
        val previewRes =
            preview.resolutionInfo?.resolution ?: throw ScannerException.NotInitialized()
        val analysisRes =
            imageAnalysis.resolutionInfo?.resolution ?: throw ScannerException.NotInitialized()
        Log.d(TAG, "Preview resolution: ${previewRes.width}x${previewRes.height}")
        Log.d(TAG, "Analysis resolution: $analysisRes")

        return PreviewConfiguration(
            flutterTextureEntry.id(),
            0,
            previewRes.height,
            previewRes.width,
            analysis = analysisRes.toString()
        )
    }

}