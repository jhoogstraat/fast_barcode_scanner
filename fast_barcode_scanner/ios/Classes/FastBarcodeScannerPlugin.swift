import Flutter
import AVFoundation

public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin {
    let channel: FlutterMethodChannel
    let factory: PreviewViewFactory

    var liveScanner: BarcodeScanner?
    var stillScanner: StillBarcodeScanner?

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
            case "init": response = try initialize(configArgs: call.arguments).asDict
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

    func initialize(configArgs: Any?) throws -> PreviewConfiguration {
        guard let configuration = ScannerConfiguration(configArgs) else {
            throw ScannerError.invalidArguments(configArgs)
        }

        liveScanner = try BarcodeScanner(configuration: configuration) { [unowned self] code in
            self.channel.invokeMethod("r", arguments: code)
        }

        factory.session = liveScanner!.captureSession

        try liveScanner!.start()

        return liveScanner!.previewConfiguration
    }

    func start() throws {
        guard let scanner = liveScanner else { throw ScannerError.notInitialized }
        try scanner.start()
	}

    func stop() throws {
        guard let scanner = liveScanner else { throw ScannerError.notInitialized }
        scanner.stop()
    }

    func dispose() {
        liveScanner?.stop()
        liveScanner = nil
    }

	func toggleTorch() throws -> Bool {
        guard let scanner = liveScanner else { throw ScannerError.notInitialized }
        return try scanner.toggleTorch()
	}

    func updateConfiguration(call: FlutterMethodCall) throws -> PreviewConfiguration {
        guard let scanner = liveScanner else { throw ScannerError.notInitialized }

        guard let config = scanner.configuration.copy(with: call.arguments) else {
            throw ScannerError.invalidArguments(call.arguments)
        }

        return try scanner.apply(configuration: config)
    }

    func analyzeImage(on result: @escaping ([String]) -> Void) {
        stillScanner = nil

        guard stillScanner == nil, let root = UIApplication.shared.delegate?.window??.rootViewController else {
            result([])
            return
        }

        let scanner = StillBarcodeScanner(symbologies: [.EAN13, .QR, .Code128]) { [weak self] barcode in
            if let barcode = barcode,
               let symbol = flutterVNSymbols[barcode.symbology],
               let value = barcode.payloadStringValue {
                result([symbol, value])
            } else {
                result([])
            }

            self?.stillScanner = nil
        }

        scanner.show(over: root)

        stillScanner = scanner
    }
}
