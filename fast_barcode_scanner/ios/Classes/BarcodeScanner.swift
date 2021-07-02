//
//  BarcodeReader.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 16.07.20.
//

import AVFoundation
import Flutter

class BarcodeScanner: NSObject {
    private let registry: FlutterTextureRegistry
    lazy private var textureId: Int64 = { registry.register(self) }()
    private let codeCallback: ([String]) -> Void

    private var captureDevice: AVCaptureDevice!
    private let captureSession: AVCaptureSession
    private let dataOutput: AVCaptureVideoDataOutput
    private var metadataOutput: AVCaptureMetadataOutput
    private var pixelBuffer: CVPixelBuffer?
    
    private(set) var configuration: CameraConfiguration
    private(set) var preview: PreviewConfiguration!
    private var torchState = false
    
	init(textureRegistry: FlutterTextureRegistry,
      configuration: CameraConfiguration,
      codeCallback: @escaping ([String]) -> Void) throws {
        self.registry = textureRegistry
		self.codeCallback = codeCallback
		self.captureSession = AVCaptureSession()
		self.dataOutput = AVCaptureVideoDataOutput()
		self.metadataOutput = AVCaptureMetadataOutput()
        self.configuration = configuration
        super.init()
        
        preview = try apply(configuration: configuration)

        captureSession.addOutput(dataOutput)
        captureSession.addOutput(metadataOutput)

        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        dataOutput.connection(with: .video)?.videoOrientation = .portrait
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
        metadataOutput.metadataObjectTypes = try configuration.codes.map {
            guard let type = avMetadataObjectTypes[$0] else {
                throw ScannerError.invalidCodeType($0)
            }
            return type
        }
    }
    
    func apply(configuration: CameraConfiguration) throws -> PreviewConfiguration {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: configuration.position) else {
            throw ScannerError.noInputDeviceForConfig(configuration)
        }
        
        captureSession.beginConfiguration()
        captureSession.inputs.forEach(captureSession.removeInput)

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
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
        
        guard let optimalFormat = captureDevice.formats.first(where: {
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
            try captureDevice.lockForConfiguration()
            captureDevice.activeFormat = optimalFormat
            captureDevice.activeVideoMinFrameDuration =
                optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
            captureDevice.activeVideoMaxFrameDuration =
                optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
            captureDevice.unlockForConfiguration()
        } catch {
            throw ScannerError.configurationError(error)
        }

        let previewSize = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        
        self.configuration = configuration
        
        preview = PreviewConfiguration(width: previewSize.width,
                             height: previewSize.height,
                             targetRotation: 0,
                             textureId: textureId)
        return preview
    }

	func start() throws {
        guard !captureSession.isRunning else {
            throw ScannerError.alreadyRunning
        }
        
        switch configuration.detectionMode {
        case .pauseDetection:
            guard !captureSession.outputs.contains(metadataOutput) else { break }
            let _metadataOutput = AVCaptureMetadataOutput()
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
            metadataOutput.metadataObjectTypes = metadataOutput.metadataObjectTypes
            metadataOutput = _metadataOutput
            captureSession.addOutput(metadataOutput)
        case .continuous: break
        case .pauseVideo: break
        }
        
		captureSession.startRunning()

		if torchState {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = .on
                captureDevice.unlockForConfiguration()
            } catch {
                throw ScannerError.configurationError(error)
            }
		}
	}
    
	func stop() {
		torchState = captureDevice.isTorchActive
		captureSession.stopRunning()
	}

	func toggleTorch() throws -> Bool {
        guard captureDevice.isTorchAvailable else { return false }

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = captureDevice.isTorchActive ? .off : .on
        captureDevice.unlockForConfiguration()
        
        return captureDevice.torchMode == .on
	}
}

extension BarcodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
	// runs on dispatch queue
	func captureOutput(_ output: AVCaptureOutput,
                    didOutput sampleBuffer: CMSampleBuffer,
                    from connection: AVCaptureConnection) {
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
		registry.textureFrameAvailable(textureId)
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

        switch configuration.detectionMode {
        case .pauseDetection:
            captureSession.removeOutput(metadataOutput)
        case .pauseVideo:
            stop()
        case .continuous: break
        }

		codeCallback([type, value])
	}
}

extension BarcodeScanner: FlutterTexture {
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return pixelBuffer == nil ? nil : .passRetained(pixelBuffer!)
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
