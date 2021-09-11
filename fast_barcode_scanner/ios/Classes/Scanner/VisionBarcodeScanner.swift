import AVFoundation
import Vision

class VisionBarcodeScanner: NSObject, BarcodeScanner, AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias Barcode = VNBarcodeObservation

    var resultHandler: ResultHandler
    var onDetection: (() -> Void)?

    private let output = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "fast_barcode_scanner.data.serial", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    private lazy var visionBarcodesRequests: [VNDetectBarcodesRequest]! = {
        let request = VNDetectBarcodesRequest(completionHandler: handleVisionRequestUpdate)
        if #available(iOS 15, *) {
            request.revision = VNDetectBarcodesRequestRevision2
        }
        return [request]
    }()
    private let visionSequenceHandler = VNSequenceRequestHandler()

    private var _session: AVCaptureSession?
    private var _symbologies = [String]()

    var symbologies: [String] {
        get { _symbologies }
        set {
            _symbologies = newValue

            // This will just ignore all incompatible types
            visionBarcodesRequests.first!.symbologies = newValue.compactMap({ vnBarcodeSymbols[$0] })

            // UPC-A is reported as EAN-13
            if newValue.contains("upcA") && !visionBarcodesRequests.first!.symbologies.contains(.EAN13) {
                visionBarcodesRequests.first!.symbologies.append(.EAN13)
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

    init(resultHandler: @escaping ResultHandler) {
        self.resultHandler = resultHandler
        super.init()

        self.output.alwaysDiscardsLateVideoFrames = true
    }

    func start() {
        output.setSampleBufferDelegate(self, queue: outputQueue)
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
    }

    // MARK: AVFoundation capture output

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            do {
                try visionSequenceHandler.perform(visionBarcodesRequests, on: pixelBuffer)
            } catch {
                handleVisionRequestUpdate(request: nil, error: error)
            }
        }
    }

    // MARK: Still image processing

    func process(_ cgImage: CGImage) {
        do {
            try visionSequenceHandler.perform(visionBarcodesRequests, on: cgImage)
        } catch {
            handleVisionRequestUpdate(request: nil, error: error)
        }
    }

    // MARK: Callback

    private func handleVisionRequestUpdate(request: VNRequest?, error: Error?) {
        if let results = request?.results as? [VNBarcodeObservation],
              let barcode = results.max(by: { $0.confidence < $1.confidence }),
              let type = flutterVNSymbols[barcode.symbology],
              let value = barcode.payloadStringValue {
            onDetection?()
            resultHandler([type, value])
        } else {
            print("Error scanning image: \(String(describing: error))")
            resultHandler(error)
        }
    }
}
