package com.jhoogstraat.fast_barcode_scanner

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FastBarcodeScannerPlugin */
public class FastBarcodeScannerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private lateinit var reader : BarcodeReader

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner")

    reader = BarcodeReader(flutterPluginBinding.textureRegistry.createSurfaceTexture()) { barcodes ->
      barcodes.firstOrNull()?.also { barcode -> channel.invokeMethod("read", listOf(barcodeStringMap[barcode.format], barcode.rawValue)) }
    }

    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    reader.stop()
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "start" -> reader.start(call.arguments as HashMap<String, Any>, result)
      "stop" -> reader.stop(result)
      "pause" -> reader.pause(result)
      "resume" -> reader.resume(result)
      "toggleTorch" -> reader.toggleTorch(result)
      else -> result.notImplemented()
    }
  }

  // https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration#uiactivity-plugin
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    reader.attachToActivity(binding.activity, FlutterLifecycleAdapter.getActivityLifecycle(binding))
    binding.addRequestPermissionsResultListener(reader)
  }

  override fun onDetachedFromActivity() {
    reader.detachFromActivity()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }
}
