package com.jhoogstraat.fast_barcode_scanner

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
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
import java.util.concurrent.Executors

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
    private val imageExecutor = Executors.newSingleThreadExecutor()

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
        dispose()
        pickImageCompleter?.trySetResult(null)
        pickImageCompleter = null
        imageExecutor.shutdown()
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
        pickImageCompleter?.trySetResult(null)
        pickImageCompleter = null
        commandChannel?.setMethodCallHandler(null)
        detectionChannel?.setStreamHandler(null)
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onListen(arguments: Any?, events: EventSink?) {
        detectionEventSink = events
    }

    override fun onCancel(arguments: Any?) {
        detectionEventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            var response: Any? = null

            when (call.method) {
                "init" -> {
                    val args = call.arguments as? Map<*, *>
                        ?: throw ScannerException.InvalidArguments(call.arguments)
                    val (newCamera, task) = initialize(args)
                    task
                        .addOnSuccessListener { result.success(it.serialized()) }
                        .addOnFailureListener { error ->
                            if (this.camera === newCamera) dispose()
                            (error as? ScannerException ?: ScannerException.Unknown(error))
                                .throwFlutterError(result)
                        }
                    return
                }

                "scan" -> {
                    scanImage(call.arguments)
                        .addOnSuccessListener { barcodes ->
                            result.success(barcodes?.let(::encode))
                        }
                        .addOnFailureListener { error ->
                            (error as? ScannerException ?: ScannerException.Unknown(error))
                                .throwFlutterError(result)
                        }
                    return
                }

                "dispose" -> dispose()

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
                            future.addListener({
                                try {
                                    future.get()
                                    result.success(activeCamera.torchState)
                                } catch (e: Exception) {
                                    ScannerException.Unknown(e).throwFlutterError(result)
                                }
                            }, ContextCompat.getMainExecutor(activeCamera.activity))
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

    private fun encode(barcodes: List<Barcode>): List<List<Any?>> =
        barcodes.mapNotNull { barcode ->
            val type = barcodeStringMap[barcode.format] ?: return@mapNotNull null
            val rawValue = barcode.rawValue ?: return@mapNotNull null
            val box = barcode.boundingBox?.let {
                listOf(it.left.toDouble(), it.top.toDouble(), it.right.toDouble(), it.bottom.toDouble())
            }
            val corners = barcode.cornerPoints?.map { listOf(it.x.toDouble(), it.y.toDouble()) }
            listOf(type, rawValue, box, corners)
        }

    private fun initialize(configuration: Map<*, *>): Pair<Camera, Task<CameraInformation>> {
        if (this.camera != null) dispose()

        val pluginBinding = this.pluginBinding ?: throw ScannerException.ActivityNotConnected()
        val activityBinding = this.activityBinding ?: throw ScannerException.ActivityNotConnected()

        val newCamera = Camera(
            activity = activityBinding.activity,
            flutterTextureEntry = pluginBinding.textureRegistry.createSurfaceTexture(),
            args = configuration
        ) { barcodes ->
            val encoded = encode(barcodes)
            if (encoded.isNotEmpty()) detectionEventSink?.success(encoded)
        }

        this.camera = newCamera
        activityBinding.addRequestPermissionsResultListener(newCamera)

        val task = newCamera.requestPermissions().continueWithTask { permissionTask ->
            if (!permissionTask.isSuccessful) {
                Tasks.forException(permissionTask.exception ?: ScannerException.Unauthorized())
            } else {
                newCamera.loadCamera()
            }
        }
        return newCamera to task
    }

    private fun dispose() {
        camera?.let { activeCamera ->
            activityBinding?.removeRequestPermissionsResultListener(activeCamera)
            activeCamera.dispose()
        }
        camera = null
    }

    private fun processStillImage(
        image: InputImage,
        onComplete: () -> Unit = {}
    ): Task<List<Barcode>> {
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .build()
        val scanner = BarcodeScanning.getClient(options)
        return scanner.process(image).addOnCompleteListener {
            scanner.close()
            onComplete()
        }
    }

    private fun scanImage(source: Any?): Task<List<Barcode>?> = when (source) {
        is List<*> -> {
            val bytes = source.getOrNull(0) as? ByteArray
                ?: throw ScannerException.InvalidImageData()
            val rotation = (source.getOrNull(1) as? Number)?.toInt() ?: 0

            Tasks.call(imageExecutor) {
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: throw ScannerException.InvalidImageData()
            }.continueWithTask { bitmapTask ->
                val bitmap = bitmapTask.result
                processStillImage(InputImage.fromBitmap(bitmap, rotation)) { bitmap.recycle() }
            }
        }

        else -> {
            if (pickImageCompleter?.task?.isComplete == false) {
                throw ScannerException.AlreadyPicking()
            }

            val binding = activityBinding ?: throw ScannerException.ActivityNotConnected()
            val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                .apply { type = "image/*" }

            val completer = TaskCompletionSource<Uri?>()
            pickImageCompleter = completer

            try {
                binding.activity.startActivityForResult(intent, PICK_IMAGE_REQUEST_CODE)
            } catch (e: Exception) {
                pickImageCompleter = null
                throw ScannerException.Unknown(e)
            }

            completer.task.continueWithTask { uriTask ->
                val uri = if (uriTask.isSuccessful) uriTask.result else null
                if (uri == null) {
                    Tasks.forResult(null)
                } else {
                    Tasks.call(imageExecutor) {
                        try {
                            InputImage.fromFilePath(binding.activity, uri)
                        } catch (e: IOException) {
                            throw ScannerException.LoadingFailed(e)
                        }
                    }.continueWithTask { imageTask ->
                        processStillImage(imageTask.result)
                    }
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_IMAGE_REQUEST_CODE) return false
        val completer = pickImageCompleter ?: return false
        pickImageCompleter = null
        completer.trySetResult(if (resultCode == Activity.RESULT_OK) data?.data else null)
        return true
    }
}
