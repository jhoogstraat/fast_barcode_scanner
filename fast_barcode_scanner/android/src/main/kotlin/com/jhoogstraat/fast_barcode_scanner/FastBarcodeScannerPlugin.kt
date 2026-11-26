package com.jhoogstraat.fast_barcode_scanner

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Point
import android.graphics.Rect
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.jhoogstraat.fast_barcode_scanner.types.CameraInformation
import com.jhoogstraat.fast_barcode_scanner.types.ScannerException
import com.jhoogstraat.fast_barcode_scanner.types.barcodeStringMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException

/** FastBarcodeScannerPlugin */
class FastBarcodeScannerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    StreamHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private var commandChannel: MethodChannel? = null
    private var detectionChannel: EventChannel? = null
    private var detectionEventSink: EventSink? = null

    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var camera: Camera? = null

    private var pickImageCompleter: TaskCompletionSource<Uri?>? = null

    companion object {
        private const val PICK_IMAGE_REQUEST_CODE = 4210
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        commandChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.jhoogstraat/fast_barcode_scanner"
        )
        detectionChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.jhoogstraat/fast_barcode_scanner/detections"
        )
        pluginBinding = flutterPluginBinding
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        commandChannel?.setMethodCallHandler(null)
        detectionChannel?.setStreamHandler(null)
        commandChannel = null
        detectionChannel = null
        pluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        commandChannel?.setMethodCallHandler(this)
        detectionChannel?.setStreamHandler(this)
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        dispose()

        commandChannel?.setMethodCallHandler(null)
        detectionChannel?.setStreamHandler(null)
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    // MARK: EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventSink?) {
        detectionEventSink = events
    }

    override fun onCancel(arguments: Any?) {
        detectionEventSink = null
    }

    // MARK: MethodChannel.MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            var response: Any? = null

            when (call.method) {
                "init" -> {
                    val args = call.arguments as? Map<*, *>
                        ?: throw ScannerException.InvalidArguments(call.arguments)
                    initialize(args)
                        .addOnSuccessListener { result.success(it.serialized()) }
                        .addOnFailureListener { error ->
                            dispose()
                            val scannerError = error as? ScannerException
                                ?: ScannerException.Unknown(error)
                            scannerError.throwFlutterError(result)
                        }
                    return
                }

                "scan" -> {
                    scanImage(call.arguments)
                        .addOnSuccessListener { barcodes ->
                            result.success(barcodes?.let { encode(it) })
                        }
                        .addOnFailureListener { error ->
                            val scannerError = error as? ScannerException
                                ?: ScannerException.Unknown(error)
                            scannerError.throwFlutterError(result)
                        }
                    return
                }

                "dispose" -> {
                    dispose()
                }

                else -> {
                    val activeCamera = this.camera ?: throw ScannerException.NotInitialized()
                    when (call.method) {
                        "start" -> activeCamera.startCamera()
                        "stop" -> activeCamera.stopCamera()
                        "startDetector" -> activeCamera.startDetector()
                        "stopDetector" -> activeCamera.stopDetector()
                        "canSwitchCamera" -> response = activeCamera.canSwitchCamera()
                        "setZoom" -> {
                            val zoomFactor = (call.arguments as? Number)?.toDouble()
                                ?: throw ScannerException.InvalidArguments(call.arguments)
                            response = activeCamera.setZoom(zoomFactor)
                        }
                        "config" -> {
                            val args = call.arguments as? Map<*, *>
                                ?: throw ScannerException.InvalidArguments(call.arguments)
                            response = activeCamera.changeConfiguration(args).serialized()
                        }
                        "torch" -> {
                            val future = activeCamera.toggleTorch()
                            future.addListener(
                                {
                                    try {
                                        future.get()
                                        result.success(activeCamera.torchState)
                                    } catch (e: Exception) {
                                        ScannerException.Unknown(e).throwFlutterError(result)
                                    }
                                },
                                ContextCompat.getMainExecutor(activeCamera.activity)
                            )
                            return
                        }
                        else -> {
                            result.notImplemented()
                            return
                        }
                    }
                }
            }

            result.success(response)
        } catch (e: ScannerException) {
            e.throwFlutterError(result)
        } catch (e: Exception) {
            ScannerException.Unknown(e).throwFlutterError(result)
        }
    }

    private fun buildBoundingBox(rect: Rect?): List<Double>? {
        return rect?.let {
            listOf(
                it.left.toDouble(),
                it.top.toDouble(),
                it.right.toDouble(),
                it.bottom.toDouble()
            )
        }
    }

    private fun buildPointList(points: Array<Point>?): List<List<Double>>? {
        return points?.map { listOf(it.x.toDouble(), it.y.toDouble()) }
    }

    private fun encode(barcodes: List<Barcode>): List<List<Any?>> {
        return barcodes.mapNotNull { barcode ->
            val type = barcodeStringMap[barcode.format] ?: return@mapNotNull null
            val rawValue = barcode.rawValue ?: return@mapNotNull null
            listOf(
                type,
                rawValue,
                buildBoundingBox(barcode.boundingBox),
                buildPointList(barcode.cornerPoints)
            )
        }
    }

    private fun initialize(configuration: Map<*, *>): Task<CameraInformation> {
        // Gracefully clean up any previous camera (for example, after a Flutter Hot Restart).
        if (this.camera != null) {
            dispose()
        }

        val pluginBinding = this.pluginBinding ?: throw ScannerException.ActivityNotConnected()
        val activityBinding = this.activityBinding ?: throw ScannerException.ActivityNotConnected()

        val newCamera = Camera(
            activity = activityBinding.activity,
            flutterTextureEntry = pluginBinding.textureRegistry.createSurfaceTexture(),
            args = configuration
        ) { barcodes ->
            val encoded = encode(barcodes)
            if (encoded.isNotEmpty()) {
                activityBinding.activity.runOnUiThread {
                    detectionEventSink?.success(encoded)
                }
            }
        }

        this.camera = newCamera
        activityBinding.addRequestPermissionsResultListener(newCamera)

        return newCamera.requestPermissions()
            .continueWithTask { permissionTask ->
                if (!permissionTask.isSuccessful) {
                    val error = permissionTask.exception ?: ScannerException.Unauthorized()
                    Tasks.forException(error)
                } else {
                    newCamera.loadCamera()
                }
            }
    }

    private fun dispose() {
        camera?.let { activeCamera ->
            activityBinding?.removeRequestPermissionsResultListener(activeCamera)
            activeCamera.dispose()
        }
        camera = null
    }

    private fun scanImage(source: Any?): Task<List<Barcode>?> {
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .build()
        val scanner = BarcodeScanning.getClient(options)

        return when (source) {
            is List<*> -> {
                val bytes = source.getOrNull(0) as? ByteArray
                    ?: throw ScannerException.InvalidImageData()
                val rotation = (source.getOrNull(1) as? Number)?.toInt() ?: 0

                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: throw ScannerException.InvalidImageData()

                scanner.process(InputImage.fromBitmap(bitmap, rotation))
                    .addOnCompleteListener { scanner.close() }
            }

            else -> {
                if (pickImageCompleter?.task?.isComplete == false) {
                    scanner.close()
                    throw ScannerException.AlreadyPicking()
                }

                val binding = activityBinding ?: run {
                    scanner.close()
                    throw ScannerException.ActivityNotConnected()
                }

                val intent = Intent(
                    Intent.ACTION_PICK,
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                ).apply {
                    type = "image/*"
                }

                val completer = TaskCompletionSource<Uri?>()
                pickImageCompleter = completer

                binding.activity.startActivityForResult(intent, PICK_IMAGE_REQUEST_CODE)

                completer.task.continueWithTask { uriTask ->
                    val uri = uriTask.result
                    if (uri == null) {
                        scanner.close()
                        Tasks.forResult(null)
                    } else {
                        try {
                            val inputImage = InputImage.fromFilePath(binding.activity, uri)
                            scanner.process(inputImage)
                                .addOnCompleteListener { scanner.close() }
                        } catch (e: IOException) {
                            scanner.close()
                            Tasks.forException(ScannerException.LoadingFailed(e))
                        }
                    }
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_IMAGE_REQUEST_CODE) {
            return false
        }

        val completer = pickImageCompleter ?: return false
        pickImageCompleter = null

        if (resultCode == Activity.RESULT_OK) {
            completer.trySetResult(data?.data)
        } else {
            completer.trySetResult(null)
        }

        return true
    }
}
