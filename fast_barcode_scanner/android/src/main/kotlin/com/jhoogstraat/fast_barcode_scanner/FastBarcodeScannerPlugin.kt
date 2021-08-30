package com.jhoogstraat.fast_barcode_scanner

import android.annotation.SuppressLint
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Continuation
import com.google.android.gms.tasks.Task
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.barcode.Barcode
import com.jhoogstraat.fast_barcode_scanner.types.PreviewConfiguration
import com.jhoogstraat.fast_barcode_scanner.types.ScannerException
import com.jhoogstraat.fast_barcode_scanner.types.barcodeStringMap

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import java.lang.Exception

/** FastBarcodeScannerPlugin */
class FastBarcodeScannerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private var commandChannel : MethodChannel? = null
  private var detectionChannel: EventChannel? = null
  private var barcodeStreamHandler: BarcodeStreamHandler? = null

  private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
  private var activityBinding: ActivityPluginBinding? = null
  private var camera: Camera? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    commandChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner")
    detectionChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner/detections")
    barcodeStreamHandler = BarcodeStreamHandler()
    pluginBinding = flutterPluginBinding

    commandChannel!!.setMethodCallHandler(this)
    detectionChannel!!.setStreamHandler(barcodeStreamHandler)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    commandChannel?.setMethodCallHandler(null)
    detectionChannel?.setStreamHandler(null)

    commandChannel = null
    detectionChannel = null
    barcodeStreamHandler = null
    pluginBinding = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    commandChannel!!.setMethodCallHandler(this)
    detectionChannel!!.setStreamHandler(BarcodeStreamHandler())
    activityBinding = binding
  }

  override fun onDetachedFromActivity() {
    dispose()
    activityBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  @Suppress("UNCHECKED_CAST")
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    try {
      var response: Any? = null

      if (call.method == "init") {
        initialize(call.arguments as HashMap<String, Any>)
          .addOnSuccessListener { result.success(it.toMap()) }
          .addOnFailureListener { (it as ScannerException).throwFlutterError(result) }
        return
      } else {
        val camera = this.camera ?: throw ScannerException.NotInitialized()
        when (call.method) {
          "start" -> camera.startCamera()
          "stop" -> camera.stopCamera()
          "startDetector" -> camera.startDetector()
          "stopDetector" -> camera.stopDetector()
          "config" -> response = camera.changeConfiguration(call.arguments as HashMap<String, Any>).toMap()
          "torch" -> {
            camera.toggleTorch()
              .addListener({ result.success(camera.torchState) }, ContextCompat.getMainExecutor(camera.activity))
            return
          }
          "scan" -> {
            camera.scanImage(call.arguments)
              .addOnSuccessListener { barcodes ->
                result.success(barcodes.map { listOf(barcodeStringMap[it.format], it.rawValue, it.valueType) })
              }
              .addOnFailureListener { ScannerException.AnalysisFailed(it).throwFlutterError(result) }
            return
          }
          "dispose" -> dispose(result)
          else -> result.notImplemented()
        }
      }

      Log.d("PLUGIN", "onMethodCall: $response")
      result.success(response)
    } catch (e: ScannerException) {
      Log.d("PLUGIN", "onMethodCall.catch(ScannerException): $e ${e.stackTraceToString()}")
      e.throwFlutterError(result)
    } catch(e: Exception) {
      Log.d("PLUGIN", "onMethodCall.catch(Exception): $e ${e.stackTraceToString()}")
      result.error("UNKNOWN", "Unknown error occurred", e.localizedMessage)
    }
  }

  @SuppressLint("UnsafeOptInUsageError")
  private fun initialize(configuration: HashMap<String, Any>): Task<PreviewConfiguration> {
    if (this.camera != null)
      throw ScannerException.AlreadyInitialized()

    val pluginBinding = this.pluginBinding ?: throw ScannerException.ActivityNotConnected()
    val activityBinding = this.activityBinding ?: throw ScannerException.ActivityNotConnected()

    val camera = Camera(activityBinding.activity, pluginBinding.textureRegistry.createSurfaceTexture(), configuration) { barcodes ->
      barcodes.firstOrNull()?.also {
        barcodeStreamHandler?.push(listOf(barcodeStringMap[it.format], it.rawValue, it.valueType) )
      }
    }

    activityBinding.addActivityResultListener(camera)
    activityBinding.addRequestPermissionsResultListener(camera)

    this.camera = camera

    return camera.requestPermissions()
      .continueWithTask { camera.loadCamera() }
  }

  private fun dispose(result: Result? = null) {
    camera?.also {
      it.stopCamera()
      activityBinding?.removeActivityResultListener(it)
    }

    camera = null

    result?.success(null)
  }

}

class BarcodeStreamHandler: EventChannel.StreamHandler {
  private var eventSink: EventChannel.EventSink? = null

  fun push(barcodes: List<*> ) {
    eventSink?.success(barcodes)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}
