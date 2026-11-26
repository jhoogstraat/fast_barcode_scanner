/// The supported barcode symbologies.
///
/// Sources:
/// - https://developer.apple.com/documentation/vision/vnbarcodesymbology
/// - https://developer.apple.com/documentation/avfoundation/avmetadatamachinereadablecodeobject/machine-readable_object_types
/// - https://developers.google.com/android/reference/com/google/mlkit/vision/barcode/common/Barcode.BarcodeFormat
enum BarcodeType {
  /// Aztec 2D barcode (iOS, Android).
  aztec,

  /// Codabar 1D barcode (iOS 15.4+, Android).
  codabar,

  /// Code 128 1D barcode (iOS, Android).
  code128,

  /// Code 39 1D barcode (iOS, Android).
  code39,

  /// Code 93 1D barcode (iOS, Android).
  code93,

  /// Data Matrix 2D barcode, including GS1 DataMatrix (iOS, Android).
  dataMatrix,

  /// EAN-13 1D barcode (iOS, Android).
  ean13,

  /// EAN-8 1D barcode (iOS, Android).
  ean8,

  /// GS1 DataBar 1D barcode (iOS 15.4+ Vision / iOS 15.4+ AVFoundation).
  gs1DataBar,

  /// Interleaved 2 of 5 / ITF-14 1D barcode (iOS, Android).
  itf,

  /// MSI Plessey 1D barcode (iOS 17+ Vision).
  msi,

  /// PDF417 2D stacked barcode (iOS, Android).
  pdf417,

  /// QR Code 2D barcode (iOS, Android).
  qr,

  /// UPC-A 1D barcode (iOS, Android).
  upcA,

  /// UPC-E 1D barcode (iOS, Android).
  upcE,
}
