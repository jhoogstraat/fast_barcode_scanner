package com.jhoogstraat.fast_barcode_scanner.types

data class PreviewConfiguration(val textureId: Long, val targetRotation: Int, val width: Int, val height: Int, val analysis: String) {
    fun toMap() = hashMapOf("textureId" to textureId, "targetRotation" to targetRotation, "width" to width, "height" to height, "analysis" to analysis)
}
