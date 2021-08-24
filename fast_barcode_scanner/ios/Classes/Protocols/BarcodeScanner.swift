import AVFoundation

protocol BarcodeScanner {
    typealias ResultHandler = (([String]?) -> Void)

    var session: AVCaptureSession? { get set }

    var symbologies: [String] { get set }

    var onDetection: (() -> Void)? { get set }

    func start()

    func stop()

    var resultHandler: ResultHandler { get }
}
