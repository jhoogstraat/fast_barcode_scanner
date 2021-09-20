package com.jhoogstraat.fast_barcode_scanner

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.jhoogstraat.fast_barcode_scanner.types.PreviewConfiguration
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
class FastBarcodeScannerPlugin : FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private var commandChannel: MethodChannel? = null
    private var detectionChannel: EventChannel? = null
    private var detectionEventSink: EventSink? = null

    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var camera: Camera? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
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

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        commandChannel!!.setMethodCallHandler(this)
        detectionChannel!!.setStreamHandler(this)
        activityBinding = binding

        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        dispose()

        commandChannel?.setMethodCallHandler(null)
        detectionChannel?.setStreamHandler(null)
        activityBinding?.removeActivityResultListener(this)

        commandChannel = null
        detectionChannel = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    /* Detections EventChannel */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        detectionEventSink = events
    }

    override fun onCancel(arguments: Any?) {
        detectionEventSink = null
    }

    /* Command MethodChannel */
    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        try {
            var response: Any? = null

            when (call.method) {
                "init" -> {
                    initialize(call.arguments as HashMap<String, Any>)
                        .addOnSuccessListener { result.success(it.toMap()) }
                        .addOnFailureListener { throw it }
                    return
                }
                "scan" -> {
                    scanImage(call.arguments)
                        .addOnSuccessListener { barcodes ->
                            result.success(barcodes?.map { encode(it) })
                        }
                        .addOnFailureListener {
                            throw ScannerException.AnalysisFailed(it)
                        }
                    return
                }
                else -> {
                    val camera = this.camera ?: throw ScannerException.NotInitialized()
                    when (call.method) {
                        "start" -> camera.startCamera()
                        "stop" -> camera.stopCamera()
                        "startDetector" -> camera.startDetector()
                        "stopDetector" -> camera.stopDetector()
                        "config" -> response =
                            camera.changeConfiguration(call.arguments as HashMap<String, Any>)
                                .toMap()
                        "torch" -> {
                            camera.toggleTorch()
                                .addListener(
                                    { result.success(camera.torchState) },
                                    ContextCompat.getMainExecutor(camera.activity)
                                )
                            return
                        }
                        "dispose" -> dispose()
                        else -> result.notImplemented()
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

    private fun encode(barcode: Barcode): List<*> {
        return listOf(
            barcodeStringMap[barcode.format],
            barcode.rawValue,
            barcode.valueType
        )
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun initialize(configuration: HashMap<String, Any>): Task<PreviewConfiguration> {
        if (this.camera != null)
            throw ScannerException.AlreadyInitialized()

        val pluginBinding = this.pluginBinding ?: throw ScannerException.ActivityNotConnected()
        val activityBinding = this.activityBinding ?: throw ScannerException.ActivityNotConnected()

        val camera = Camera(
            activityBinding.activity,
            pluginBinding.textureRegistry.createSurfaceTexture(),
            configuration
        ) { barcodes ->
            detectionEventSink?.success(encode(barcodes.first()))
        }

        this.camera = camera

        activityBinding.addRequestPermissionsResultListener(camera)

        return camera.requestPermissions()
            .continueWithTask { camera.loadCamera() }
    }

    private fun dispose() {
        camera?.also {
            it.stopCamera()
            it.flutterTextureEntry.release()
            activityBinding?.removeRequestPermissionsResultListener(it)
        }

        camera = null
    }

    private var pickImageCompleter: TaskCompletionSource<Uri?>? = null
    private fun scanImage(source: Any?): Task<List<Barcode>?> {
        val options =
            BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS).build()
        val scanner = BarcodeScanning.getClient(options)

        return when (source) {
            // Binary
            is List<*> -> scanner.process(
                InputImage.fromBitmap(
                    BitmapFactory.decodeByteArray(
                        source[0] as ByteArray,
                        0,
                        (source[0] as ByteArray).size
                    ),
                    source[1] as Int
                )
            )
            // Path
            is String -> {
                val activity =
                    activityBinding?.activity ?: throw ScannerException.ActivityNotConnected()
                return scanner.process(InputImage.fromFilePath(activity, Uri.parse(source)))
            }
            // Picker
            else -> {
                if (pickImageCompleter?.task?.isComplete == false)
                    throw ScannerException.AlreadyPicking()

                val activityBinding =
                    activityBinding ?: throw ScannerException.ActivityNotConnected()

                val intent = Intent(
                    Intent.ACTION_PICK,
                    MediaStore.Images.Media.INTERNAL_CONTENT_URI
                )
                intent.type = "image/*"

                this.pickImageCompleter = TaskCompletionSource<Uri?>()

                activityBinding.activity.startActivityForResult(intent, 1)

                return pickImageCompleter!!.task.continueWithTask {
                    if (it.result == null) Tasks.forResult(null) else
                        scanner.process(InputImage.fromFilePath(activityBinding.activity, it.result))
                }
            }
        }
    }

    /* Activity Result Listener for picking images from Intent */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 1) {
            return false
        }

        val completer = pickImageCompleter ?: return false

        when (resultCode) {
            Activity.RESULT_OK -> {
                try {
                    completer.setResult(data?.data)
                } catch (e: IOException) {
                    completer.setException(ScannerException.LoadingFailed(e))
                }
            }
            else -> {
                completer.setResult(null)
            }
        }

        pickImageCompleter = null

        return true
    }
}
