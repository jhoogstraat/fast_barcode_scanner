package com.jhoogstraat.fast_barcode_scanner.types

data class CameraInformation(
    val videoWidth: Double,
    val videoHeight: Double,
    val analysisWidth: Double,
    val analysisHeight: Double,
    val textureId: Long,
    val sensorOrientation: Int = 90,
    val minZoom: Double = 1.0,
    val maxZoom: Double = 1.0
) {
    fun serialized(): Map<String, Any> {
        val offsetX = maxOf(0.0, videoWidth - analysisWidth)
        val offsetY = maxOf(0.0, videoHeight - analysisHeight)

        return mapOf(
            "video_size" to listOf(videoWidth, videoHeight),
            "analysis_frame" to listOf(offsetX / 2.0, offsetY / 2.0, analysisWidth, analysisHeight),
            "texture_id" to textureId,
            "sensor_orientation" to sensorOrientation,
            "min_zoom" to minZoom,
            "max_zoom" to maxZoom
        )
    }
}
