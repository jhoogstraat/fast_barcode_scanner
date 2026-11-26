import AVFoundation
import Flutter

protocol BarcodeScanner: AnyObject {
  /// Either a serialized list of barcodes `[[type, value, boundingBox, cornerPoints]]`
  /// or a `FlutterError`.
  typealias ResultHandler = (Any?) -> Void

  var session: AVCaptureSession? { get set }

  var symbologies: [String] { get set }

  var onDetection: (() -> Void)? { get set }

  func start()

  func stop()
}
