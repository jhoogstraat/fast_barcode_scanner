import Flutter
import AVFoundation

struct CameraConfiguration {
    
    init(position: AVCaptureDevice.Position, framerate: Framerate, resolution: Resolution, mode: DetectionMode, codes: [String]) {
        self.position = position
        self.framerate = framerate
        self.resolution = resolution
        self.detectionMode = mode
        self.codes = codes
    }
    
    init?(_ args: Any?) {
		guard
			let dict = args as? [String: Any],
            let position = cameraPositions[dict["pos"] as? String ?? ""],
			let resolution = Resolution(rawValue: dict["res"] as? String ?? ""),
			let framerate = Framerate(rawValue: dict["fps"] as? String ?? ""),
			let detectionMode = DetectionMode(rawValue: dict["mode"] as? String ?? ""),
			let codes = dict["types"] as? [String]
			else {
				return nil
		}
        
        self.init(position: position,
                  framerate: framerate,
                  resolution: resolution,
                  mode: detectionMode,
                  codes: codes
        )
	}

    let position: AVCaptureDevice.Position
	let framerate: Framerate
	let resolution: Resolution
	let detectionMode: DetectionMode
	let codes: [String]
    
    func updated(with args: Any?) -> CameraConfiguration? {
        guard let dict = args as? [String: Any] else { return nil }
        
        return CameraConfiguration.init(
            position: cameraPositions[dict["pos"] as? String ?? ""] ?? position,
            framerate: Framerate(rawValue: dict["fps"] as? String ?? "") ?? framerate,
            resolution: Resolution(rawValue: dict["res"] as? String ?? "") ?? resolution,
            mode: DetectionMode(rawValue: dict["mode"] as? String ?? "") ?? detectionMode,
            codes: dict["types"] as? [String] ?? codes
        )
    }
}

public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin {

	let textureRegistry: FlutterTextureRegistry
	let channel: FlutterMethodChannel

	var reader: BarcodeReader?

	init(channel: FlutterMethodChannel, textureRegistry: FlutterTextureRegistry) {
		self.textureRegistry = textureRegistry
		self.channel = channel
	}

	public static func register(with registrar: FlutterPluginRegistrar) {
		let channel = FlutterMethodChannel(name: "com.jhoogstraat/fast_barcode_scanner",
                                           binaryMessenger: registrar.messenger())
		let instance = FastBarcodeScannerPlugin(channel: channel, textureRegistry: registrar.textures())
		registrar.addMethodCallDelegate(instance, channel: channel)
	}

	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            switch call.method {
            case "start": start(call: call, result: result)
            case "stop": stop(result: result)
            case "pause": pause(result: result)
            case "resume": try resume(result: result)
            case "toggleTorch": toggleTorch(result: result)
            case "updateConfig": updateConfiguration(call: call, result: result)
            default: result(FlutterMethodNotImplemented)
            }
        } catch {
            print(error)
            result(FlutterError(code: "THROW", message: "\(error)", details: nil))
        }
	}

	func start(call: FlutterMethodCall, result: @escaping FlutterResult) {
		guard reader == nil else {
			let error = FlutterError(code: "ALREADY_RUNNING",
                                     message: "Start cannot be called when already running",
                                     details: nil)
			result(error)
			return
		}

		guard let args = CameraConfiguration(call.arguments) else {
			let error = FlutterError(code: "INVALID_ARGUMENT",
                                     message: "Missing a required argument",
                                     details: "Expected resolution, framerate, mode and types")
			result(error)
			return
		}

		do {
			reader = try BarcodeReader(textureRegistry: textureRegistry, configuration: args) { [unowned self] code in
				self.channel.invokeMethod("read", arguments: code)
			}

			try reader!.start(fromPause: false)

			result([
				"surfaceWidth": reader!.previewSize.height,
				"surfaceHeight": reader!.previewSize.width,
				"surfaceOrientation": 0,
				"textureId": reader!.textureId!
			])

		} catch ReaderError.noInputDeviceForConfig {
			result(FlutterError(code: "AV_NO_INPUT_DEVICE",
                                message: "No input device found",
                                details: "Are you using a simulator?"))
		} catch ReaderError.cameraNotSuitable(let res, let fps) {
			result(FlutterError(code: "CAMERA_NOT_SUITABLE",
                                message: """
                                    The camera does not support the requested resolution (\(res)) \
                                    and framerate (\(fps)) combination
                                    """,
                                details: "try to lower your settings"))
        } catch ReaderError.unauthorized {
                result(FlutterError(code: "UNAUTHORIZED",
                                    message: "The application is not authorized to use the camera device",
                                    details: nil))
        } catch {
            result(FlutterError(code: "UNEXPECTED_ERROR",
                                                    message: "Unknown error occured.",
                                                    details: nil))
        }
	}

	func pause(result: @escaping FlutterResult) {
		reader?.pauseIfRequired()
		result(nil)
	}

	func resume(result: @escaping FlutterResult) throws {
		try reader?.resume()
		result(nil)
	}

	func toggleTorch(result: @escaping FlutterResult) {
		result(reader?.toggleTorch())
	}

    func updateConfiguration(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let reader = reader else {
            let error = FlutterError(code: "NOT_RUNNING",
                                     message: "Camera cannot be changed when not running",
                                     details: nil)
            result(error)
            return
        }

        guard let config = reader.configuration.updated(with: call.arguments) else {
            let error = FlutterError(code: "INVALID_ARGUMENT",
                                    message: "Missing a required argument",
                                    details: "Expected resolution, framerate, mode and types")
            result(error)
            return
        }

        do {
            try reader.setCaptureDevice(config: config)
        } catch ReaderError.noInputDeviceForConfig {
            result(FlutterError(code: "AV_NO_INPUT_DEVICE",
                                message: "No input device found",
                                details: "Are you using a simulator?"))
        } catch ReaderError.cameraNotSuitable(let res, let fps) {
            result(FlutterError(code: "CAMERA_NOT_SUITABLE",
                                message: """
                                    The camera does not support the requested resolution (\(res)) \
                                    and framerate (\(fps)) combination
                                    """,
                                details: "try to lower your settings"))
        } catch ReaderError.unauthorized {
                result(FlutterError(code: "UNAUTHORIZED",
                                    message: "The application is not authorized to use the camera device",
                                    details: nil))
        } catch {
            result(FlutterError(code: "UNEXPECTED_ERROR",
                                                    message: "Unknown error occured.",
                                                    details: nil))
        }
    }

	func stop(result: @escaping FlutterResult) {
		reader?.stop(pause: false)
		reader = nil
		result(nil)
	}
}
