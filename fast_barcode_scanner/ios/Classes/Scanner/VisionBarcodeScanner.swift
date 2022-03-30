import Flutter
import AVFoundation
import Vision

@available(iOS 11.0, *)
typealias VisionBarcodeCornerPointConverter = (VNBarcodeObservation) -> [[Int]]?

@available(iOS 11.0, *)
class VisionBarcodeScanner: NSObject, BarcodeScanner, AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias ErrorHandler = (FlutterError?) -> Void

    typealias Barcode = VNBarcodeObservation

    var resultHandler: ResultHandler
    var errorHandler: ErrorHandler
    var cornerPointConverter: VisionBarcodeCornerPointConverter
    var confidence: Double
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
        get {
            _symbologies
        }
        set {
            _symbologies = newValue

            // This will just ignore all unsupported types
            visionBarcodesRequests.first!.symbologies = newValue.compactMap({ vnBarcodeSymbols[$0] })

            // UPC-A is reported as EAN-13
            if newValue.contains("upcA") && !visionBarcodesRequests.first!.symbologies.contains(.EAN13) {
                visionBarcodesRequests.first!.symbologies.append(.EAN13)
            }

            // Report to the user if any types are not supported
            if visionBarcodesRequests.first!.symbologies.count != newValue.count {
                let unsupportedTypes = newValue.filter {
                    vnBarcodeSymbols[$0] == nil
                }
                print("WARNING: Unsupported barcode types selected: \(unsupportedTypes)")
            }
        }
    }

    var session: AVCaptureSession? {
        get {
            _session
        }
        set {
            _session = newValue
            if let session = newValue, session.canAddOutput(output), !session.outputs.contains(output) {
                session.addOutput(output)
            }
        }
    }

    init(cornerPointConverter: @escaping VisionBarcodeCornerPointConverter, confidence: Double, resultHandler: @escaping ResultHandler, errorHandler: @escaping ErrorHandler) {
        self.resultHandler = resultHandler
        self.errorHandler = errorHandler
        self.cornerPointConverter = cornerPointConverter
        self.confidence = confidence
        super.init()

        output.alwaysDiscardsLateVideoFrames = true
    }

    func start() {
        output.setSampleBufferDelegate(self, queue: outputQueue)
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
    }

    // MARK: Vision capture output

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
        guard let results = request?.results as? [VNBarcodeObservation] else {
            let message = error != nil ? "\(error!)" : "unknownError"
            print("Error scanning image: \(message)")
            let flutterError = FlutterError(code: "UNEXPECTED_SCAN_ERROR", message: message, details: error?._code)
            errorHandler(flutterError)
            return
        }

        let barcodes: [[Any?]] = results.filter { $0.confidence > Float(confidence) }.map {
                    let pointList = cornerPointConverter($0)
                    return [flutterVNSymbols[$0.symbology]!, $0.payloadStringValue ?? "", nil, pointList]
                }

        // consolidate any duplicate scans. Code128 has been observed to produce multiple scans
        var barcodeDict = [String: [Any?]]()
        for barcode: [Any?] in barcodes {
            let barcodeType = barcode[0] as! String
            let barcodeValue = barcode[1] as! String
            let key = "\(barcodeType)|\(barcodeValue)"
            let existingBarcodes = barcodeDict[key]
            if existingBarcodes == nil {
                barcodeDict[key] = barcode
            }
        }
        let uniqueCodes = Array(barcodeDict.values)

        onDetection?()
        resultHandler(uniqueCodes)
    }
}

@available(iOS 11.0, *)
extension VNBarcodeObservation {
    var pointList: [[Int]] {
        get {
            [
                [Int(topLeft.x), Int(topLeft.y)],
                [Int(topRight.x), Int(topRight.y)],
                [Int(bottomRight.x), Int(bottomRight.y)],
                [Int(bottomLeft.x), Int(bottomLeft.y)]
            ]
        }
    }
}
