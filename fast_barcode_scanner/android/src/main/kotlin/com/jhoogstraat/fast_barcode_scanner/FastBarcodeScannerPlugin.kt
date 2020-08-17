package com.jhoogstraat.fast_barcode_scanner

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

/** FastBarcodeScannerPlugin */
public class FastBarcodeScannerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private lateinit var reader : BarcodeReader

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.jhoogstraat/fast_barcode_scanner")
    channel.setMethodCallHandler(this)

    reader = BarcodeReader(flutterPluginBinding.textureRegistry.createSurfaceTexture()) { barcodes ->
      barcodes.firstOrNull()?.also { barcode -> channel.invokeMethod("read", listOf(barcodeStringMap[barcode.format], barcode.rawValue)) }
    }
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val plugin = FastBarcodeScannerPlugin()
      val channel = MethodChannel(registrar.messenger(), "com.jhoogstraat/fast_barcode_scanner")

      plugin.reader = BarcodeReader(registrar.textures().createSurfaceTexture()) { barcodes ->
        barcodes.firstOrNull()?.also { barcode -> channel.invokeMethod("read", listOf(barcodeFormatMap.entries.first { it.value == barcode.format }, barcode.rawValue)) }
      }

      channel.setMethodCallHandler(plugin)
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "start" -> reader.start(call.arguments as HashMap<String, Any>, result)
      "stop" -> reader.stop()
      "pause" -> reader.pause()
      "resume" -> reader.resume()
      "toggleTorch" -> reader.toggleTorch()
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  // https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration#uiactivity-plugin
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    reader.attachTo(binding.activity, FlutterLifecycleAdapter.getActivityLifecycle(binding))
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
