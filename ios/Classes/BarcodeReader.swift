//
//  BarcodeReader.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 16.07.20.
//

import AVFoundation
import Flutter

// Lookup AVMetadataObject
let avMetadataObjectTypes: [String: AVMetadataObject.ObjectType] =
	[
		"aztec": .aztec,
		"cod128":.code128,
		"code39": .code39,
		"code39mod43": .code39Mod43,
		"code93": .code93,
		"dataMatrix": .dataMatrix,
		"ean13": .ean13,
		"ean8": .ean8,
		"itf":  .itf14,
		"pdf417":. pdf417,
		"qr": .qr,
		"upcE": .upce,
		"interleaved": .interleaved2of5
]

// Reverse lookup flutter type
let flutterMetadataObjectTypes = Dictionary(uniqueKeysWithValues: avMetadataObjectTypes.map({ ($1, $0) }))

enum ReaderError: Error {
	case noInputDevice
	case cameraNotSuitable(Resolution, Framerate)
}

enum Resolution: String {
	case sd480, hd720, hd1080, hd4k

	var width: Int32 {
		switch self {
		case .sd480: return 720
		case .hd720: return 1280
		case .hd1080: return 1920
		case .hd4k: return 3840
		}
	}

	var height: Int32 {
		switch self {
		case .sd480: return 480
		case .hd720: return 720
		case .hd1080: return 1080
		case .hd4k: return 2160
		}
	}
}

enum Framerate: String {
	case fps30, fps60, fps120, fps240

	var doubleValue: Double {
		switch self {
		case .fps30: return 30
		case .fps60: return 60
		case .fps120: return 120
		case .fps240: return 240
		}
	}
}

enum DetectionMode: String {
	case pauseDetection, pauseDetectionAndVideo, continuous
}

class BarcodeReader: NSObject {
	let textureRegistry: FlutterTextureRegistry
	var textureId: Int64!
	var pixelBuffer: CVPixelBuffer?

	var captureDevice: AVCaptureDevice!
	var captureSession: AVCaptureSession
	let dataOutput: AVCaptureVideoDataOutput
	let metadataOutput: AVCaptureMetadataOutput
	let codeCallback: ([String]) -> Void
	let detectionMode: DetectionMode
	let cameraPosition = AVCaptureDevice.Position.back
	var torchActiveBeforeStop = false
	var previewSize: CMVideoDimensions!

	init(textureRegistry: FlutterTextureRegistry, arguments: StartArgs, codeCallback: @escaping ([String]) -> Void) throws {
		self.textureRegistry = textureRegistry
		self.codeCallback = codeCallback
		self.captureSession = AVCaptureSession()
		self.dataOutput = AVCaptureVideoDataOutput()
		self.metadataOutput = AVCaptureMetadataOutput()
		self.detectionMode = arguments.detectionMode
		super.init()

		captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)

		guard captureDevice != nil else {
			throw ReaderError.noInputDevice
		}

		let input = try! AVCaptureDeviceInput(device: captureDevice)

		captureSession.addInput(input)
		captureSession.addOutput(dataOutput)
		captureSession.addOutput(metadataOutput)

		dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
		dataOutput.connection(with: .video)?.videoOrientation = .portrait // TODO: Get real interface orientation
		dataOutput.alwaysDiscardsLateVideoFrames = true
		dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))

		metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
		metadataOutput.metadataObjectTypes = arguments.codes.compactMap { avMetadataObjectTypes[$0] }

		guard let optimalFormat = captureDevice.formats.first(where: {
			let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
			let mediaSubType = CMFormatDescriptionGetMediaSubType($0.formatDescription).toString()

			return $0.videoSupportedFrameRateRanges.first!.maxFrameRate >= arguments.framerate.doubleValue
				&& dimensions.height >= arguments.resolution.height
				&& dimensions.width >= arguments.resolution.width
				&& mediaSubType == "420f" // maybe 420v is also ok? Who knows...
		}) else {
			throw ReaderError.cameraNotSuitable(arguments.resolution, arguments.framerate)
		}

		try! captureDevice.lockForConfiguration()
		captureDevice.activeFormat = optimalFormat
		captureDevice.activeVideoMinFrameDuration = optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
		captureDevice.activeVideoMaxFrameDuration = optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
		captureDevice.unlockForConfiguration()

		previewSize = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
	}

	func start(fromPause: Bool) {
		captureSession.startRunning()

		if !fromPause {
			self.textureId = textureRegistry.register(self)
		}

		if (torchActiveBeforeStop) {
			try! captureDevice.lockForConfiguration()
			captureDevice.torchMode = .on
			captureDevice.unlockForConfiguration()
			torchActiveBeforeStop = false
		}
	}

	func stop(pause: Bool) {
		torchActiveBeforeStop = captureDevice.isTorchActive
		captureSession.stopRunning()
		if !pause {
			pixelBuffer = nil
			textureRegistry.unregisterTexture(textureId)
			textureId = nil
		}
	}

	func toggleTorch() {
		try! captureDevice.lockForConfiguration()
		captureDevice.torchMode = captureDevice.isTorchActive ? .off : .on
		captureDevice.unlockForConfiguration()
	}

	func pauseIfRequired() {
		switch detectionMode {
		case .continuous: return
		case .pauseDetection:
			captureSession.removeOutput(metadataOutput)
		case .pauseDetectionAndVideo:
			stop(pause: true)
		}
	}

	func resume() {
		switch detectionMode {
		case .continuous: return
		case .pauseDetection:
			captureSession.addOutput(metadataOutput)
		case .pauseDetectionAndVideo:
			start(fromPause: true)
		}
	}

}

extension BarcodeReader: FlutterTexture {
	func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
		pixelBuffer == nil ? nil : .passRetained(pixelBuffer!)
	}
}

extension BarcodeReader: AVCaptureVideoDataOutputSampleBufferDelegate {
	// runs on dispatch queue
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
		textureRegistry.textureFrameAvailable(textureId)
	}
}

extension BarcodeReader: AVCaptureMetadataOutputObjectsDelegate {
	// runs on dispatch queue
	func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
		guard
			let metadata = metadataObjects.first,
			let readableCode = metadata as? AVMetadataMachineReadableCodeObject
			else { return }

		pauseIfRequired()

		codeCallback([flutterMetadataObjectTypes[readableCode.type]!, readableCode.stringValue!])
	}
}

extension FourCharCode {
	func toString() -> String {
		String(cString: [
			CChar(self >> 24 & 0xFF),
			CChar(self >> 16 & 0xFF),
			CChar(self >> 8 & 0xFF),
			CChar(self & 0xFF),
			0
		])
	}
}

