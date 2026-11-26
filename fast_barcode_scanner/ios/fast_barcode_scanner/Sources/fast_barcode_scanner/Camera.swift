import AVFoundation
import UIKit

final class Camera: NSObject {
  // MARK: Session Management

  let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(
    label: "com.jhoogstraat.fast_barcode_scanner.session",
    qos: .userInitiated
  )
  private var deviceInput: AVCaptureDeviceInput?
  private var captureDevice: AVCaptureDevice? { deviceInput?.device }
  private let scanner: BarcodeScanner

  private(set) var targetConfiguration: CameraConfiguration
  private(set) var cameraInformation: CameraInformation!

  private var wasUsingTorch = false
  private var isDisposed = false

  init(configuration: CameraConfiguration, scanner: BarcodeScanner) async throws {
    self.scanner = scanner
    self.targetConfiguration = configuration
    super.init()

    let authorizationGranted: Bool
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      authorizationGranted = true
    case .notDetermined:
      authorizationGranted = await AVCaptureDevice.requestAccess(for: .video)
    default:
      authorizationGranted = false
    }

    guard authorizationGranted else {
      throw ScannerError.unauthorized
    }

    try await configureSession(configuration: configuration)
    addObservers()
  }

  deinit {
    removeObservers()
  }

  static func canSwitchCamera() -> Bool {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .unspecified
    )
    let hasBack = discovery.devices.contains { $0.position == .back }
    let hasFront = discovery.devices.contains { $0.position == .front }
    return hasBack && hasFront
  }

  func configureSession(configuration: CameraConfiguration) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      sessionQueue.async { [weak self] in
        guard let self = self, !self.isDisposed else {
          continuation.resume(throwing: ScannerError.notInitialized)
          return
        }

        do {
          try self.configureSessionOnQueue(configuration: configuration)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func configureSessionOnQueue(configuration: CameraConfiguration) throws {
    let requestedDevice: AVCaptureDevice?
    if let device = AVCaptureDevice.default(
      .builtInWideAngleCamera,
      for: .video,
      position: configuration.position
    ) {
      requestedDevice = device
    } else if let fallback = AVCaptureDevice.default(
      .builtInWideAngleCamera,
      for: .video,
      position: configuration.position == .back ? .front : .back
    ) {
      requestedDevice = fallback
    } else {
      requestedDevice = nil
    }

    guard let device = requestedDevice else {
      throw ScannerError.noInputDeviceForConfig(configuration)
    }

    session.beginConfiguration()
    defer { session.commitConfiguration() }

    for input in session.inputs {
      session.removeInput(input)
    }

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw ScannerError.configurationError("Could not add video device input to session")
    }

    session.addInput(input)
    self.deviceInput = input

    scanner.session = session
    scanner.symbologies = configuration.codes
    scanner.onDetection = { [weak self] in
      guard let self = self else { return }
      switch self.targetConfiguration.detectionMode {
      case .pauseDetection:
        self.scanner.stop()
      case .pauseVideo:
        Task { await self.stop() }
      case .continuous:
        break
      }
    }

    applyPerformanceMode(configuration.performanceMode, to: device)

    self.targetConfiguration = configuration

    let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    let minZoom = Double(device.minAvailableVideoZoomFactor)
    let maxZoom = min(Double(device.activeFormat.videoMaxZoomFactor), 10.0)

    self.cameraInformation = CameraInformation(
      videoWidth: dimensions.width,
      videoHeight: dimensions.height,
      analysisWidth: dimensions.width,
      analysisHeight: dimensions.height,
      sensorOrientation: 90,
      minZoom: minZoom,
      maxZoom: max(minZoom, maxZoom)
    )
  }

  private func applyPerformanceMode(_ mode: PerformanceMode, to device: AVCaptureDevice) {
    // Select best matching format without failing on constrained devices.
    let targetW = mode.targetWidth
    let targetH = mode.targetHeight
    let targetFps = mode.targetFramerate

    let candidates = device.formats.filter { format in
      let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      let subType = CMFormatDescriptionGetMediaSubType(format.formatDescription).toString()
      let maxFps = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
      return (subType == "420f" || subType == "420v")
        && dims.width >= targetW
        && dims.height >= targetH
        && maxFps >= targetFps
    }

    // Prefer the smallest format that still meets the target (avoids unnecessary 4K overhead in system/economic mode).
    let optimalFormat = candidates.min { lhs, rhs in
      let lDims = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
      let rDims = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
      return (Int64(lDims.width) * Int64(lDims.height)) < (Int64(rDims.width) * Int64(rDims.height))
    }

    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }

      if let format = optimalFormat {
        device.activeFormat = format
        if let range = format.videoSupportedFrameRateRanges.first {
          let desiredFps = min(targetFps, range.maxFrameRate)
          let duration = CMTime(value: 1, timescale: CMTimeScale(desiredFps))
          device.activeVideoMinFrameDuration = duration
          device.activeVideoMaxFrameDuration = duration
        }
      } else if session.canSetSessionPreset(mode.fallbackPreset) {
        session.sessionPreset = mode.fallbackPreset
      }

      // Optimize autofocus for fast barcode acquisition (including curved/close objects).
      if device.isFocusModeSupported(.continuousAutoFocus) {
        device.focusMode = .continuousAutoFocus
      }
      if device.isAutoFocusRangeRestrictionSupported {
        device.autoFocusRangeRestriction = .near
      }
      if device.isSmoothAutoFocusSupported {
        device.isSmoothAutoFocusEnabled = true
      }
    } catch {
      if session.canSetSessionPreset(mode.fallbackPreset) {
        session.sessionPreset = mode.fallbackPreset
      }
    }
  }

  func start() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      sessionQueue.async { [weak self] in
        guard let self = self, !self.isDisposed else {
          continuation.resume(throwing: ScannerError.notInitialized)
          return
        }

        if !self.session.isRunning {
          self.scanner.start()
          self.session.startRunning()
        }

        if self.wasUsingTorch {
          _ = try? self.setTorchOnQueue(enabled: true)
        }

        continuation.resume()
      }
    }
  }

  func stop() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      sessionQueue.async { [weak self] in
        guard let self = self else {
          continuation.resume()
          return
        }

        if let device = self.captureDevice {
          self.wasUsingTorch = device.isTorchActive
        }

        self.scanner.stop()

        if self.session.isRunning {
          self.session.stopRunning()
        }

        continuation.resume()
      }
    }
  }

  func dispose() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      sessionQueue.async { [weak self] in
        guard let self = self else {
          continuation.resume()
          return
        }

        self.isDisposed = true
        self.removeObservers()
        self.scanner.stop()

        if self.session.isRunning {
          self.session.stopRunning()
        }

        self.session.beginConfiguration()
        for input in self.session.inputs {
          self.session.removeInput(input)
        }
        for output in self.session.outputs {
          self.session.removeOutput(output)
        }
        self.session.commitConfiguration()

        self.deviceInput = nil
        continuation.resume()
      }
    }
  }

  @discardableResult
  func toggleTorch() throws -> Bool {
    guard let device = captureDevice, device.isTorchAvailable else { return false }
    return try setTorchOnQueue(enabled: !device.isTorchActive)
  }

  private func setTorchOnQueue(enabled: Bool) throws -> Bool {
    guard let device = captureDevice, device.isTorchAvailable else { return false }

    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    device.torchMode = enabled ? .on : .off
    return device.torchMode == .on
  }

  func setZoom(_ factor: Double) throws -> Double {
    guard let device = captureDevice else {
      throw ScannerError.notInitialized
    }

    let minZoom = Double(device.minAvailableVideoZoomFactor)
    let maxZoom = min(Double(device.activeFormat.videoMaxZoomFactor), 10.0)
    let clamped = max(minZoom, min(factor, maxZoom))

    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    device.videoZoomFactor = CGFloat(clamped)
    return Double(device.videoZoomFactor)
  }

  func startScanner() {
    sessionQueue.async { [weak self] in
      guard let self = self, !self.isDisposed else { return }
      self.scanner.start()
    }
  }

  func stopScanner() {
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      self.scanner.stop()
    }
  }

  // MARK: Notifications

  private func addObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sessionRuntimeError),
      name: .AVCaptureSessionRuntimeError,
      object: session
    )
  }

  private func removeObservers() {
    NotificationCenter.default.removeObserver(
      self,
      name: .AVCaptureSessionRuntimeError,
      object: session
    )
  }

  @objc
  private func sessionRuntimeError(notification: NSNotification) {
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

    if error.code == .mediaServicesWereReset {
      sessionQueue.async { [weak self] in
        guard let self = self, !self.isDisposed, !self.session.isRunning else { return }
        self.session.startRunning()
      }
    }
  }
}
