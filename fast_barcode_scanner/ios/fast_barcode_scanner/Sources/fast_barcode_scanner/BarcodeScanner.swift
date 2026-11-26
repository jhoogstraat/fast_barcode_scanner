import AVFoundation
import CoreGraphics

protocol BarcodeScanner: AnyObject {
  /// Serialized list of barcodes `[[type, value, boundingBox, cornerPoints]]` or a `FlutterError`.
  typealias ResultHandler = (Any?) -> Void

  var session: AVCaptureSession? { get set }
  var symbologies: [String] { get set }
  var onDetection: (() -> Void)? { get set }

  func start()
  func stop()
}

/// Normalizes Apple's EAN-13 reporting of UPC-A (leading `"0"`) against enabled symbologies.
func normalizeBarcodeTypeAndValue(
  type: String,
  value: String,
  isEan13: Bool,
  acceptsUpcA: Bool,
  acceptsEan13: Bool
) -> (String, String)? {
  guard isEan13 else { return (type, value) }
  if value.hasPrefix("0") && acceptsUpcA {
    return ("upcA", String(value.dropFirst()))
  }
  return acceptsEan13 ? (type, value) : nil
}

/// Serializes a detected barcode into the cross-platform wire format.
func serializeBarcode(
  type: String,
  value: String,
  bounds: CGRect,
  corners: [CGPoint]
) -> [Any] {
  [
    type,
    value,
    [Double(bounds.minX), Double(bounds.minY), Double(bounds.maxX), Double(bounds.maxY)],
    corners.map { [Double($0.x), Double($0.y)] },
  ]
}
