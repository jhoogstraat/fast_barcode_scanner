import AVFoundation

protocol BarcodeScanner {
    typealias ResultHandler = (Any?) -> Void

    var session: AVCaptureSession? { get set }

    var symbologies: [String] { get set }

    var onDetection: (() -> Void)? { get set }

    func start()

    func stop()
}
