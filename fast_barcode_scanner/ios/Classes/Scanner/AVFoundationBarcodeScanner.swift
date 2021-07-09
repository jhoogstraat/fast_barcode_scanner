import AVFoundation

class AVFoundationBarcodeScanner: NSObject, BarcodeScanner, AVCaptureMetadataOutputObjectsDelegate {
    typealias Barcode = AVMetadataMachineReadableCodeObject

    init(resultHandler: @escaping ResultHandler) {
        self.resultHandler = resultHandler
    }

    var resultHandler: ResultHandler
    var onDetection: (() -> Void)?

    private let output = AVCaptureMetadataOutput()
    private let metadataQueue = DispatchQueue(label: "fast_barcode_scanner.metadata.serial")
    private var _session: AVCaptureSession?
    private var _symbologies = [String]()
    private var isPaused = false

    var symbologies: [String] {
        get { _symbologies }
        set {
            _symbologies = newValue

            // This will just ignore all incomptaible types
            output.metadataObjectTypes = newValue.compactMap { avMetadataObjectTypes[$0] }

            // UPC-A is reported as EAN-13
            if newValue.contains("upcA") && !output.metadataObjectTypes.contains(.ean13) {
                output.metadataObjectTypes.append(.ean13)
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

    func start() {
        output.setMetadataObjectsDelegate(self, queue: metadataQueue)
    }

    func stop() {
        output.setMetadataObjectsDelegate(nil, queue: nil)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
		guard
			let metadata = metadataObjects.first,
			let readableCode = metadata as? AVMetadataMachineReadableCodeObject,
            var type = flutterMetadataObjectTypes[readableCode.type],
            var value = readableCode.stringValue
        else { return }

        onDetection?()

        // Fix UPC-A, see https://developer.apple.com/library/archive/technotes/tn2325/_index.html#//apple_ref/doc/uid/DTS40013824-CH1-IS_UPC_A_SUPPORTED_
        if readableCode.type == .ean13 {
            if value.hasPrefix("0") {
                // UPC-A
                guard symbologies.contains("upcA") else { return }
                type = "upcA"
                value.removeFirst()
            } else {
                // EAN-13
                guard symbologies.contains(type) else { return }
            }
        }

        resultHandler([type, value])
	}
}
