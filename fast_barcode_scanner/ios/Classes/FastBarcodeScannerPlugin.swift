import Flutter
import AVFoundation

public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin {
    let channel: FlutterMethodChannel
    let factory: PreviewViewFactory

    var camera: Camera?
    var picker: ImagePicker?

    init(channel: FlutterMethodChannel, factory: PreviewViewFactory) {
		self.channel = channel
        self.factory = factory
	}

	public static func register(with registrar: FlutterPluginRegistrar) {
		let channel = FlutterMethodChannel(name: "com.jhoogstraat/fast_barcode_scanner",
                                           binaryMessenger: registrar.messenger())

        let instance = FastBarcodeScannerPlugin(channel: channel,
                                                factory: PreviewViewFactory())

        registrar.register(instance.factory, withId: "fast_barcode_scanner.preview")
		registrar.addMethodCallDelegate(instance, channel: channel)
	}

	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            var response: Any?

            switch call.method {
            case "init": response = try initialize(args: call.arguments).asDict
            case "start": try start()
            case "stop": try stop()
            case "torch": response = try toggleTorch()
            case "config":  response = try updateConfiguration(call: call).asDict
            case "dispose": dispose()
            case "pick": analyzeImage(on: result); return
            default: response = FlutterMethodNotImplemented
            }

            result(response)
        } catch {
            print(error)
            result(error.flutterError)
        }
	}

    func initialize(args: Any?) throws -> PreviewConfiguration {
        guard let configuration = ScannerConfiguration(args) else {
            throw ScannerError.invalidArguments(args)
        }

        let scanner = AVFoundationBarcodeScanner { barcode in
            if let barcode = barcode {
                self.channel.invokeMethod("s", arguments: barcode)
            }
        }

        camera = try Camera(configuration: configuration, scanner: scanner)

        factory.session = camera!.session

        try camera!.start()

        return camera!.previewConfiguration
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

    func analyzeImage(on result: @escaping ([String]?) -> Void) {
        guard picker == nil, let root = UIApplication.shared.delegate?.window??.rootViewController else {
            return result(nil)
        }

        let visionResultHandler: BarcodeScanner.ResultHandler = { [weak self] barcode in
            result(barcode)
            self?.picker = nil
        }

        let imageResultHandler: ImagePicker.ResultHandler = { image in
            guard let uiImage = image,
                  let cgImage = uiImage.cgImage
            else { return result(nil) }

            let scanner = VisionBarcodeScanner(resultHandler: visionResultHandler)

            scanner.performVisionRequest(cgImage: cgImage, orientation: .init(uiImage.imageOrientation))
        }

        if #available(iOS 14, *) {
            picker = PHImagePicker(resultHandler: imageResultHandler)
        } else {
            picker = UIImagePicker(resultHandler: imageResultHandler)
        }

        picker!.show(over: root)
    }
}
