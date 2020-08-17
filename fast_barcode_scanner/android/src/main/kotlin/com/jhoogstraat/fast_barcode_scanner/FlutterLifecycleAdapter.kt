package com.jhoogstraat.fast_barcode_scanner

import androidx.lifecycle.Lifecycle
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference

/** Provides a static method for extracting lifecycle objects from Flutter plugin bindings.  */
object FlutterLifecycleAdapter {
    /**
     * Returns the lifecycle object for the activity a plugin is bound to.
     *
     *
     * Returns null if the Flutter engine version does not include the lifecycle extraction code.
     * (this probably means the Flutter engine version is too old).
     */
    fun getActivityLifecycle(
            activityPluginBinding: ActivityPluginBinding): Lifecycle {
        val reference = activityPluginBinding.lifecycle as HiddenLifecycleReference
        return reference.lifecycle
    }
}