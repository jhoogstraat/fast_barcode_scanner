import AVFoundation
import Flutter
import UIKit

public final class FastBarcodeScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let commandChannel: FlutterMethodChannel
  private let barcodeEventChannel: FlutterEventChannel
  private let factory: PreviewViewFactory

  private var camera: Camera?
  private var picker: ImagePicker?
  private var detectionsSink: FlutterEventSink?

  init(
    commands: FlutterMethodChannel,
    events: FlutterEventChannel,
    factory: PreviewViewFactory
  ) {
    self.commandChannel = commands
    self.barcodeEventChannel = events
    self.factory = factory
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let commandChannel = FlutterMethodChannel(
      name: "com.jhoogstraat/fast_barcode_scanner",
      binaryMessenger: registrar.messenger()
    )

    let barcodeEventChannel = FlutterEventChannel(
      name: "com.jhoogstraat/fast_barcode_scanner/detections",
      binaryMessenger: registrar.messenger()
    )

    let instance = FastBarcodeScannerPlugin(
      commands: commandChannel,
      events: barcodeEventChannel,
      factory: PreviewViewFactory()
    )

    registrar.register(instance.factory, withId: "fast_barcode_scanner.preview")
    registrar.addMethodCallDelegate(instance, channel: commandChannel)
    barcodeEventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task {
      do {
        var response: Any?

        switch call.method {
        case "init":
          response = try await initialize(args: call.arguments).serialized
        case "start":
          try await start()
        case "stop":
          try await stop()
        case "startDetector":
          try startDetector()
        case "stopDetector":
          try stopDetector()
        case "torch":
          response = try toggleTorch()
        case "setZoom":
          response = try setZoom(args: call.arguments)
        case "canSwitchCamera":
          response = Camera.canSwitchCamera()
        case "config":
          response = try await updateConfiguration(call: call).serialized
        case "scan":
          response = try await analyzeImage(args: call.arguments)
        case "dispose":
          await dispose()
        default:
          response = FlutterMethodNotImplemented
        }

        await MainActor.run {
          result(response)
        }
      } catch {
        await MainActor.run {
          result(error.flutterError)
        }
      }
    }
  }

  private func initialize(args: Any?) async throws -> CameraInformation {
    // Gracefully clean up any previous camera (for example, after a Flutter Hot Restart).
    if camera != nil {
      await dispose()
    }

    guard let cameraConfiguration = CameraConfiguration(args) else {
      throw ScannerError.invalidArguments(args)
    }

    let scanner: BarcodeScanner
    switch cameraConfiguration.apiOptions {
    case .avFoundation:
      scanner = AVFoundationBarcodeScanner { [weak self] metadata in
        self?.factory.preview?.videoPreviewLayer.transformedMetadataObject(for: metadata)
      } resultHandler: { [weak self] barcodes in
        self?.detectionsSink?(barcodes)
      }
    case .vision(let confidence):
      scanner = VisionBarcodeScanner(confidence: confidence) { [weak self] observation in
        guard let previewLayer = self?.factory.preview?.videoPreviewLayer else {
          return nil
        }
        let rect = previewLayer.layerRectConverted(
          fromMetadataOutputRect: observation.boundingBox
        )
        let corners = [
          observation.topLeft,
          observation.topRight,
          observation.bottomRight,
          observation.bottomLeft,
        ].map { point in
          // Vision uses bottom-left origin; AVFoundation metadata rect uses top-left origin.
          previewLayer.layerPointConverted(
            fromCaptureDevicePoint: CGPoint(x: point.x, y: 1.0 - point.y)
          )
        }
        return (rect, corners)
      } resultHandler: { [weak self] barcodes in
        self?.detectionsSink?(barcodes)
      }
    }

    let newCamera = try await Camera(configuration: cameraConfiguration, scanner: scanner)
    self.camera = newCamera
    factory.session = newCamera.session

    try await newCamera.start()

    return newCamera.cameraInformation
  }

  private func start() async throws {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }
    try await camera.start()
  }

  private func stop() async throws {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }
    await camera.stop()
  }

  private func dispose() async {
    factory.session = nil
    if let existingCamera = camera {
      camera = nil
      await existingCamera.dispose()
    }
  }

  private func startDetector() throws {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }
    camera.startScanner()
  }

  private func stopDetector() throws {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }
    camera.stopScanner()
  }

  private func toggleTorch() throws -> Bool {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }
    return try camera.toggleTorch()
  }

  private func setZoom(args: Any?) throws -> Double {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }
    guard let zoomFactor = (args as? NSNumber)?.doubleValue else {
      throw ScannerError.invalidArguments(args)
    }
    return try camera.setZoom(zoomFactor)
  }

  private func updateConfiguration(call: FlutterMethodCall) async throws -> CameraInformation {
    guard let camera = camera else {
      throw ScannerError.notInitialized
    }

    guard let config = camera.targetConfiguration.copy(with: call.arguments) else {
      throw ScannerError.invalidArguments(call.arguments)
    }

    try await camera.configureSession(configuration: config)
    return camera.cameraInformation
  }

  private func analyzeImage(args: Any?) async throws -> Any? {
    let image: UIImage?

    if let container = args as? [Any] {
      guard let byteBuffer = container.first as? FlutterStandardTypedData else {
        throw ScannerError.loadingDataFailed
      }
      guard let decoded = UIImage(data: byteBuffer.data) else {
        throw ScannerError.loadingDataFailed
      }
      image = decoded
    } else {
      let rootViewController: UIViewController? = await MainActor.run {
        UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap(\.windows)
          .first(where: \.isKeyWindow)?
          .rootViewController
          ?? UIApplication.shared.delegate?.window??.rootViewController
      }

      guard let root = rootViewController else {
        return nil
      }

      let activePicker: ImagePicker
      if #available(iOS 14, *) {
        activePicker = await PHImagePicker()
      } else {
        activePicker = await UIImagePicker()
      }

      self.picker = activePicker
      defer { self.picker = nil }

      image = await activePicker.show(over: root)
      // User cancelled the photo picker.
      guard image != nil else {
        return nil
      }
    }

    guard let uiImage = image else {
      return nil
    }

    return try await VisionBarcodeScanner.scanStillImage(uiImage)
  }

  // MARK: FlutterStreamHandler

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    detectionsSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    detectionsSink = nil
    return nil
  }
}
