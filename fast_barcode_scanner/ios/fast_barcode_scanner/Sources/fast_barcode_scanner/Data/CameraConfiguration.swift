import AVFoundation
import Vision

enum PerformanceMode: String {
  case system
  case economic
  case high

  var targetWidth: Int32 {
    switch self {
    case .economic: return 1280
    case .system: return 1920
    case .high: return 3840
    }
  }

  var targetHeight: Int32 {
    switch self {
    case .economic: return 720
    case .system: return 1080
    case .high: return 2160
    }
  }

  var targetFramerate: Double {
    switch self {
    case .economic: return 30
    case .system: return 30
    case .high: return 60
    }
  }

  var fallbackPreset: AVCaptureSession.Preset {
    switch self {
    case .economic: return .hd1280x720
    case .system: return .hd1920x1080
    case .high: return .hd1920x1080
    }
  }
}

enum DetectionMode: String {
  case pauseDetection
  case pauseVideo
  case continuous
}

enum ApiOptions {
  case avFoundation
  case vision(confidence: Float)
}

struct CameraConfiguration {
  let position: AVCaptureDevice.Position
  let performanceMode: PerformanceMode
  let detectionMode: DetectionMode
  let codes: [String]
  let apiOptions: ApiOptions

  init(
    position: AVCaptureDevice.Position,
    performanceMode: PerformanceMode,
    detectionMode: DetectionMode,
    codes: [String],
    apiOptions: ApiOptions
  ) {
    self.position = position
    self.performanceMode = performanceMode
    self.detectionMode = detectionMode
    self.codes = codes
    self.apiOptions = apiOptions
  }

  init?(_ args: Any?) {
    guard
      let dict = args as? [String: Any],
      let position = cameraPositions[dict["pos"] as? String ?? ""],
      let performanceMode = PerformanceMode(rawValue: dict["mode"] as? String ?? ""),
      let detectionMode = DetectionMode(rawValue: dict["detectionMode"] as? String ?? ""),
      let codes = dict["types"] as? [String],
      let api = dict["api"] as? String
    else {
      return nil
    }

    let options = dict["options"] as? [String: Any] ?? [:]
    let apiOptions: ApiOptions
    switch api {
    case "avfoundation":
      apiOptions = .avFoundation
    case "vision":
      let confidence = (options["confidence"] as? NSNumber)?.floatValue ?? 0.6
      apiOptions = .vision(confidence: confidence)
    default:
      return nil
    }

    self.init(
      position: position,
      performanceMode: performanceMode,
      detectionMode: detectionMode,
      codes: codes,
      apiOptions: apiOptions
    )
  }

  func copy(with args: Any?) -> CameraConfiguration? {
    guard let dict = args as? [String: Any] else {
      return nil
    }

    var updatedApiOptions = apiOptions
    if let api = dict["api"] as? String {
      let options = dict["options"] as? [String: Any] ?? [:]
      switch api {
      case "avfoundation":
        updatedApiOptions = .avFoundation
      case "vision":
        let confidence = (options["confidence"] as? NSNumber)?.floatValue ?? 0.6
        updatedApiOptions = .vision(confidence: confidence)
      default:
        return nil
      }
    }

    return CameraConfiguration(
      position: cameraPositions[dict["pos"] as? String ?? ""] ?? position,
      performanceMode: PerformanceMode(rawValue: dict["mode"] as? String ?? "") ?? performanceMode,
      detectionMode: DetectionMode(rawValue: dict["detectionMode"] as? String ?? "") ?? detectionMode,
      codes: dict["types"] as? [String] ?? codes,
      apiOptions: updatedApiOptions
    )
  }
}

let cameraPositions: [String: AVCaptureDevice.Position] = [
  "front": .front,
  "back": .back,
]

// MARK: - AVFoundation symbology mappings

func avMetadataObjectTypes(for flutterTypes: [String]) -> [AVMetadataObject.ObjectType] {
  var result: [AVMetadataObject.ObjectType] = []
  var unsupported: [String] = []

  func appendUnique(_ type: AVMetadataObject.ObjectType) {
    if !result.contains(type) {
      result.append(type)
    }
  }

  for name in flutterTypes {
    switch name {
    case "aztec":
      appendUnique(.aztec)
    case "codabar":
      if #available(iOS 15.4, *) {
        appendUnique(.codabar)
      } else {
        unsupported.append(name)
      }
    case "code128":
      appendUnique(.code128)
    case "code39":
      appendUnique(.code39)
      appendUnique(.code39Mod43)
    case "code93":
      appendUnique(.code93)
    case "dataMatrix":
      appendUnique(.dataMatrix)
    case "ean13":
      appendUnique(.ean13)
    case "ean8":
      appendUnique(.ean8)
    case "gs1DataBar":
      if #available(iOS 15.4, *) {
        appendUnique(.gs1DataBar)
        appendUnique(.gs1DataBarExpanded)
        appendUnique(.gs1DataBarLimited)
      } else {
        unsupported.append(name)
      }
    case "itf":
      appendUnique(.itf14)
      appendUnique(.interleaved2of5)
    case "pdf417":
      appendUnique(.pdf417)
    case "qr":
      appendUnique(.qr)
    case "upcA":
      // UPC-A is reported by AVFoundation as EAN-13 with a leading "0".
      appendUnique(.ean13)
    case "upcE":
      appendUnique(.upce)
    default:
      unsupported.append(name)
    }
  }

  if !unsupported.isEmpty {
    print("fast_barcode_scanner: Unsupported AVFoundation barcode types on this iOS version: \(unsupported)")
  }

  return result
}

