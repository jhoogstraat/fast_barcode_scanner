import AVFoundation

typealias AVMetadataObjectBoundsConverter = (AVMetadataObject) -> AVMetadataObject?

final class AVFoundationBarcodeScanner: NSObject, BarcodeScanner,
  AVCaptureMetadataOutputObjectsDelegate
{
  private let resultHandler: ResultHandler
  private let objectBoundsConverter: AVMetadataObjectBoundsConverter
  var onDetection: (() -> Void)?

  private let output = AVCaptureMetadataOutput()
  private let metadataQueue = DispatchQueue(
    label: "com.jhoogstraat.fast_barcode_scanner.avfoundation",
    qos: .userInitiated
  )
  private weak var _session: AVCaptureSession?
  private var _symbologies = [String]()
  private var isActive = false

  init(
    objectBoundsConverter: @escaping AVMetadataObjectBoundsConverter,
    resultHandler: @escaping ResultHandler
  ) {
    self.objectBoundsConverter = objectBoundsConverter
    self.resultHandler = resultHandler
    super.init()
  }

  var symbologies: [String] {
    get { _symbologies }
    set {
      _symbologies = newValue
      let requested = avMetadataObjectTypes(for: newValue)
      let available = Set(output.availableMetadataObjectTypes)
      output.metadataObjectTypes = requested.filter { available.contains($0) }
    }
  }

  var session: AVCaptureSession? {
    get { _session }
    set {
      _session = newValue
      if let session = newValue, session.canAddOutput(output), !session.outputs.contains(output) {
        session.addOutput(output)
      }
    }
  }

  func start() {
    isActive = true
    output.setMetadataObjectsDelegate(self, queue: metadataQueue)
  }

  func stop() {
    isActive = false
    output.setMetadataObjectsDelegate(nil, queue: nil)
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard isActive, !metadataObjects.isEmpty else { return }

    let readableCodes = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
    guard !readableCodes.isEmpty else { return }

    let currentSymbologies = _symbologies

    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.isActive else { return }

      var scannedCodes: [[Any?]] = []

      for readableCode in readableCodes {
        guard
          var type = flutterType(for: readableCode.type),
          var value = readableCode.stringValue
        else {
          continue
        }

        // Apple reports UPC-A as EAN-13 with a leading "0".
        if readableCode.type == .ean13 {
          if value.hasPrefix("0") && currentSymbologies.contains("upcA") {
            type = "upcA"
            value.removeFirst()
          } else if !currentSymbologies.contains("ean13") {
            continue
          }
        }

        let transformed =
          self.objectBoundsConverter(readableCode) as? AVMetadataMachineReadableCodeObject
        let bounds = transformed?.bounds ?? readableCode.bounds
        let corners = (transformed?.corners ?? readableCode.corners).map {
          [Double($0.x), Double($0.y)]
        }

        scannedCodes.append([
          type,
          value,
          [Double(bounds.minX), Double(bounds.minY), Double(bounds.maxX), Double(bounds.maxY)],
          corners,
        ])
      }

      guard !scannedCodes.isEmpty else { return }

      self.onDetection?()
      self.resultHandler(scannedCodes)
    }
  }
}
