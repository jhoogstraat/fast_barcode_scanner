package com.jhoogstraat.fast_barcode_scanner

import android.util.Log
import androidx.annotation.NonNull
import com.google.mlkit.vision.barcode.Barcode
import com.jhoogstraat.fast_barcode_scanner.types.ScannerError
import com.jhoogstraat.fast_barcode_scanner.types.barcodeStringMap

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FastBarcodeScannerPlugin */
class FastBarcodeScannerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private lateinit var pluginBinding: FlutterPlugin.FlutterPluginBinding
  private var activityBinding: ActivityPluginBinding? = null

  private var scanner: BarcodeScanner? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner")
    this.pluginBinding = flutterPluginBinding
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    // TODO: Remove plugin binding?
    dispose()
  }

  // https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration#uiactivity-plugin
  // https://github.com/flutter/plugins/blob/master/packages/camera/android/src/main/java/io/flutter/plugins/camera/CameraPlugin.java
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    channel.setMethodCallHandler(this)
    activityBinding = binding
  }

  override fun onDetachedFromActivity() {
    channel.setMethodCallHandler(null)
    scanner?.detachFromActivity()
    activityBinding = null
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  @Suppress("UNCHECKED_CAST")
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "init") {
      initialize(call.arguments as HashMap<String, Any>, result)
    } else {
      val scanner = this.scanner ?: run {
        ScannerError.NotInitialized().throwFlutterError(result)
        return
      }

      when (call.method) {
        "start" -> scanner.startCamera(result)
        "stop" -> scanner.stopCamera(result)
        "startDetector" -> scanner.startDetector(result)
        "stopDetector" -> scanner.stopDetector(result)
        "torch" -> scanner.toggleTorch(result)
        "config" -> scanner.changeConfiguration(call.arguments as HashMap<String, Any>, result)
        "scan" -> scanner.scanImage(call.arguments, result)
        "dispose" -> dispose(result)
        else -> result.notImplemented()
      }
    }
  }

  private fun encodeBarcodes(barcodes: List<Barcode>) : List<*>? {
    return barcodes.firstOrNull()?.let { listOf(barcodeStringMap[it.format], it.rawValue, it.valueType) }
  }

  private fun initialize(configuration: HashMap<String, Any>, result: Result) {
    if (scanner != null) {
      ScannerError.AlreadyInitialized().throwFlutterError(result)
      return
    }

    val binding = activityBinding ?: run {
      ScannerError.ActivityNotConnected().throwFlutterError(result)
      return
    }

    val scanner = BarcodeScanner(pluginBinding.textureRegistry.createSurfaceTexture()) { barcodes ->
      encodeBarcodes(barcodes)?.also { channel.invokeMethod("s", it) }
    }

    Log.d("ME", "initialize: $configuration")
    scanner.attachToActivity(binding.activity)
    binding.addRequestPermissionsResultListener(scanner)
    binding.addActivityResultListener(scanner)

    this.scanner = scanner

    scanner.initialize(configuration, result)
  }

  private fun dispose(result: Result? = null) {
    scanner?.let {
      it.stopCamera()
      activityBinding?.removeRequestPermissionsResultListener(it)
      activityBinding?.removeActivityResultListener(it)
    }
    scanner = null
    result?.success(null)
  }
}