func flutterType(for avType: AVMetadataObject.ObjectType) -> String? {
  if #available(iOS 15.4, *) {
    switch avType {
    case .codabar: return "codabar"
    case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: return "gs1DataBar"
    default: break
    }
  }

  switch avType {
  case .aztec: return "aztec"
  case .code128: return "code128"
  case .code39, .code39Mod43: return "code39"
  case .code93: return "code93"
  case .dataMatrix: return "dataMatrix"
  case .ean13: return "ean13"
  case .ean8: return "ean8"
  case .itf14, .interleaved2of5: return "itf"
  case .pdf417: return "pdf417"
  case .qr: return "qr"
  case .upce: return "upcE"
  default: return nil
  }
}

// MARK: - Vision symbology mappings

func vnBarcodeSymbologies(for flutterTypes: [String]) -> [VNBarcodeSymbology] {
  var result: [VNBarcodeSymbology] = []
  var unsupported: [String] = []

  func appendUnique(_ symbology: VNBarcodeSymbology) {
    if !result.contains(symbology) {
      result.append(symbology)
    }
  }

  for name in flutterTypes {
    switch name {
    case "aztec":
      appendUnique(.aztec)
    case "codabar":
      if #available(iOS 15.0, *) {
        appendUnique(.codabar)
      } else {
        unsupported.append(name)
      }
    case "code128":
      appendUnique(.code128)
    case "code39":
      appendUnique(.code39)
      appendUnique(.code39Checksum)
      appendUnique(.code39FullASCII)
      appendUnique(.code39FullASCIIChecksum)
    case "code93":
      appendUnique(.code93)
      appendUnique(.code93i)
    case "dataMatrix":
      appendUnique(.dataMatrix)
    case "ean13":
      appendUnique(.ean13)
    case "ean8":
      appendUnique(.ean8)
    case "gs1DataBar":
      if #available(iOS 15.0, *) {
        appendUnique(.gs1DataBar)
        appendUnique(.gs1DataBarExpanded)
        appendUnique(.gs1DataBarLimited)
      } else {
        unsupported.append(name)
      }
    case "itf":
      appendUnique(.itf14)
      appendUnique(.i2of5)
      appendUnique(.i2of5Checksum)
    case "msi":
      if #available(iOS 17.0, *) {
        appendUnique(.msiPlessey)
      } else {
        unsupported.append(name)
      }
    case "pdf417":
      appendUnique(.pdf417)
      if #available(iOS 15.0, *) {
        appendUnique(.microPDF417)
      }
    case "qr":
      appendUnique(.qr)
      if #available(iOS 15.0, *) {
        appendUnique(.microQR)
      }
    case "upcA":
      appendUnique(.ean13)
    case "upcE":
      appendUnique(.upce)
    default:
      unsupported.append(name)
    }
  }

  if !unsupported.isEmpty {
    print("fast_barcode_scanner: Unsupported Vision barcode types on this iOS version: \(unsupported)")
  }

  return result
}

func flutterType(for vnSymbology: VNBarcodeSymbology) -> String? {
  if #available(iOS 17.0, *) {
    if vnSymbology == .msiPlessey {
      return "msi"
    }
  }

  if #available(iOS 15.0, *) {
    switch vnSymbology {
    case .codabar: return "codabar"
    case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: return "gs1DataBar"
    case .microPDF417: return "pdf417"
    case .microQR: return "qr"
    default: break
    }
  }

  switch vnSymbology {
  case .aztec: return "aztec"
  case .code128: return "code128"
  case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: return "code39"
  case .code93, .code93i: return "code93"
  case .dataMatrix: return "dataMatrix"
  case .ean13: return "ean13"
  case .ean8: return "ean8"
  case .itf14, .i2of5, .i2of5Checksum: return "itf"
  case .pdf417: return "pdf417"
  case .qr: return "qr"
  case .upce: return "upcE"
  default: return nil
  }
}
