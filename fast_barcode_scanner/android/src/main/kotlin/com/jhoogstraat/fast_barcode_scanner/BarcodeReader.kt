package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.camera2.CaptureRequest
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.core.util.Consumer
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import java.util.concurrent.Executors
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.TextureRegistry
import java.util.ArrayList

class BarcodeReader(private val flutterTexture: TextureRegistry.SurfaceTextureEntry, private val listener: (List<Barcode>) -> Unit) : PluginRegistry.RequestPermissionsResultListener, LifecycleOwner {

    private var activity: Activity? = null
    private var lifecycle: Lifecycle? = null

    private lateinit var flutterPreview: Preview
    private lateinit var barcodeAnalyzer: ImageAnalysis
    private lateinit var camera: Camera
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private val analyseExecutor = Executors.newSingleThreadExecutor()

    private lateinit var args: HashMap<String, Any>

    var torchState = false

    fun attachTo(activity: Activity, lifecycle: Lifecycle) {
        this.activity = activity
        this.lifecycle = lifecycle
    }

    fun detachFromActivity() {
        this.activity = null
        this.lifecycle = null
    }

    private fun initCamera() {
        val formats = (args["types"] as ArrayList<String>).map { barcodeFormatMap[it]!! }.toIntArray()
        val detectionMode = DetectionMode.valueOf(args["mode"] as String)
        val resolution = Resolution.valueOf(args["res"] as String)
        val framerate = Framerate.valueOf(args["fps"] as String)

        val activity = activity ?: throw IllegalStateException("No activity available!")
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)

        cameraProviderFuture.addListener(Runnable {
            // Used to bind the lifecycle of cameras to the lifecycle owner
            cameraProvider = cameraProviderFuture.get()

            // Select back camera
            cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                    .build()

            try {
                // Unbind use cases before rebinding
                cameraProvider.unbindAll()

                // Create Use Cases
                // Preview Use Case
                flutterPreview = Preview.Builder()
                        .setTargetResolution(Size(resolution.width(), resolution.height()))
                        .setTargetRotation(Surface.ROTATION_90)
                        .build()

                val textureSurface = flutterTexture.surfaceTexture()

                val surfaceProvider = Preview.SurfaceProvider {
                    textureSurface.setDefaultBufferSize(it.resolution.width, it.resolution.height)
                    val surface = Surface(textureSurface)
                    it.provideSurface(surface, ContextCompat.getMainExecutor(activity), Consumer<SurfaceRequest.Result> {})
                }

                flutterPreview.setSurfaceProvider(surfaceProvider)

                // Analysis Use Case
                val options = BarcodeScannerOptions.Builder()
                        .setBarcodeFormats(0, *formats)
                        .build()

                val detector = MLKitBarcodeDetector(options, OnSuccessListener { barcodes ->
                    if (detectionMode.pause() && barcodes.isNotEmpty()) {
                        pause()
                    }
                    listener(barcodes)
                }, OnFailureListener {
                    Log.e(TAG, "Error in MLKit", it)
                })

                val analyserBuilder = ImageAnalysis.Builder()
                val extender = Camera2Interop.Extender(analyserBuilder).setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(framerate.intValue(), framerate.intValue()))
                extender.setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(framerate.intValue(), framerate.intValue()))

                barcodeAnalyzer = analyserBuilder
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { it.setAnalyzer(analyseExecutor, detector) }

                camera = cameraProvider.bindToLifecycle(this, cameraSelector, flutterPreview, barcodeAnalyzer)
            } catch(exc: Exception) {
                Log.e(TAG, "Use case binding failed", exc)
            }

        }, ContextCompat.getMainExecutor(activity))
    }

    fun start(args: HashMap<String, Any>, result: Result) {
        this.args = args

        if (allPermissionsGranted()) {
            initCamera()
        } else {
            activity?.requestPermissions(REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }

        result.success(hashMapOf("textureId" to flutterTexture.id(), "surfaceOrientation" to 0, "surfaceHeight" to 1280, "surfaceWidth" to 720))
    }

    fun stop() {
        cameraProvider?.unbindAll()
    }

    fun pause() {
        cameraProvider?.unbindAll()
    }

    fun resume() {
        camera = cameraProvider.bindToLifecycle(this, cameraSelector, flutterPreview, barcodeAnalyzer)
    }

    fun toggleTorch() {
        camera?.cameraControl.enableTorch(!torchState).addListener(Runnable {
            torchState = !torchState
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(activity!!. baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                initCamera()
            }
        }

        return true
    }

    override fun getLifecycle(): Lifecycle {
        return lifecycle!!
    }

    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

}