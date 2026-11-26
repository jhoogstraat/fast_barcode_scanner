import AVFoundation
import Flutter
import UIKit

@MainActor
public final class FastBarcodeScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let factory: PreviewViewFactory
  private var camera: Camera?
  private var picker: ImagePicker?
  private var detectionsSink: FlutterEventSink?

  init(factory: PreviewViewFactory) {
    self.factory = factory
  }

  public nonisolated static func register(with registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      let commandChannel = FlutterMethodChannel(
        name: "com.jhoogstraat/fast_barcode_scanner",
        binaryMessenger: registrar.messenger()
      )
      let barcodeEventChannel = FlutterEventChannel(
        name: "com.jhoogstraat/fast_barcode_scanner/detections",
        binaryMessenger: registrar.messenger()
      )
      let instance = FastBarcodeScannerPlugin(factory: PreviewViewFactory())
      registrar.register(instance.factory, withId: "fast_barcode_scanner.preview")
      registrar.addMethodCallDelegate(instance, channel: commandChannel)
      barcodeEventChannel.setStreamHandler(instance)
    }
  }

  public nonisolated func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        var response: Any?
        switch call.method {
        case "init": response = try await initialize(args: call.arguments).serialized
        case "start": try await requireCamera().start()
        case "stop": await try requireCamera().stop()
        case "startDetector": try requireCamera().startScanner()
        case "stopDetector": try requireCamera().stopScanner()
        case "torch": response = try await requireCamera().toggleTorch()
        case "setZoom": response = try await setZoom(args: call.arguments)
        case "canSwitchCamera": response = Camera.canSwitchCamera()
        case "config": response = try await requireCamera().updateConfiguration(args: call.arguments).serialized
        case "scan": response = try await analyzeImage(args: call.arguments)
        case "dispose": await dispose()
        default: response = FlutterMethodNotImplemented
        }
        result(response)
      } catch {
        result(error.flutterError)
      }
    }
  }

  private func requireCamera() throws -> Camera {
    guard let camera = camera else { throw ScannerError.notInitialized }
    return camera
  }

  private func initialize(args: Any?) async throws -> CameraInformation {
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
        guard let previewLayer = self?.factory.preview?.videoPreviewLayer else { return nil }
        // Flip Vision bottom-left coordinates into AVFoundation top-left metadata space.
        let box = observation.boundingBox
        let flippedBox = CGRect(
          x: box.minX, y: 1.0 - box.maxY, width: box.width, height: box.height)
        let rect = previewLayer.layerRectConverted(fromMetadataOutputRect: flippedBox)
        let corners = [
          observation.topLeft,
          observation.topRight,
          observation.bottomRight,
          observation.bottomLeft,
        ].map {
          previewLayer.layerPointConverted(
            fromCaptureDevicePoint: CGPoint(x: $0.x, y: 1.0 - $0.y))
        }
        return (rect, corners)
      } resultHandler: { [weak self] barcodes in
        self?.detectionsSink?(barcodes)
      }
    }

    let newCamera = try await Camera(configuration: cameraConfiguration, scanner: scanner)
    do {
      let info = try await newCamera.configureSession(configuration: cameraConfiguration)
      try await newCamera.start()
      self.camera = newCamera
      self.factory.session = newCamera.session
      return info
    } catch {
      await newCamera.dispose()
      throw error
    }
  }

  private func dispose() async {
    factory.session = nil
    if let existingCamera = camera {
      camera = nil
      await existingCamera.dispose()
    }
  }

  private func setZoom(args: Any?) async throws -> Double {
    guard let zoomFactor = (args as? NSNumber)?.doubleValue else {
      throw ScannerError.invalidArguments(args)
    }
    return try await requireCamera().setZoom(zoomFactor)
  }

  private func analyzeImage(args: Any?) async throws -> Any? {
    let image: UIImage?
    if let container = args as? [Any] {
      guard
        let byteBuffer = container.first as? FlutterStandardTypedData,
        let decoded = UIImage(data: byteBuffer.data)
      else { throw ScannerError.loadingDataFailed }
      image = decoded
    } else {
      guard picker == nil else { return nil }
      let root =
        UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
        ?? UIApplication.shared.delegate?.window??.rootViewController
      guard let root = root else { return nil }

      let activePicker: ImagePicker =
        if #available(iOS 14, *) { PHImagePicker() } else { UIImagePicker() }
      self.picker = activePicker
      defer { self.picker = nil }

      image = await activePicker.show(over: root)
    }

    guard let uiImage = image else { return nil }
    return try await VisionBarcodeScanner.scanStillImage(uiImage)
  }

  public nonisolated func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    MainActor.assumeIsolated { detectionsSink = events }
    return nil
  }

  public nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
    MainActor.assumeIsolated { detectionsSink = nil }
    return nil
  }
}
