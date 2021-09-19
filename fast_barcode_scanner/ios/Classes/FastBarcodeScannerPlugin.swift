import Flutter
import AVFoundation

public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    let commandChannel: FlutterMethodChannel
    let barcodeEventChannel: FlutterEventChannel
    let factory: PreviewViewFactory

    var camera: Camera?
    var picker: ImagePicker?
    var detectionsSink: FlutterEventSink?

    init(commands: FlutterMethodChannel,
         events: FlutterEventChannel,
         factory: PreviewViewFactory
    ) {
		self.commandChannel = commands
        self.barcodeEventChannel = events
        self.factory = factory
	}

	public static func register(with registrar: FlutterPluginRegistrar) {
		let commandChannel = FlutterMethodChannel(name: "com.jhoogstraat/fast_barcode_scanner",
                                                  binaryMessenger: registrar.messenger())

        let barcodeEventChannel = FlutterEventChannel(name: "com.jhoogstraat/fast_barcode_scanner/detections",
                                                      binaryMessenger: registrar.messenger())

        let instance = FastBarcodeScannerPlugin(commands: commandChannel,
                                                events: barcodeEventChannel,
                                                factory: PreviewViewFactory())

        registrar.register(instance.factory, withId: "fast_barcode_scanner.preview")
		registrar.addMethodCallDelegate(instance, channel: commandChannel)
        barcodeEventChannel.setStreamHandler(instance)
	}

	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            var response: Any?

            switch call.method {
            case "init": response = try initialize(args: call.arguments).asDict
            case "start": try start()
            case "stop": try stop()
            case "startDetector": try startDetector()
            case "stopDetector": try stopDetector()
            case "torch": response = try toggleTorch()
            case "config": response = try updateConfiguration(call: call).asDict
            case "scan": analyzeImage(on: result); return
            case "dispose": dispose()
            default: response = FlutterMethodNotImplemented
            }

            result(response)
        } catch {
            print(error)
            result(error.flutterError)
        }
	}

    func initialize(args: Any?) throws -> PreviewConfiguration {
        guard camera == nil else {
            throw ScannerError.alreadyInitialized
        }

        guard let configuration = ScannerConfiguration(args) else {
            throw ScannerError.invalidArguments(args)
        }

        let scanner = AVFoundationBarcodeScanner { [unowned self] barcode in
            self.detectionsSink?(barcode)
        }

        let camera = try Camera(configuration: configuration, scanner: scanner)

        // AVCaptureVideoPreviewLayer shows the current camera's session
        factory.session = camera.session

        try camera.start()

        self.camera = camera

        return camera.previewConfiguration
    }

    func start() throws {
        guard let camera = camera else { throw ScannerError.notInitialized }
        try camera.start()
	}

    func stop() throws {
        guard let camera = camera else { throw ScannerError.notInitialized }
        camera.stop()
    }

    func dispose() {
        camera?.stop()
        camera = nil
    }

    func startDetector() throws {
        guard let camera = camera else { throw ScannerError.notInitialized }
        camera.startDetector()
    }

    func stopDetector() throws {
        guard let camera = camera else { throw ScannerError.notInitialized }
        camera.stopDetector()
    }

	func toggleTorch() throws -> Bool {
        guard let camera = camera else { throw ScannerError.notInitialized }
        return try camera.toggleTorch()
	}

    func updateConfiguration(call: FlutterMethodCall) throws -> PreviewConfiguration {
        guard let camera = camera else {
            throw ScannerError.notInitialized
        }

        guard let config = camera.configuration.copy(with: call.arguments) else {
            throw ScannerError.invalidArguments(call.arguments)
        }

        try camera.configureSession(configuration: config)

        return camera.previewConfiguration
    }

    func analyzeImage(on resultHandler: @escaping (Any?) -> Void) {
        guard picker == nil, let root = UIApplication.shared.delegate?.window??.rootViewController else {
            return resultHandler(nil)
        }

        let visionResultHandler: BarcodeScanner.ResultHandler = { [weak self] result in
            resultHandler(result)
            self?.picker = nil
        }

        let imageResultHandler: ImagePicker.ResultHandler = { image in
            guard let uiImage = image,
                  let cgImage = uiImage.cgImage
            else { return resultHandler(nil) }

            let scanner = VisionBarcodeScanner(resultHandler: visionResultHandler)

            scanner.process(cgImage)
        }

        if #available(iOS 14, *) {
            picker = PHImagePicker(resultHandler: imageResultHandler)
        } else {
            picker = UIImagePicker(resultHandler: imageResultHandler)
        }

        picker!.show(over: root)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        detectionsSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        detectionsSink = nil
        return nil
    }
}
