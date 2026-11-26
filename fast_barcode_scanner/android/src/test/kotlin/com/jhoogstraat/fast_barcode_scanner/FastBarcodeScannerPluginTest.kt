package com.jhoogstraat.fast_barcode_scanner

import com.jhoogstraat.fast_barcode_scanner.types.CameraInformation
import com.jhoogstraat.fast_barcode_scanner.types.CameraPosition
import com.jhoogstraat.fast_barcode_scanner.types.DetectionMode
import com.jhoogstraat.fast_barcode_scanner.types.PerformanceMode
import com.jhoogstraat.fast_barcode_scanner.types.barcodeFormatMap
import com.jhoogstraat.fast_barcode_scanner.types.barcodeStringMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import org.mockito.Mockito

internal class FastBarcodeScannerPluginTest {
    @Test
    fun cameraInformation_serializesAllFields() {
        val info = CameraInformation(
            videoWidth = 1920.0,
            videoHeight = 1080.0,
            analysisWidth = 1280.0,
            analysisHeight = 720.0,
            textureId = 7L,
            sensorOrientation = 90,
            minZoom = 1.0,
            maxZoom = 8.0
        )

        val serialized = info.serialized()

        assertEquals(listOf(1920.0, 1080.0), serialized["video_size"])
        assertEquals(listOf(320.0, 180.0, 1280.0, 720.0), serialized["analysis_frame"])
        assertEquals(7L, serialized["texture_id"])
        assertEquals(90, serialized["sensor_orientation"])
        assertEquals(1.0, serialized["min_zoom"])
        assertEquals(8.0, serialized["max_zoom"])
    }

    @Test
    fun enumParsing_matchesDartWireNames() {
        assertEquals(PerformanceMode.System, PerformanceMode.fromString("system"))
        assertEquals(PerformanceMode.Economic, PerformanceMode.fromString("economic"))
        assertEquals(PerformanceMode.High, PerformanceMode.fromString("high"))
        assertEquals(DetectionMode.PauseDetection, DetectionMode.fromString("pauseDetection"))
        assertEquals(DetectionMode.PauseVideo, DetectionMode.fromString("pauseVideo"))
        assertEquals(DetectionMode.Continuous, DetectionMode.fromString("continuous"))
        assertEquals(CameraPosition.Front, CameraPosition.fromString("front"))
        assertEquals(CameraPosition.Back, CameraPosition.fromString("back"))

        assertFailsWith<IllegalArgumentException> {
            PerformanceMode.fromString("invalid")
        }
    }

    @Test
    fun barcodeFormatMap_roundTripsAllFormats() {
        for ((name, format) in barcodeFormatMap) {
            assertEquals(name, barcodeStringMap[format])
        }
    }

    @Test
    fun onMethodCall_startWhenUninitialized_returnsNotInitializedError() {
        val plugin = FastBarcodeScannerPlugin()
        val call = MethodCall("start", null)
        val mockResult = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).error(
            "NOT_INITIALIZED",
            "Camera has not been initialized",
            null
        )
    }
}
