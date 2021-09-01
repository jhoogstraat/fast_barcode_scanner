package com.jhoogstraat.fast_barcode_scanner

import android.annotation.SuppressLint
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.barcode.Barcode
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

/** FastBarcodeScannerPlugin */
class FastBarcodeScannerPlugin : FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware {
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
    }

    override fun onDetachedFromActivity() {
        dispose()

        commandChannel?.setMethodCallHandler(null)
        detectionChannel?.setStreamHandler(null)

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

            if (call.method == "init") {
                initialize(call.arguments as HashMap<String, Any>)
                    .addOnSuccessListener { result.success(it.toMap()) }
                    .addOnFailureListener { throw it }
                return
            } else {
                val camera = this.camera ?: throw ScannerException.NotInitialized()
                when (call.method) {
                    "start" -> camera.startCamera()
                    "stop" -> camera.stopCamera()
                    "startDetector" -> camera.startDetector()
                    "stopDetector" -> camera.stopDetector()
                    "config" -> response =
                        camera.changeConfiguration(call.arguments as HashMap<String, Any>).toMap()
                    "torch" -> {
                        camera.toggleTorch()
                            .addListener(
                                { result.success(camera.torchState) },
                                ContextCompat.getMainExecutor(camera.activity)
                            )
                        return
                    }
                    "scan" -> {
                        camera.scanImage(call.arguments)
                            .addOnSuccessListener { barcodes ->
                                result.success(barcodes.map { encode(it) })
                            }
                            .addOnFailureListener {
                                throw ScannerException.AnalysisFailed(it)
                            }
                        return
                    }
                    "dispose" -> dispose()
                    else -> result.notImplemented()
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

        activityBinding.addActivityResultListener(camera)
        activityBinding.addRequestPermissionsResultListener(camera)

        this.camera = camera

        return camera.requestPermissions()
            .continueWithTask { camera.loadCamera() }
    }

    private fun dispose() {
        camera?.also {
            it.stopCamera()
            activityBinding?.removeActivityResultListener(it)
        }

        camera = null
    }
}
