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
  private let stateLock = NSLock()
  private weak var _session: AVCaptureSession?
  private var _symbologies = [String]()
  private var acceptsUpcA = false
  private var acceptsEan13 = false
  private var _isActive = false

  private var isActive: Bool {
    get { stateLock.withLock { _isActive } }
    set { stateLock.withLock { _isActive = newValue } }
  }

  init(
    objectBoundsConverter: @escaping AVMetadataObjectBoundsConverter,
    resultHandler: @escaping ResultHandler
  ) {
    self.objectBoundsConverter = objectBoundsConverter
    self.resultHandler = resultHandler
    super.init()
  }

  var symbologies: [String] {
    get { stateLock.withLock { _symbologies } }
    set {
      stateLock.withLock {
        _symbologies = newValue
        acceptsUpcA = newValue.contains("upcA")
        acceptsEan13 = newValue.contains("ean13")
      }
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
    let (active, upcA, ean13) = stateLock.withLock { (_isActive, acceptsUpcA, acceptsEan13) }
    guard active, !metadataObjects.isEmpty else { return }

    // Filter and normalize on metadataQueue before hopping to main.
    var matched: [(AVMetadataMachineReadableCodeObject, String, String)] = []
    for obj in metadataObjects {
      guard
        let code = obj as? AVMetadataMachineReadableCodeObject,
        let rawType = flutterType(for: code.type),
        let rawValue = code.stringValue,
        let (type, value) = normalizeBarcodeTypeAndValue(
          type: rawType,
          value: rawValue,
          isEan13: code.type == .ean13,
          acceptsUpcA: upcA,
          acceptsEan13: ean13
        )
      else { continue }
      matched.append((code, type, value))
    }

    guard !matched.isEmpty else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.isActive else { return }
      let scannedCodes = matched.map { code, type, value -> [Any] in
        let transformed =
          self.objectBoundsConverter(code) as? AVMetadataMachineReadableCodeObject
        return serializeBarcode(
          type: type,
          value: value,
          bounds: transformed?.bounds ?? code.bounds,
          corners: transformed?.corners ?? code.corners
        )
      }
      self.onDetection?()
      self.resultHandler(scannedCodes)
    }
  }
}
