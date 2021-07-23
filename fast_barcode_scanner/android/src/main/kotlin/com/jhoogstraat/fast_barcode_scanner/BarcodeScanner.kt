package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.common.InputImage
import com.jhoogstraat.fast_barcode_scanner.types.*
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.io.IOException
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class BarcodeScanner(private val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry, private val listener: (List<Barcode>) -> Unit) : RequestPermissionsResultListener, ActivityResultListener {

    /* Android Lifecycle */
    private var activity: Activity? = null

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
    private var pendingPermissionsResult: Result? = null
    private var pendingImageAnalysisResult: Result? = null

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

    fun attachToActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachFromActivity() {
        stopCamera(null)
        this.activity = null
    }

    private fun allPermissionsGranted(activity: Activity) = REQUIRED_PERMISSIONS.all {
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

    fun initialize(args: HashMap<String, Any>, result: Result) {
        // Only initialize once
        // if (isInitialized)
        // return returnCameraDetails(result)

        // Make sure we are connected to an activity
        if (activity == null)
            return ScannerError.ActivityNotConnected().throwFlutterError(result)

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

        // Initialize the ML KIT Barcode scanner with the options provided
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(0, *scannerConfiguration.formats)
            .build()

        barcodeDetector = MLKitBarcodeDetector(options, { codes ->
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

        if (allPermissionsGranted(activity!!)) {
            initCamera(result)
        } else {
            pendingPermissionsResult = result
            ActivityCompat.requestPermissions(activity!!, REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }
    }

    fun startCamera(result: Result) {
        if (!isInitialized)
            return ScannerError.NotInitialized().throwFlutterError(result)
        else if (cameraProvider.isBound(preview))
            return ScannerError.AlreadyRunning().throwFlutterError(result)

        bindCameraUseCases()
        result.success(null)
    }

    fun stopCamera(result: Result? = null) {
        if (!isInitialized) {
            result?.let { ScannerError.NotInitialized().throwFlutterError(it) }
            return
        } else if (!cameraProvider.isBound(preview)) {
            result?.let {ScannerError.NotRunning().throwFlutterError(result) }
            return
        }

        cameraProvider.unbindAll()
        result?.success(null)
    }

    fun stopDetector(result: Result? = null) {
        if (!isInitialized) {
            result?.let { ScannerError.NotInitialized().throwFlutterError(it) }
            return
        } else if (!cameraProvider.isBound(imageAnalysis)) {
            result?.let { ScannerError.NotRunning().throwFlutterError(it) }
            return
        }

        imageAnalysis.clearAnalyzer()
    }

    fun startDetector(result: Result) {
        if (!isInitialized)
            return ScannerError.NotInitialized().throwFlutterError(result)
        else if (!cameraProvider.isBound(imageAnalysis))
            return ScannerError.NotRunning().throwFlutterError(result)

        imageAnalysis.setAnalyzer(cameraExecutor, barcodeDetector)
    }

    fun toggleTorch(result: Result) {
        if (!isInitialized)
            return ScannerError.NotInitialized().throwFlutterError(result)
        else if (!cameraProvider.isBound(preview))
            return ScannerError.NotRunning().throwFlutterError(result)

        camera.cameraControl.enableTorch(camera.cameraInfo.torchState.value != TorchState.ON).addListener({
            result.success(camera.cameraInfo.torchState.value == TorchState.ON)
        }, ContextCompat.getMainExecutor(activity!!))
    }

    fun changeConfiguration(args: HashMap<String, Any>, result: Result) {
        if (!isInitialized)
            return ScannerError.NotInitialized().throwFlutterError(result)

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

        bindCameraUseCases(result)
    }

    private fun initCamera(result: Result?) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity!!)

        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            try {
                bindCameraUseCases(result)
                isInitialized = true
            } catch (e: Exception) {
                result?.let { ScannerError.ConfigurationError(e).throwFlutterError(it) }
                Log.d(TAG, "initCamera: Error binding use cases")
                return@addListener
            }

        }, ContextCompat.getMainExecutor(activity!!))
    }



    private fun bindCameraUseCases(result: Result? = null) {
        Log.d(TAG, "Requested Resolution: ${scannerConfiguration.resolution.portrait()}")

        // CameraSelector
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
                .also { it.setAnalyzer(cameraExecutor, barcodeDetector) }

        // As required by CameraX, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()

        // Bind camera to Lifecycle
        camera = cameraProvider.bindToLifecycle(activity!! as LifecycleOwner, cameraSelector, preview, imageAnalysis)

        // Setup Surface
        cameraSurfaceProvider = Preview.SurfaceProvider {
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(it.resolution.width, it.resolution.height)
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, {})
        }

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)

        result?.also { sendCameraDetails(it) }
    }

    fun scanImage(source: Any?, result: Result) {
        if (pendingImageAnalysisResult != null) {
            result.error("ALREADY_PICKING", "Already picking an image for analysis", null);
            return
        }

        if (activity == null) {
            ScannerError.NotInitialized().throwFlutterError(result)
            return
        }

        when (source) {
            is List<*> -> barcodeDetector.analyze(
                InputImage.fromBitmap(BitmapFactory.decodeByteArray(source[0] as ByteArray, 0, (source[0] as ByteArray).size), source[1] as Int)
            )
                .addOnSuccessListener { sendBarcodes(it, result) }
                .addOnFailureListener { ScannerError.AnalysisFailed(it).throwFlutterError(pendingImageAnalysisResult!!) }
            is String -> barcodeDetector.analyze(activity!!.applicationContext, Uri.parse(source))
                    .addOnSuccessListener { sendBarcodes(it, result) }
                    .addOnFailureListener { ScannerError.AnalysisFailed(it).throwFlutterError(pendingImageAnalysisResult!!) }
            else -> {
                pendingImageAnalysisResult = result
                val intent = Intent(
                    Intent.ACTION_PICK,
                    android.provider.MediaStore.Images.Media.INTERNAL_CONTENT_URI
                )
                intent.type = "image/*"
                activity!!.startActivityForResult(intent, 1)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 1 || pendingImageAnalysisResult == null) {
            return false
        }

        when(resultCode) {
            Activity.RESULT_OK -> {
                try {
                    barcodeDetector.analyze(activity!!.applicationContext, data?.data!!)
                        .addOnSuccessListener { sendBarcodes(it, pendingImageAnalysisResult!!) }
                        .addOnFailureListener {
                            ScannerError.AnalysisFailed(it).throwFlutterError(pendingImageAnalysisResult!!)
                        }
                        .addOnCompleteListener { pendingImageAnalysisResult = null }
                } catch (e: IOException) {
                    ScannerError.LoadingFailed(e).throwFlutterError(pendingImageAnalysisResult!!)
                }
            }
            else -> {
                pendingImageAnalysisResult!!.success(null)
                pendingImageAnalysisResult = null
            }
        }

        return true
    }

    private fun sendCameraDetails(result: Result) {
        val previewRes = preview.resolutionInfo?.resolution ?: return ScannerError.NotInitialized().throwFlutterError(result)
        val analysisRes = imageAnalysis.resolutionInfo?.resolution ?: return ScannerError.NotInitialized().throwFlutterError(result)
        Log.d(TAG, "Preview resolution: ${previewRes.width}x${previewRes.height}")
        Log.d(TAG, "Analysis resolution: $analysisRes")
        // TODO: Handle Rotation properly

        previewConfiguration = PreviewConfiguration(flutterTextureEntry.id(), 0, previewRes.height, previewRes.width, analysis = analysisRes.toString())
        result.success(previewConfiguration.toMap())
    }

    private fun sendBarcodes(barcodes: List<Barcode>, result: Result) {
        result.success(barcodes.map { listOf(barcodeStringMap[it.format], it.rawValue, it.valueType) })
    }
}