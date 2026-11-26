import AVFoundation
import Vision

enum PerformanceMode: String {
  case system, economic, high

  var targetSize: (width: Int32, height: Int32) {
    switch self {
    case .economic: return (1280, 720)
    case .system: return (1920, 1080)
    case .high: return (3840, 2160)
    }
  }

  var targetFramerate: Double {
    self == .high ? 60 : 30
  }

  var fallbackPreset: AVCaptureSession.Preset {
    self == .economic ? .hd1280x720 : .hd1920x1080
  }
}

enum DetectionMode: String {
  case pauseDetection, pauseVideo, continuous
}

enum ApiOptions {
  case avFoundation
  case vision(confidence: Float)

  init?(api: String, options: [String: Any]) {
    switch api {
    case "avfoundation":
      self = .avFoundation
    case "vision":
      let confidence = (options["confidence"] as? NSNumber)?.floatValue ?? 0.6
      self = .vision(confidence: confidence)
    default:
      return nil
    }
  }
}

struct CameraConfiguration {
  let position: AVCaptureDevice.Position
  let performanceMode: PerformanceMode
  let detectionMode: DetectionMode
  let codes: [String]
  let apiOptions: ApiOptions

  func copy(with args: Any?) -> CameraConfiguration? {
    guard let dict = args as? [String: Any] else { return nil }
    return CameraConfiguration(
      position: cameraPositions[dict["pos"] as? String ?? ""] ?? position,
      performanceMode: PerformanceMode(rawValue: dict["mode"] as? String ?? "") ?? performanceMode,
      detectionMode: DetectionMode(rawValue: dict["detectionMode"] as? String ?? "")
        ?? detectionMode,
      codes: dict["types"] as? [String] ?? codes,
      apiOptions: apiOptions
    )
  }
}

extension CameraConfiguration {
  init?(_ args: Any?) {
    guard
      let dict = args as? [String: Any],
      let position = cameraPositions[dict["pos"] as? String ?? ""],
      let performanceMode = PerformanceMode(rawValue: dict["mode"] as? String ?? ""),
      let detectionMode = DetectionMode(rawValue: dict["detectionMode"] as? String ?? ""),
      let codes = dict["types"] as? [String],
      let api = dict["api"] as? String,
      let apiOptions = ApiOptions(api: api, options: dict["options"] as? [String: Any] ?? [:])
    else {
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
}

let cameraPositions: [String: AVCaptureDevice.Position] = [
  "front": .front,
  "back": .back,
]

// MARK: - AVFoundation symbology mappings

private let avSymbologyTable: [String: [AVMetadataObject.ObjectType]] = {
  var map: [String: [AVMetadataObject.ObjectType]] = [
    "aztec": [.aztec],
    "code128": [.code128],
    "code39": [.code39, .code39Mod43],
    "code93": [.code93],
    "dataMatrix": [.dataMatrix],
    "ean13": [.ean13],
    "ean8": [.ean8],
    "itf": [.itf14, .interleaved2of5],
    "pdf417": [.pdf417],
    "qr": [.qr],
    "upcA": [.ean13],
    "upcE": [.upce],
  ]
  if #available(iOS 15.4, *) {
    map["codabar"] = [.codabar]
    map["gs1DataBar"] = [.gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited]
  }
  return map
}()

private let avToFlutterMap: [AVMetadataObject.ObjectType: String] = {
  var reverse: [AVMetadataObject.ObjectType: String] = [:]
  for (name, types) in avSymbologyTable where name != "upcA" {
    for type in types { reverse[type] = name }
  }
  return reverse
}()

func avMetadataObjectTypes(for flutterTypes: [String]) -> [AVMetadataObject.ObjectType] {
  var result: [AVMetadataObject.ObjectType] = []
  var seen = Set<AVMetadataObject.ObjectType>()
  for name in flutterTypes {
    guard let mapped = avSymbologyTable[name] else {
      print("fast_barcode_scanner: Unsupported AVFoundation barcode type: \(name)")
      continue
    }
    for type in mapped where seen.insert(type).inserted {
      result.append(type)
    }
  }
  return result
}

func flutterType(for avType: AVMetadataObject.ObjectType) -> String? {
  avToFlutterMap[avType]
}

// MARK: - Vision symbology mappings

private let vnSymbologyTable: [String: [VNBarcodeSymbology]] = {
  var map: [String: [VNBarcodeSymbology]] = [
    "aztec": [.aztec],
    "code128": [.code128],
    "code39": [.code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum],
    "code93": [.code93, .code93i],
    "dataMatrix": [.dataMatrix],
    "ean13": [.ean13],
    "ean8": [.ean8],
    "itf": [.itf14, .i2of5, .i2of5Checksum],
    "pdf417": [.pdf417],
    "qr": [.qr],
    "upcA": [.ean13],
    "upcE": [.upce],
  ]
  if #available(iOS 15.0, *) {
    map["codabar"] = [.codabar]
    map["gs1DataBar"] = [.gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited]
    map["pdf417"]?.append(.microPDF417)
    map["qr"]?.append(.microQR)
  }
  if #available(iOS 17.0, *) {
    map["msi"] = [.msiPlessey]
  }
  return map
}()

private let vnToFlutterMap: [VNBarcodeSymbology: String] = {
  var reverse: [VNBarcodeSymbology: String] = [:]
  for (name, symbologies) in vnSymbologyTable where name != "upcA" {
    for symbology in symbologies { reverse[symbology] = name }
  }
  return reverse
}()

func vnBarcodeSymbologies(for flutterTypes: [String]) -> [VNBarcodeSymbology] {
  var result: [VNBarcodeSymbology] = []
  var seen = Set<VNBarcodeSymbology>()
  for name in flutterTypes {
    guard let mapped = vnSymbologyTable[name] else {
      print("fast_barcode_scanner: Unsupported Vision barcode type: \(name)")
      continue
    }
    for symbology in mapped where seen.insert(symbology).inserted {
      result.append(symbology)
    }
  }
  return result
}

func flutterType(for vnSymbology: VNBarcodeSymbology) -> String? {
  vnToFlutterMap[vnSymbology]
}
