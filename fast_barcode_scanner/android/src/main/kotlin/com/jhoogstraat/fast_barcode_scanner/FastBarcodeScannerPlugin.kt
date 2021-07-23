package com.jhoogstraat.fast_barcode_scanner


import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull
import com.google.mlkit.vision.barcode.Barcode
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
  private lateinit var scanner: BarcodeScanner

  private fun encodeBarcodes(barcodes: List<Barcode>) : List<*>? {
    return barcodes.firstOrNull()?.let { listOf(barcodeStringMap[it.format], it.rawValue, it.valueType) }
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner")
    scanner = BarcodeScanner(flutterPluginBinding.textureRegistry.createSurfaceTexture()) { barcodes ->
      encodeBarcodes(barcodes)?.also { channel.invokeMethod("s", it) }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {

  }

  // https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration#uiactivity-plugin
  // https://github.com/flutter/plugins/blob/master/packages/camera/android/src/main/java/io/flutter/plugins/camera/CameraPlugin.java
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    scanner.attachToActivity(binding.activity)
    binding.addRequestPermissionsResultListener(scanner)
    binding.addActivityResultListener(scanner)
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromActivity() {
    channel.setMethodCallHandler(null)
    scanner.detachFromActivity()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    @Suppress("UNCHECKED_CAST")
    when (call.method) {
      "init" -> scanner.initialize(call.arguments as HashMap<String, Any>, result)
      "start" -> scanner.startCamera(result)
      "stop" -> scanner.stopCamera(result)
      "startDetector" -> scanner.startDetector(result)
      "stopDetector" -> scanner.stopDetector(result)
      "torch" -> scanner.toggleTorch(result)
      "config" -> scanner.changeConfiguration(call.arguments as HashMap<String, Any>, result)
      "scan" -> scanner.scanImage(call.arguments, result)
      else -> result.notImplemented()
    }
  }
}
