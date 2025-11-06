package com.icapps.icapps_fast_barcode_scanner


import androidx.annotation.NonNull
import android.app.Activity
import androidx.camera.core.CameraSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** FastBarcodeScannerPlugin */
class FastBarcodeScannerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var channel : MethodChannel
  private var reader: BarcodeReader? = null

  private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
  private var activity: Activity? = null


  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.pluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.icapps/icapps_fast_barcode_scanner")
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    this.pluginBinding = null
  }

  // https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration#uiactivity-plugin
  // https://github.com/flutter/plugins/blob/master/packages/camera/android/src/main/java/io/flutter/plugins/camera/CameraPlugin.java
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
      this.activity = binding.activity
      binding.addRequestPermissionsResultListener(this)
      channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromActivity() {
      channel.setMethodCallHandler(null)
      reader?.detachFromActivity()
      this.activity = null
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return reader?.onRequestPermissionsResult(requestCode, permissions, grantResults) ?: false
    }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    @Suppress("UNCHECKED_CAST")
    when (call.method) {
      "start" -> {
          if (activity == null) {
              result.error("0", "Activity not connected!", null)
              return
          }

          pluginBinding?.let { binding ->
              if (reader == null) {
                  reader =
                      BarcodeReader(binding.textureRegistry.createSurfaceTexture()) { barcodes ->
                          barcodes.firstOrNull()?.also { barcode ->
                              channel.invokeMethod(
                                  "read",
                                  listOf(barcodeStringMap[barcode.format], barcode.rawValue)
                              )
                          }
                      }
                  reader!!.attachToActivity(activity!!)
              }

              // Start the reader *inside* the null-safe block
              reader!!.start(call.arguments as HashMap<String, Any>, result)

          } ?: run {
              // This runs if pluginBinding is null
              result.error("1", "Plugin not attached to an engine.", null)
          }
          reader!!.start(call.arguments as HashMap<String, Any>, result)
      }
      "stop" -> reader?.stop(result)
      "pause" -> reader?.stop(result)
      "resume" -> reader?.resume(result)
      "toggleTorch" -> reader?.toggleTorch(result)
      "canChangeCamera" -> {
          if (activity == null) {
              result.error("0", "Activity not connected!", null)
              return
          }
          try {
              val cameraProviderFuture = ProcessCameraProvider.getInstance(activity!!)
              cameraProviderFuture.addListener({
                  val cameraProviderForChangeCamera = cameraProviderFuture.get()
                  val hasFrontCamera =
                      cameraProviderForChangeCamera.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)
                  val hasBackCamera =
                      cameraProviderForChangeCamera.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)
                  result.success(hasFrontCamera && hasBackCamera)
              }, ContextCompat.getMainExecutor(activity!!))
          } catch (exc: Exception) {
              result.success(false)
          }
      }
      "changeCamera" -> reader?.changeCamera(call.arguments as String, result)
      else -> result.notImplemented()
    }
  }
}
