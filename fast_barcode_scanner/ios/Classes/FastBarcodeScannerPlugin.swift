import Flutter
import AVFoundation

public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin {
	let textureRegistry: FlutterTextureRegistry
	let channel: FlutterMethodChannel

	var reader: BarcodeScanner?

	init(channel: FlutterMethodChannel, textureRegistry: FlutterTextureRegistry) {
		self.textureRegistry = textureRegistry
		self.channel = channel
	}

	public static func register(with registrar: FlutterPluginRegistrar) {
		let channel = FlutterMethodChannel(name: "com.jhoogstraat/fast_barcode_scanner",
                                           binaryMessenger: registrar.messenger())
		let instance = FastBarcodeScannerPlugin(channel: channel,
                                                textureRegistry: registrar.textures())
        
		registrar.addMethodCallDelegate(instance, channel: channel)
	}

	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            var response: Any?
            
            switch call.method {
            case "start": response = try start(configArgs: call.arguments).dict
            case "stop": try stop()
            case "pause": try pause()
            case "resume": try resume()
            case "toggleTorch": response = try toggleTorch()
            case "config":  try updateConfiguration(call: call)
            default: result(FlutterMethodNotImplemented)
            }
            
            result(response)
        } catch {
            print(error)
            result(error.flutterError)
        }
	}

    func start(configArgs: Any?) throws -> PreviewConfiguration {
        if let reader = reader {
            try reader.stop(pause: false)
        }

        guard let configuration = CameraConfiguration(configArgs) else {
            throw ScannerError.invalidArguments(configArgs)
        }
        
        reader = try BarcodeScanner(textureRegistry: textureRegistry, configuration: configuration) { [unowned self] code in
            self.channel.invokeMethod("r", arguments: code)
        }

        return try reader!.start(fromPause: false)
	}

	func pause() throws {
        guard let reader = reader else { throw ScannerError.notRunning }
        return try reader.pauseIfRequired()
	}

	func resume() throws {
        guard let reader = reader else { throw ScannerError.notRunning }
        return try reader.resume()
	}
    
    func stop() throws {
        guard let reader = reader else { throw ScannerError.notRunning }
        try reader.stop(pause: false)
        self.reader = nil
    }

	func toggleTorch() throws -> Bool {
        guard let reader = reader else { throw ScannerError.notRunning }
        return try reader.toggleTorch()
	}

    func updateConfiguration(call: FlutterMethodCall) throws {
        guard let reader = reader else {
            throw ScannerError.notRunning
        }

        guard let config = reader.configuration.copy(with: call.arguments) else {
            throw ScannerError.invalidArguments(call.arguments)
        }

        try reader.set(configuration: config)
    }
}
