import AVFoundation
import Vision

class VisionBarcodeScanner: NSObject, BarcodeScanner, AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias Barcode = VNBarcodeObservation

    var resultHandler: ResultHandler
    var onDetection: (() -> Void)?

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "fast_barcode_scanner.data.serial")
    private var _session: AVCaptureSession?
    private var _symbologies = [String]()

    var symbologies: [String] {
        get { _symbologies }
        set {
            _symbologies = newValue

            // This will just ignore all incomptaible types
            barcodeDetectionRequest.symbologies = newValue.compactMap({ vnBarcodeSymbols[$0] })

            // UPC-A is reported as EAN-13
            if newValue.contains("upcA") && !barcodeDetectionRequest.symbologies.contains(.EAN13) {
                barcodeDetectionRequest.symbologies.append(.EAN13)
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

    /// - Tag: ConfigureCompletionHandler
    private lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
        VNDetectBarcodesRequest(completionHandler: self.handleDetectedBarcodes)
    }()

    init(resultHandler: @escaping ResultHandler) {
        self.resultHandler = resultHandler
        super.init()

        self.output.alwaysDiscardsLateVideoFrames = true
    }

    func start() {
        output.setSampleBufferDelegate(self, queue: queue)
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
    }

    // MARK: Vision handling

    func performVisionRequest(cgImage: CGImage, orientation: CGImagePropertyOrientation) {
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                        orientation: orientation,
                                                        options: [:])
        perform(requestHandler: imageRequestHandler)
    }

    private func perform(requestHandler: VNImageRequestHandler) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([self.barcodeDetectionRequest])
            } catch let error as NSError {
                print("Failed to perform image request \(error)")
                return self.resultHandler(nil)
            }
        }
    }

    private func handleDetectedBarcodes(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            print("Error performing detection \(nsError)")
        } else {
            guard let results = request?.results as? [VNBarcodeObservation],
                  let barcode = results.max(by: { $0.confidence < $1.confidence }),
                  let type = flutterVNSymbols[barcode.symbology],
                  let value = barcode.payloadStringValue
            else {
                resultHandler(nil)
                return
            }

            onDetection?()
            resultHandler([type, value])
        }
    }

    // MARK: AVFoundation capture output
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            perform(requestHandler: handler)
        }
    }
}
