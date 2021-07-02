//
//  BarcodeReader.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 16.07.20.
//

import AVFoundation
import Flutter

class BarcodeScanner: NSObject {
    private let textureRegistry: FlutterTextureRegistry
	private var textureId: Int64?
	private var pixelBuffer: CVPixelBuffer?

	private let dataOutput: AVCaptureVideoDataOutput
    private var metadataOutput: AVCaptureMetadataOutput
    private let codeCallback: ([String]) -> Void

    private(set) var configuration: CameraConfiguration
    private var captureDevice: AVCaptureDevice?
    private var captureSession: AVCaptureSession
    private var torchActiveOnStop = false
    private  var previewSize: CMVideoDimensions?
    
    public func previewConfiguration() throws -> PreviewConfiguration {
        guard let preview = previewSize, let id = textureId else { throw ScannerError.notInitialized }
        return PreviewConfiguration(width: preview.width, height: preview.height, targetRotation: 0, textureId: id)
    }
    
	init(textureRegistry: FlutterTextureRegistry,
      configuration: CameraConfiguration,
      codeCallback: @escaping ([String]) -> Void) throws {
		self.textureRegistry = textureRegistry
		self.codeCallback = codeCallback
		self.captureSession = AVCaptureSession()
		self.dataOutput = AVCaptureVideoDataOutput()
		self.metadataOutput = AVCaptureMetadataOutput()
        self.configuration = configuration
		super.init()
        
        try set(configuration: configuration)

        captureSession.addOutput(dataOutput)
        captureSession.addOutput(metadataOutput)

        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        dataOutput.connection(with: .video)?.videoOrientation = .portrait
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
        metadataOutput.metadataObjectTypes = configuration.codes.compactMap { avMetadataObjectTypes[$0] }
    }
    
    private func captureDevice(with configuration: CameraConfiguration) throws -> AVCaptureDevice {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: configuration.position) else {
            throw ScannerError.noInputDeviceForConfig(configuration)
        }
        
        return device
    }
    
    func set(configuration: CameraConfiguration) throws {
        let device = try captureDevice(with: configuration)
        
        captureSession.beginConfiguration()
        captureSession.inputs.forEach(captureSession.removeInput)

        do {
            let input = try AVCaptureDeviceInput(device: device)
            captureSession.addInput(input)
            captureDevice = device
        } catch let error as AVError {
            if error.code == AVError.applicationIsNotAuthorizedToUseDevice {
                throw ScannerError.unauthorized
            }
            throw error
        }
        
        dataOutput.connection(with: .video)?.videoOrientation = .portrait
        dataOutput.connection(with: .video)?.isVideoMirrored = configuration.position == .front
        captureSession.commitConfiguration()
        
        guard let optimalFormat = device.formats.first(where: {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let mediaSubType = CMFormatDescriptionGetMediaSubType($0.formatDescription).toString()

            return $0.videoSupportedFrameRateRanges.first!.maxFrameRate >= configuration.framerate.doubleValue
                && dimensions.height >= configuration.resolution.height
                && dimensions.width >= configuration.resolution.width
                && mediaSubType == "420f" // maybe 420v is also ok? Who knows...
        }) else {
            throw ScannerError.cameraNotSuitable(configuration.resolution, configuration.framerate)
        }
        
        do {
            try device.lockForConfiguration()
            device.activeFormat = optimalFormat
            device.activeVideoMinFrameDuration =
                optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
            device.activeVideoMaxFrameDuration =
                optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
            device.unlockForConfiguration()
        } catch {
            throw ScannerError.configurationLockError(error)
        }

        previewSize = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)

        self.configuration = configuration
    }

	func start(fromPause: Bool) throws {
        guard let device = captureDevice else { throw ScannerError.notInitialized }

		captureSession.startRunning()

		if !fromPause {
			self.textureId = textureRegistry.register(self)
		}

		if torchActiveOnStop {
            do {
                try device.lockForConfiguration()
                device.torchMode = .on
                device.unlockForConfiguration()
                torchActiveOnStop = false
            } catch {
                throw ScannerError.configurationLockError(error)
            }
		}
	}

	func stop(pause: Bool) throws {
        guard let device = captureDevice, let textureId = textureId else {
            throw ScannerError.notInitialized
        }

		torchActiveOnStop = device.isTorchActive
		captureSession.stopRunning()
        
		if !pause {
			pixelBuffer = nil
			textureRegistry.unregisterTexture(textureId)
            self.textureId = nil
		}
	}

	func toggleTorch() throws -> Bool {
        guard let device = captureDevice else { throw ScannerError.notInitialized }
        guard device.isTorchAvailable else { return false }

        try device.lockForConfiguration()
        device.torchMode = device.isTorchActive ? .off : .on
        device.unlockForConfiguration()

        return device.torchMode == .on
	}

	func pauseIfRequired() throws {
        switch configuration.detectionMode {
        case .continuous: return
        case .pauseDetection:
			captureSession.removeOutput(metadataOutput)
        case .pauseVideo:
			try stop(pause: true)
		}
	}

	func resume() throws {
        switch configuration.detectionMode {
        case .continuous: return
        case .pauseDetection:
            guard !captureSession.outputs.contains(metadataOutput) else { return }

            let types = metadataOutput.metadataObjectTypes
            metadataOutput = AVCaptureMetadataOutput()
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
            metadataOutput.metadataObjectTypes = types
			captureSession.addOutput(metadataOutput)
        case .pauseVideo:
			let _ = try start(fromPause: true)
		}
	}
}

extension BarcodeScanner: FlutterTexture {
	func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
		pixelBuffer == nil ? nil : .passRetained(pixelBuffer!)
	}
}

extension BarcodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
	// runs on dispatch queue
	func captureOutput(_ output: AVCaptureOutput,
                    didOutput sampleBuffer: CMSampleBuffer,
                    from connection: AVCaptureConnection) {
		pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
		textureRegistry.textureFrameAvailable(textureId!)
	}
}

extension BarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
	// runs on dispatch queue
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
		guard
			let metadata = metadataObjects.first,
			let readableCode = metadata as? AVMetadataMachineReadableCodeObject,
            let type = flutterMetadataObjectTypes[readableCode.type],
            let value = readableCode.stringValue
			else { return }

		try? pauseIfRequired()

		codeCallback([type, value])
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
