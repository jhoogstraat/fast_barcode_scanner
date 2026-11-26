import AVFoundation
import Flutter
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

  private let visionSequenceHandler = VNSequenceRequestHandler()
  private lazy var barcodeRequest: VNDetectBarcodesRequest = {
    let request = VNDetectBarcodesRequest()
    if #available(iOS 17, *) {
      request.revision = VNDetectBarcodesRequestRevision4
    } else if #available(iOS 16, *) {
      request.revision = VNDetectBarcodesRequestRevision3
    } else if #available(iOS 15, *) {
      request.revision = VNDetectBarcodesRequestRevision2
    }
    return request
  }()

  private var _symbologies = [String]()
  private weak var _session: AVCaptureSession?
  private var isActive = false

  var symbologies: [String] {
    get { _symbologies }
    set {
      _symbologies = newValue
      barcodeRequest.symbologies = vnBarcodeSymbologies(for: newValue)
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

  // MARK: Live video frame capture

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard isActive, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    do {
      try visionSequenceHandler.perform([barcodeRequest], on: pixelBuffer)
      guard let observations = barcodeRequest.results, !observations.isEmpty else { return }
      handleObservations(observations)
    } catch {
      // Transient Vision frame errors should not crash or terminate the live stream.
      print("fast_barcode_scanner: Vision frame error: \(error)")
    }
  }

  private func handleObservations(_ observations: [VNBarcodeObservation]) {
    let currentSymbologies = _symbologies
    var seen = Set<String>()

    let validObservations = observations.filter { observation in
      guard observation.confidence >= confidence,
        let payload = observation.payloadStringValue
      else {
        return false
      }
      return seen.insert("\(observation.symbology.rawValue)|\(payload)").inserted
    }

    guard !validObservations.isEmpty else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.isActive else { return }

      var scannedCodes: [[Any?]] = []

      for observation in validObservations {
        guard
          var type = flutterType(for: observation.symbology),
          var value = observation.payloadStringValue
        else {
          continue
        }

        if observation.symbology == .ean13 {
          if value.hasPrefix("0") && currentSymbologies.contains("upcA") {
            type = "upcA"
            value.removeFirst()
          } else if !currentSymbologies.contains("ean13") {
            continue
          }
        }

        let converted = self.boundsConverter?(observation)
        let rect = converted?.0 ?? observation.boundingBox
        let corners = (converted?.1 ?? [
          observation.topLeft,
          observation.topRight,
          observation.bottomRight,
          observation.bottomLeft,
        ]).map { [Double($0.x), Double($0.y)] }

        scannedCodes.append([
          type,
          value,
          [Double(rect.minX), Double(rect.minY), Double(rect.maxX), Double(rect.maxY)],
          corners,
        ])
      }

      guard !scannedCodes.isEmpty else { return }

      self.onDetection?()
      self.resultHandler(scannedCodes)
    }
  }

  // MARK: Still image processing

  static func scanStillImage(_ uiImage: UIImage) async throws -> [[Any?]] {
    guard let cgImage = uiImage.cgImage else {
      throw ScannerError.loadingDataFailed
    }

    let orientation = cgImagePropertyOrientation(from: uiImage.imageOrientation)

    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNDetectBarcodesRequest()
        if #available(iOS 17, *) {
          request.revision = VNDetectBarcodesRequestRevision4
        } else if #available(iOS 16, *) {
          request.revision = VNDetectBarcodesRequestRevision3
        } else if #available(iOS 15, *) {
          request.revision = VNDetectBarcodesRequestRevision2
        }

        let handler = VNImageRequestHandler(
          cgImage: cgImage,
          orientation: orientation,
          options: [:]
        )

        do {
          try handler.perform([request])
          let observations = request.results ?? []
          let width = Double(cgImage.width)
          let height = Double(cgImage.height)

          var seen = Set<String>()
          var results: [[Any?]] = []

          for observation in observations {
            guard
              let payload = observation.payloadStringValue,
              let type = flutterType(for: observation.symbology),
              seen.insert("\(type)|\(payload)").inserted
            else {
              continue
            }

            // Convert Vision's normalized bottom-left coordinates to image pixel top-left coordinates.
            let box = observation.boundingBox
            let left = Double(box.minX) * width
            let top = (1.0 - Double(box.maxY)) * height
            let right = Double(box.maxX) * width
            let bottom = (1.0 - Double(box.minY)) * height

            let corners = [
              observation.topLeft,
              observation.topRight,
              observation.bottomRight,
              observation.bottomLeft,
            ].map { [Double($0.x) * width, (1.0 - Double($0.y)) * height] }

            results.append([
              type,
              payload,
              [left, top, right, bottom],
              corners,
            ])
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
