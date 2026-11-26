import AVFoundation
import UIKit
import Vision

typealias VisionBarcodeBoundsConverter = (VNBarcodeObservation) -> (CGRect, [CGPoint])?

final class VisionBarcodeScanner: NSObject, BarcodeScanner,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  private let resultHandler: ResultHandler
  private let boundsConverter: VisionBarcodeBoundsConverter?
  private let confidence: Float
  var onDetection: (() -> Void)?

  private let output = AVCaptureVideoDataOutput()
  private let outputQueue = DispatchQueue(
    label: "com.jhoogstraat.fast_barcode_scanner.vision",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem
  )
  private let stateLock = NSLock()
  private let visionSequenceHandler = VNSequenceRequestHandler()
  private let barcodeRequest = VisionBarcodeScanner.makeBarcodeRequest()

  private var _symbologies = [String]()
  private var acceptsUpcA = false
  private var acceptsEan13 = false
  private var _isActive = false
  private weak var _session: AVCaptureSession?

  private var isActive: Bool {
    get { stateLock.withLock { _isActive } }
    set { stateLock.withLock { _isActive = newValue } }
  }

  private static func makeBarcodeRequest() -> VNDetectBarcodesRequest {
    let request = VNDetectBarcodesRequest()
    if #available(iOS 17, *) {
      request.revision = VNDetectBarcodesRequestRevision4
    } else if #available(iOS 16, *) {
      request.revision = VNDetectBarcodesRequestRevision3
    } else if #available(iOS 15, *) {
      request.revision = VNDetectBarcodesRequestRevision2
    }
    return request
  }

  var symbologies: [String] {
    get { stateLock.withLock { _symbologies } }
    set {
      stateLock.withLock {
        _symbologies = newValue
        acceptsUpcA = newValue.contains("upcA")
        acceptsEan13 = newValue.contains("ean13")
      }
      let mapped = vnBarcodeSymbologies(for: newValue)
      outputQueue.async { [weak self] in
        self?.barcodeRequest.symbologies = mapped
      }
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

  init(
    confidence: Float,
    boundsConverter: VisionBarcodeBoundsConverter? = nil,
    resultHandler: @escaping ResultHandler
  ) {
    self.confidence = confidence
    self.boundsConverter = boundsConverter
    self.resultHandler = resultHandler
    super.init()
    output.alwaysDiscardsLateVideoFrames = true
  }

  func start() {
    isActive = true
    output.setSampleBufferDelegate(self, queue: outputQueue)
  }

  func stop() {
    isActive = false
    output.setSampleBufferDelegate(nil, queue: nil)
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let (active, upcA, ean13) = stateLock.withLock { (_isActive, acceptsUpcA, acceptsEan13) }
    guard active, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    do {
      try visionSequenceHandler.perform([barcodeRequest], on: pixelBuffer)
      guard let observations = barcodeRequest.results, !observations.isEmpty else { return }

      var seen: Set<String>? = observations.count > 1 ? Set<String>() : nil
      var matched: [(VNBarcodeObservation, String, String)] = []

      for observation in observations {
        guard
          observation.confidence >= confidence,
          let rawPayload = observation.payloadStringValue,
          let rawType = flutterType(for: observation.symbology),
          let (type, value) = normalizeBarcodeTypeAndValue(
            type: rawType,
            value: rawPayload,
            isEan13: observation.symbology == .ean13,
            acceptsUpcA: upcA,
            acceptsEan13: ean13
          )
        else { continue }

        if seen != nil && !(seen!.insert("\(type)|\(value)").inserted) {
          continue
        }
        matched.append((observation, type, value))
      }

      guard !matched.isEmpty else { return }

      DispatchQueue.main.async { [weak self] in
        guard let self = self, self.isActive else { return }
        let scannedCodes = matched.map { observation, type, value -> [Any] in
          let converted = self.boundsConverter?(observation)
          return serializeBarcode(
            type: type,
            value: value,
            bounds: converted?.0 ?? observation.boundingBox,
            corners: converted?.1 ?? [
              observation.topLeft,
              observation.topRight,
              observation.bottomRight,
              observation.bottomLeft,
            ]
          )
        }
        self.onDetection?()
        self.resultHandler(scannedCodes)
      }
    } catch {
      print("fast_barcode_scanner: Vision frame error: \(error)")
    }
  }

  // MARK: Still image processing

  static func scanStillImage(_ uiImage: UIImage) async throws -> [[Any]] {
    guard let cgImage = uiImage.cgImage else {
      throw ScannerError.loadingDataFailed
    }

    let orientation = cgImagePropertyOrientation(from: uiImage.imageOrientation)
    // Vision returns coordinates in the oriented (upright) pixel space.
    let width = Double(uiImage.size.width * uiImage.scale)
    let height = Double(uiImage.size.height * uiImage.scale)

    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let request = makeBarcodeRequest()
        let handler = VNImageRequestHandler(
          cgImage: cgImage, orientation: orientation, options: [:])

        do {
          try handler.perform([request])
          let observations = request.results ?? []
          var seen = Set<String>()
          var results: [[Any]] = []

          for observation in observations {
            guard
              let payload = observation.payloadStringValue,
              let type = flutterType(for: observation.symbology),
              seen.insert("\(type)|\(payload)").inserted
            else { continue }

            let box = observation.boundingBox
            let rect = CGRect(
              x: Double(box.minX) * width,
              y: (1.0 - Double(box.maxY)) * height,
              width: Double(box.width) * width,
              height: Double(box.height) * height
            )
            let corners = [
              observation.topLeft,
              observation.topRight,
              observation.bottomRight,
              observation.bottomLeft,
            ].map { CGPoint(x: Double($0.x) * width, y: (1.0 - Double($0.y)) * height) }

            results.append(serializeBarcode(type: type, value: payload, bounds: rect, corners: corners))
          }

          continuation.resume(returning: results)
        } catch {
          continuation.resume(throwing: ScannerError.analysisFailed(error))
        }
      }
    }
  }

  private static func cgImagePropertyOrientation(
    from uiOrientation: UIImage.Orientation
  ) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
