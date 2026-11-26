package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.TorchState
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.jhoogstraat.fast_barcode_scanner.scanner.MLKitBarcodeScanner
import com.jhoogstraat.fast_barcode_scanner.types.CameraInformation
import com.jhoogstraat.fast_barcode_scanner.types.CameraPosition
import com.jhoogstraat.fast_barcode_scanner.types.DetectionMode
import com.jhoogstraat.fast_barcode_scanner.types.PerformanceMode
import com.jhoogstraat.fast_barcode_scanner.types.ScannerConfiguration
import com.jhoogstraat.fast_barcode_scanner.types.ScannerException
import com.jhoogstraat.fast_barcode_scanner.types.barcodeFormatMap
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Camera(
    val activity: Activity,
    val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry,
    args: Map<*, *>,
    private val listener: (List<Barcode>) -> Unit
) : RequestPermissionsResultListener {

    private var scannerConfiguration: ScannerConfiguration

    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraSelector: CameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null

    private var barcodeScanner: MLKitBarcodeScanner

    private var isInitialized = false
    private val isRunning: Boolean
        get() = cameraProvider != null && preview != null && cameraProvider!!.isBound(preview!!)

    val torchState: Boolean
        get() = camera?.cameraInfo?.torchState?.value == TorchState.ON

    private var permissionsCompleter: TaskCompletionSource<Unit>? = null

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val PERMISSIONS_REQUEST_CODE = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

    init {
        scannerConfiguration = parseInitialConfiguration(args)
        barcodeScanner = createScanner(scannerConfiguration.types)
    }

    private fun parseInitialConfiguration(args: Map<*, *>): ScannerConfiguration {
        try {
            val rawTypes = (args["types"] as? List<*>)
                ?.mapNotNull { it as? String }
                ?: throw ScannerException.InvalidArguments(args)

            val mappedTypes = rawTypes.mapNotNull { barcodeFormatMap[it] }.toIntArray()
            if (rawTypes.size != mappedTypes.size) {
                val unsupported = rawTypes.filter { !barcodeFormatMap.containsKey(it) }
                Log.w(TAG, "Unsupported Android barcode types selected: $unsupported")
            }

            return ScannerConfiguration(
                types = mappedTypes,
                mode = PerformanceMode.fromString(args["mode"] as? String),
                position = CameraPosition.fromString(args["pos"] as? String),
                detectionMode = DetectionMode.fromString(args["detectionMode"] as? String)
            )
        } catch (e: ScannerException) {
            throw e
        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(args)
        }
    }

    private fun createScanner(formats: IntArray): MLKitBarcodeScanner {
        val optionsBuilder = BarcodeScannerOptions.Builder()
        if (formats.isEmpty()) {
            optionsBuilder.setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
        } else {
            optionsBuilder.setBarcodeFormats(formats[0], *formats.sliceArray(1 until formats.size))
        }

        return MLKitBarcodeScanner(
            options = optionsBuilder.build(),
            successListener = { codes ->
                if (codes.isNotEmpty()) {
                    when (scannerConfiguration.detectionMode) {
                        DetectionMode.PauseDetection -> stopDetector()
                        DetectionMode.PauseVideo -> stopCamera()
                        DetectionMode.Continuous -> Unit
                    }
                    listener(codes)
                }
            },
            failureListener = { error ->
                Log.e(TAG, "Error in ML Kit barcode scanner", error)
            }
        )
    }

    fun requestPermissions(): Task<Unit> {
        val completer = TaskCompletionSource<Unit>()
        permissionsCompleter = completer

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
            completer.setResult(Unit)
        }

        return completer.task
    }

    fun loadCamera(): Task<CameraInformation> {
        val loadingCompleter = TaskCompletionSource<CameraInformation>()

        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_DENIED
        ) {
            loadingCompleter.setException(ScannerException.Unauthorized())
            return loadingCompleter.task
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                isInitialized = true
                bindCameraUseCases()
                loadingCompleter.setResult(getCameraInformation())
            } catch (e: ScannerException) {
                loadingCompleter.setException(e)
            } catch (e: Exception) {
                loadingCompleter.setException(ScannerException.ConfigurationException(e))
            }
        }, ContextCompat.getMainExecutor(activity))

        return loadingCompleter.task
    }

    @Suppress("DEPRECATION")
    private fun currentDisplayRotation(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            activity.windowManager.defaultDisplay?.rotation ?: Surface.ROTATION_0
        }
    }

    private fun buildSelectorAndUseCases() {
        val provider = cameraProvider ?: throw ScannerException.NotInitialized()
        val desiredLens = if (scannerConfiguration.position == CameraPosition.Back) {
            CameraSelector.LENS_FACING_BACK
        } else {
            CameraSelector.LENS_FACING_FRONT
        }

        val desiredSelector = CameraSelector.Builder()
            .requireLensFacing(desiredLens)
            .build()

        cameraSelector = if (provider.hasCamera(desiredSelector)) {
            desiredSelector
        } else {
            val fallbackLens = if (desiredLens == CameraSelector.LENS_FACING_BACK) {
                CameraSelector.LENS_FACING_FRONT
            } else {
                CameraSelector.LENS_FACING_BACK
            }
            val fallbackSelector = CameraSelector.Builder()
                .requireLensFacing(fallbackLens)
                .build()
            if (provider.hasCamera(fallbackSelector)) {
                fallbackSelector
            } else {
                throw ScannerException.NoInputDeviceForConfig(scannerConfiguration)
            }
        }

        val targetSize = scannerConfiguration.mode.targetSize()
        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    targetSize,
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
                )
            )
            .build()

        val rotation = currentDisplayRotation()

        preview = Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(rotation)
            .build()

        imageAnalysis = ImageAnalysis.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(rotation)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { it.setAnalyzer(cameraExecutor, barcodeScanner) }
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: throw ScannerException.NotInitialized()
        val lifecycleOwner = activity as? LifecycleOwner
            ?: throw ScannerException.ActivityNotConnected()

        buildSelectorAndUseCases()

        provider.unbindAll()

        val activePreview = preview!!
        val activeAnalysis = imageAnalysis!!

        val surfaceProvider = Preview.SurfaceProvider { request ->
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(
                request.resolution.width,
                request.resolution.height
            )
            val surface = Surface(surfaceTexture)
            request.provideSurface(surface, cameraExecutor) {
                surface.release()
            }
        }

        activePreview.setSurfaceProvider(ContextCompat.getMainExecutor(activity), surfaceProvider)

        camera = provider.bindToLifecycle(
            lifecycleOwner,
            cameraSelector,
            activePreview,
            activeAnalysis
        )
    }

    fun canSwitchCamera(): Boolean {
        val provider = cameraProvider ?: return false
        return try {
            provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA) &&
                provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)
        } catch (_: Exception) {
            false
        }
    }

    fun startCamera() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (isRunning) return
        bindCameraUseCases()
    }

    fun stopCamera() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) return
        cameraProvider?.unbindAll()
    }

    fun startDetector() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) throw ScannerException.NotRunning()
        imageAnalysis?.setAnalyzer(cameraExecutor, barcodeScanner)
    }

    fun stopDetector() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) throw ScannerException.NotRunning()
        imageAnalysis?.clearAnalyzer()
    }

    fun toggleTorch(): ListenableFuture<Void> {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) throw ScannerException.NotRunning()
        val activeCamera = camera ?: throw ScannerException.NotInitialized()
        return activeCamera.cameraControl.enableTorch(!torchState)
    }

    fun setZoom(zoomFactor: Double): Double {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) throw ScannerException.NotRunning()
        val activeCamera = camera ?: throw ScannerException.NotInitialized()

        val zoomState = activeCamera.cameraInfo.zoomState.value
        val minZoom = zoomState?.minZoomRatio?.toDouble() ?: 1.0
        val maxZoom = zoomState?.maxZoomRatio?.toDouble() ?: 1.0
        val clamped = zoomFactor.coerceIn(minZoom, maxZoom)

        activeCamera.cameraControl.setZoomRatio(clamped.toFloat())
        return clamped
    }

    fun changeConfiguration(args: Map<*, *>): CameraInformation {
        if (!isInitialized) throw ScannerException.NotInitialized()

        var typesChanged = false

        try {
            val formats = if (args.containsKey("types")) {
                val rawTypes = (args["types"] as? List<*>)
                    ?.mapNotNull { it as? String }
                    ?: throw ScannerException.InvalidArguments(args)
                typesChanged = true
                rawTypes.mapNotNull { barcodeFormatMap[it] }.toIntArray()
            } else {
                scannerConfiguration.types
            }

            val mode = if (args.containsKey("mode")) {
                PerformanceMode.fromString(args["mode"] as? String)
            } else {
                scannerConfiguration.mode
            }

            val detectionMode = if (args.containsKey("detectionMode")) {
                DetectionMode.fromString(args["detectionMode"] as? String)
            } else {
                scannerConfiguration.detectionMode
            }

            val position = if (args.containsKey("pos")) {
                CameraPosition.fromString(args["pos"] as? String)
            } else {
                scannerConfiguration.position
            }

            scannerConfiguration = scannerConfiguration.copy(
                types = formats,
                mode = mode,
                position = position,
                detectionMode = detectionMode
            )
        } catch (e: ScannerException) {
            throw e
        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(args)
        }

        if (typesChanged) {
            val previousScanner = barcodeScanner
            barcodeScanner = createScanner(scannerConfiguration.types)
            previousScanner.close()
        }

        bindCameraUseCases()
        return getCameraInformation()
    }

    fun dispose() {
        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.w(TAG, "Error unbinding camera during dispose", e)
        }
        barcodeScanner.close()
        flutterTextureEntry.release()
        cameraExecutor.shutdown()
        camera = null
        isInitialized = false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSIONS_REQUEST_CODE) {
            return false
        }

        permissionsCompleter?.let { completer ->
            permissionsCompleter = null
            if (grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            ) {
                completer.trySetResult(Unit)
            } else {
                completer.trySetException(ScannerException.Unauthorized())
            }
        }

        return true
    }

    private fun getCameraInformation(): CameraInformation {
        val previewRes = preview?.resolutionInfo?.resolution
            ?: throw ScannerException.NotInitialized()
        val analysisRes = imageAnalysis?.resolutionInfo?.resolution
            ?: previewRes

        val cameraInfo = camera?.cameraInfo
        val sensorOrientation = cameraInfo?.sensorRotationDegrees ?: 90
        val zoomState = cameraInfo?.zoomState?.value
        val minZoom = zoomState?.minZoomRatio?.toDouble() ?: 1.0
        val maxZoom = zoomState?.maxZoomRatio?.toDouble() ?: 1.0

        return CameraInformation(
            videoWidth = previewRes.width.toDouble(),
            videoHeight = previewRes.height.toDouble(),
            analysisWidth = analysisRes.width.toDouble(),
            analysisHeight = analysisRes.height.toDouble(),
            textureId = flutterTextureEntry.id(),
            sensorOrientation = sensorOrientation,
            minZoom = minZoom,
            maxZoom = maxZoom
        )
    }
}
