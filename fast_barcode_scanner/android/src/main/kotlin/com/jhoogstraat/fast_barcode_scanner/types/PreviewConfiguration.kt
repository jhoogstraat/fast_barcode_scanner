package com.jhoogstraat.fast_barcode_scanner.types

data class PreviewConfiguration(val textureId: Long, val targetRotation: Int, val width: Int,
                                val height: Int, val analysisWidth: Int,
                                val analysisHeight: Int) {
    fun toMap() = hashMapOf(
            "textureId" to textureId,
            "targetRotation" to targetRotation,
            "width" to width,
            "height" to height,
            "analysis" to "${analysisWidth}x${analysisHeight}",
            "analysisWidth" to analysisWidth,
            "analysisHeight" to analysisHeight)
}
