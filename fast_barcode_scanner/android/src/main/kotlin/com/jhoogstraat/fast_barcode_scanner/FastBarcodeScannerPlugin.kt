package com.jhoogstraat.fast_barcode_scanner


import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity

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
  private lateinit var reader: BarcodeReader

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner")

    reader = BarcodeReader(flutterPluginBinding.textureRegistry.createSurfaceTexture()) { barcodes ->
      barcodes.firstOrNull()?.also { barcode -> channel.invokeMethod("read", listOf(barcodeStringMap[barcode.format], barcode.rawValue)) }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {

  }

  // https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration#uiactivity-plugin
  // https://github.com/flutter/plugins/blob/master/packages/camera/android/src/main/java/io/flutter/plugins/camera/CameraPlugin.java
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    reader.attachToActivity(binding.activity as FlutterActivity)
    binding.addRequestPermissionsResultListener(reader)
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromActivity() {
    channel.setMethodCallHandler(null)
    reader.detachFromActivity()
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
      "start" -> reader.start(call.arguments as HashMap<String, Any>, result)
      "stop" -> reader.stop(result)
      "pause" -> reader.stop(result)
      "resume" -> reader.resume(result)
      "toggleTorch" -> reader.toggleTorch(result)
      else -> result.notImplemented()
    }
  }
}
