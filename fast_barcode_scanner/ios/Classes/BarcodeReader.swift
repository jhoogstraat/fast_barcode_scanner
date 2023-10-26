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
		"code128": .code128,
		"code39": .code39,
		"code39mod43": .code39Mod43,
		"code93": .code93,
		"dataMatrix": .dataMatrix,
		"ean13": .ean13,
		"ean8": .ean8,
		"itf": .itf14,
		"pdf417": .pdf417,
		"qr": .qr,
		"upcE": .upce,
		"interleaved": .interleaved2of5,
	]

let cameraPositions: [String: AVCaptureDevice.Position] = [
	"front": .front,
	"back": .back,
]

// Reverse lookup flutter type
let flutterMetadataObjectTypes = Dictionary(uniqueKeysWithValues: avMetadataObjectTypes.map { ($1, $0) })

enum ReaderError: Error {
	case noInputDevice
	case cameraNotSuitable(Resolution, Framerate)
	case unauthorized
	case configurationLockError(Error)
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
	case pauseDetection, pauseVideo, continuous
}

class BarcodeReader: NSObject {
	let textureRegistry: FlutterTextureRegistry
	var textureId: Int64!
	var pixelBuffer: CVPixelBuffer?

	var captureDevice: AVCaptureDevice!
	var captureSession: AVCaptureSession
	let dataOutput: AVCaptureVideoDataOutput

	var metadataOutput: AVCaptureMetadataOutput
	let codeCallback: ([String]) -> Void

	var position: AVCaptureDevice.Position
	let detectionMode: DetectionMode
	let framerate: Framerate
	let resolution: Resolution
	let codes: [String]

	var torchActiveOnStop = false
	var isForcePaused = false
	var previewSize: CMVideoDimensions!

	init(textureRegistry: FlutterTextureRegistry,
	     arguments: StartArgs,
	     codeCallback: @escaping ([String]) -> Void) throws
	{
		self.textureRegistry = textureRegistry
		self.codeCallback = codeCallback

		captureSession = AVCaptureSession()
		dataOutput = AVCaptureVideoDataOutput()
		metadataOutput = AVCaptureMetadataOutput()

		detectionMode = arguments.detectionMode
		position = arguments.position
		framerate = arguments.framerate
		resolution = arguments.resolution
		codes = arguments.codes

		super.init()

		do {
			try setupCaptureDevice(arguments)
		} catch {
			throw error
		}
	}

	private func setupCaptureDevice(_ arguments: StartArgs) throws {
		captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)

		guard captureDevice != nil else {
			throw ReaderError.noInputDevice
		}

		do {
			let input = try AVCaptureDeviceInput(device: captureDevice)
			captureSession.addInput(input)
		} catch let error as AVError {
			if error.code == AVError.applicationIsNotAuthorizedToUseDevice {
				throw ReaderError.unauthorized
			}
			throw error
		}

		captureSession.addOutput(dataOutput)
		captureSession.addOutput(metadataOutput)

		dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
		dataOutput.connection(with: .video)?.videoOrientation = .portrait
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

		do {
			try captureDevice.lockForConfiguration()
			captureDevice.activeFormat = optimalFormat
			captureDevice.activeVideoMinFrameDuration =
				optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
			captureDevice.activeVideoMaxFrameDuration =
				optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
			captureDevice.unlockForConfiguration()
		} catch {
			throw ReaderError.configurationLockError(error)
		}

		previewSize = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
	}

	func start(fromPause: Bool) throws {
		guard captureDevice != nil else { return }

		captureSession.startRunning()

		if !fromPause {
			textureId = textureRegistry.register(self)
		}

		if torchActiveOnStop {
			do {
				try captureDevice.lockForConfiguration()
				captureDevice.torchMode = .on
				captureDevice.unlockForConfiguration()
				torchActiveOnStop = false
			} catch {
				throw ReaderError.configurationLockError(error)
			}
		}
	}

	func stop(pause: Bool) {
		guard captureDevice != nil else { return }

		torchActiveOnStop = captureDevice.isTorchActive
		captureSession.stopRunning()
		if !pause {
			pixelBuffer = nil
			textureRegistry.unregisterTexture(textureId)
			textureId = nil
		}
	}

	func toggleTorch() -> Bool {
		guard captureDevice != nil, captureDevice.isTorchAvailable else { return false }

		do {
			try captureDevice.lockForConfiguration()
			captureDevice.torchMode = captureDevice.isTorchActive ? .off : .on
			captureDevice.unlockForConfiguration()
		} catch {
			print(error)
			return false
		}

		return captureDevice.isTorchActive
	}

	func pauseIfRequired(force: Bool = false) {
		if force {
		    isForcePaused = true
			stop(pause: true)
		} else {
			switch detectionMode {
			case .continuous: return
			case .pauseDetection:
				captureSession.removeOutput(metadataOutput)
			case .pauseVideo:
				stop(pause: true)
			}
		}
	}

	func resume() throws {
		switch detectionMode {
		case .continuous:
            if(isForcePaused){
                isForcePaused = false
                try start(fromPause: true)
            }
		    return
		case .pauseDetection:
			guard !captureSession.outputs.contains(metadataOutput) else { return }

			let types = metadataOutput.metadataObjectTypes
			metadataOutput = AVCaptureMetadataOutput()
			metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
			metadataOutput.metadataObjectTypes = types
			captureSession.addOutput(metadataOutput)
		case .pauseVideo:
			try start(fromPause: true)
		}
	}

	func changeCamera(type: String) {
		position = type == "front" ? .front : .back
		reloadCamera()
	}

	func toggleCamera() {
		position = position.toggled()
		reloadCamera()
	}

	private func reloadCamera() {
		captureSession.stopRunning()

		captureSession.outputs.forEach { captureSession.removeOutput($0) }
		captureSession.inputs.forEach { captureSession.removeInput($0) }

		do {
			let arguments = StartArgs(position: position, detectionMode: detectionMode, framerate: framerate, resolution: resolution, codes: codes)
			try setupCaptureDevice(arguments)
		} catch {
			print(error)
		}

		captureSession.startRunning()
	}
}

private extension AVCaptureDevice.Position {
	func toggled() -> AVCaptureDevice.Position {
		switch self {
		case .back:
			return .front
		default:
			return .back
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
	func captureOutput(_: AVCaptureOutput,
	                   didOutput sampleBuffer: CMSampleBuffer,
	                   from _: AVCaptureConnection)
	{
		pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
		textureRegistry.textureFrameAvailable(textureId)
	}
}

extension BarcodeReader: AVCaptureMetadataOutputObjectsDelegate {
	// runs on dispatch queue
	func metadataOutput(_: AVCaptureMetadataOutput,
	                    didOutput metadataObjects: [AVMetadataObject],
	                    from _: AVCaptureConnection)
	{
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
			0,
		])
	}
}
