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
import com.google.android.gms.tasks.Tasks
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
    private val mainExecutor = ContextCompat.getMainExecutor(activity)
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var barcodeScanner: MLKitBarcodeScanner

    private var isInitialized = false
    private var isDisposed = false
    private var isDetecting = false
    private val isRunning: Boolean
        get() = preview?.let { cameraProvider?.isBound(it) } == true

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

    private fun parseTypes(raw: Any?, args: Map<*, *>): List<Int> {
        val rawTypes = (raw as? List<*>)?.mapNotNull { it as? String }
            ?: throw ScannerException.InvalidArguments(args)
        val mapped = rawTypes.mapNotNull { barcodeFormatMap[it] }
        if (rawTypes.size != mapped.size) {
            val unsupported = rawTypes.filter { !barcodeFormatMap.containsKey(it) }
            Log.w(TAG, "Unsupported Android barcode types selected: $unsupported")
        }
        return mapped
    }

    private fun parseInitialConfiguration(args: Map<*, *>): ScannerConfiguration {
        try {
            return ScannerConfiguration(
                types = parseTypes(args["types"], args),
                mode = PerformanceMode.fromString(args["mode"] as? String),
                position = CameraPosition.fromString(args["pos"] as? String),
                detectionMode = DetectionMode.fromString(args["detectionMode"] as? String)
            )
        } catch (e: ScannerException) {
            throw e
        } catch (_: Exception) {
            throw ScannerException.InvalidArguments(args)
        }
    }

    private fun createScanner(formats: List<Int>): MLKitBarcodeScanner {
        val optionsBuilder = BarcodeScannerOptions.Builder()
        if (formats.isEmpty()) {
            optionsBuilder.setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
        } else {
            val extra = formats.drop(1).toIntArray()
            optionsBuilder.setBarcodeFormats(formats.first(), *extra)
        }

        return MLKitBarcodeScanner(
            options = optionsBuilder.build(),
            mainExecutor = mainExecutor,
            onBarcodes = { codes ->
                if (isDisposed || !isInitialized || !isRunning || !isDetecting) return@MLKitBarcodeScanner
                when (scannerConfiguration.detectionMode) {
                    DetectionMode.PauseDetection -> {
                        isDetecting = false
                        imageAnalysis?.clearAnalyzer()
                    }
                    DetectionMode.PauseVideo -> {
                        isDetecting = false
                        cameraProvider?.unbindAll()
                    }
                    DetectionMode.Continuous -> Unit
                }
                listener(codes)
            },
            onFailure = { error -> Log.e(TAG, "Error in ML Kit barcode scanner", error) }
        )
    }

    fun requestPermissions(): Task<Unit> {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return Tasks.forResult(Unit)
        }

        permissionsCompleter?.trySetException(ScannerException.Unauthorized())
        val completer = TaskCompletionSource<Unit>()
        permissionsCompleter = completer
        ActivityCompat.requestPermissions(activity, REQUIRED_PERMISSIONS, PERMISSIONS_REQUEST_CODE)
        return completer.task
    }

    fun loadCamera(): Task<CameraInformation> {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_DENIED
        ) {
            return Tasks.forException(ScannerException.Unauthorized())
        }

        val loadingCompleter = TaskCompletionSource<CameraInformation>()
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        cameraProviderFuture.addListener({
            if (isDisposed) {
                loadingCompleter.trySetException(ScannerException.NotInitialized())
                return@addListener
            }
            try {
                cameraProvider = cameraProviderFuture.get()
                isInitialized = true
                bindCameraUseCases()
                loadingCompleter.trySetResult(getCameraInformation())
            } catch (e: ScannerException) {
                loadingCompleter.trySetException(e)
            } catch (e: Exception) {
                loadingCompleter.trySetException(ScannerException.ConfigurationException(e))
            }
        }, mainExecutor)

        return loadingCompleter.task
    }

    @Suppress("DEPRECATION")
    private fun currentDisplayRotation(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            activity.windowManager.defaultDisplay?.rotation ?: Surface.ROTATION_0
        }

    private fun resolveCameraSelector(provider: ProcessCameraProvider): CameraSelector {
        val preferred = if (scannerConfiguration.position == CameraPosition.Back) {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        val fallback = if (preferred == CameraSelector.DEFAULT_BACK_CAMERA) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }

        return when {
            provider.hasCamera(preferred) -> preferred
            provider.hasCamera(fallback) -> fallback
            else -> throw ScannerException.NoInputDeviceForConfig(scannerConfiguration)
        }
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: throw ScannerException.NotInitialized()
        val lifecycleOwner = activity as? LifecycleOwner
            ?: throw ScannerException.ActivityNotConnected()

        val selector = resolveCameraSelector(provider)
        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    scannerConfiguration.mode.targetSize(),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
                )
            )
            .build()

        val rotation = currentDisplayRotation()
        val activePreview = Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(rotation)
            .build()
        val activeAnalysis = ImageAnalysis.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(rotation)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { it.setAnalyzer(cameraExecutor, barcodeScanner) }

        preview = activePreview
        imageAnalysis = activeAnalysis
        isDetecting = true

        provider.unbindAll()

        activePreview.setSurfaceProvider(mainExecutor) { request ->
            if (isDisposed) {
                request.willNotProvideSurface()
                return@setSurfaceProvider
            }
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = Surface(surfaceTexture)
            request.provideSurface(surface, Runnable::run) { surface.release() }
        }

        camera = provider.bindToLifecycle(lifecycleOwner, selector, activePreview, activeAnalysis)
    }

    private fun requireRunningCamera(): Camera {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) throw ScannerException.NotRunning()
        return camera ?: throw ScannerException.NotInitialized()
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
        if (!isRunning) bindCameraUseCases()
    }

    fun stopCamera() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        if (!isRunning) return
        isDetecting = false
        cameraProvider?.unbindAll()
    }

    fun startDetector() {
        requireRunningCamera()
        isDetecting = true
        imageAnalysis?.setAnalyzer(cameraExecutor, barcodeScanner)
    }

    fun stopDetector() {
        requireRunningCamera()
        isDetecting = false
        imageAnalysis?.clearAnalyzer()
    }

    fun toggleTorch(): ListenableFuture<Void> =
        requireRunningCamera().cameraControl.enableTorch(!torchState)

    fun setZoom(zoomFactor: Double): Double {
        val activeCamera = requireRunningCamera()
        val zoomState = activeCamera.cameraInfo.zoomState.value
        val minZoom = zoomState?.minZoomRatio?.toDouble() ?: 1.0
        val maxZoom = maxOf(minZoom, zoomState?.maxZoomRatio?.toDouble() ?: 1.0)
        val clamped = zoomFactor.coerceIn(minZoom, maxZoom)
        activeCamera.cameraControl.setZoomRatio(clamped.toFloat())
        return clamped
    }

    fun changeConfiguration(args: Map<*, *>): CameraInformation {
        if (!isInitialized) throw ScannerException.NotInitialized()

        val previous = scannerConfiguration
        try {
            scannerConfiguration = previous.copy(
                types = if (args.containsKey("types")) parseTypes(args["types"], args) else previous.types,
                mode = if (args.containsKey("mode")) PerformanceMode.fromString(args["mode"] as? String) else previous.mode,
                detectionMode = if (args.containsKey("detectionMode")) {
                    DetectionMode.fromString(args["detectionMode"] as? String)
                } else {
                    previous.detectionMode
                },
                position = if (args.containsKey("pos")) CameraPosition.fromString(args["pos"] as? String) else previous.position
            )
        } catch (e: ScannerException) {
            throw e
        } catch (_: Exception) {
            throw ScannerException.InvalidArguments(args)
        }

        val typesChanged = scannerConfiguration.types != previous.types
        val needsRebind = scannerConfiguration.mode != previous.mode ||
            scannerConfiguration.position != previous.position

        var oldScanner: MLKitBarcodeScanner? = null
        if (typesChanged) {
            oldScanner = barcodeScanner
            barcodeScanner = createScanner(scannerConfiguration.types)
        }

        if (needsRebind && isRunning) {
            bindCameraUseCases()
        } else if (typesChanged && isRunning && isDetecting) {
            imageAnalysis?.setAnalyzer(cameraExecutor, barcodeScanner)
        }

        // Close old scanner only after analyzer has been swapped out.
        oldScanner?.close()

        return getCameraInformation()
    }

    fun dispose() {
        if (isDisposed) return
        isDisposed = true
        isInitialized = false
        isDetecting = false

        permissionsCompleter?.trySetException(ScannerException.ActivityNotConnected())
        permissionsCompleter = null

        imageAnalysis?.clearAnalyzer()
        preview?.setSurfaceProvider(null)
        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.w(TAG, "Error unbinding camera during dispose", e)
        }

        barcodeScanner.close()
        flutterTextureEntry.release()
        cameraExecutor.shutdown()

        camera = null
        preview = null
        imageAnalysis = null
        cameraProvider = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSIONS_REQUEST_CODE) return false

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
        val fallback = scannerConfiguration.mode.targetSize()
        val previewRes = preview?.resolutionInfo?.resolution ?: fallback
        val analysisRes = imageAnalysis?.resolutionInfo?.resolution ?: previewRes

        val cameraInfo = camera?.cameraInfo
        val zoomState = cameraInfo?.zoomState?.value
        val minZoom = zoomState?.minZoomRatio?.toDouble() ?: 1.0
        val maxZoom = maxOf(minZoom, zoomState?.maxZoomRatio?.toDouble() ?: 1.0)

        return CameraInformation(
            videoWidth = previewRes.width.toDouble(),
            videoHeight = previewRes.height.toDouble(),
            analysisWidth = analysisRes.width.toDouble(),
            analysisHeight = analysisRes.height.toDouble(),
            textureId = flutterTextureEntry.id(),
            sensorOrientation = cameraInfo?.sensorRotationDegrees ?: 90,
            minZoom = minZoom,
            maxZoom = maxZoom
        )
    }
}
