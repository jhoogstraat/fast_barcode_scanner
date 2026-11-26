import AVFoundation

final class Camera: NSObject {
  let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(
    label: "com.jhoogstraat.fast_barcode_scanner.session",
    qos: .userInitiated
  )
  private var deviceInput: AVCaptureDeviceInput?
  private var captureDevice: AVCaptureDevice? { deviceInput?.device }
  private let scanner: BarcodeScanner

  private var targetConfiguration: CameraConfiguration
  private var wasUsingTorch = false
  private var isDisposed = false

  init(configuration: CameraConfiguration, scanner: BarcodeScanner) async throws {
    self.scanner = scanner
    self.targetConfiguration = configuration
    super.init()

    let authorized: Bool
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      authorized = true
    case .notDetermined:
      authorized = await AVCaptureDevice.requestAccess(for: .video)
    default:
      authorized = false
    }

    guard authorized else { throw ScannerError.unauthorized }
    addObservers()
  }

  deinit {
    removeObservers()
  }

  static func canSwitchCamera() -> Bool {
    let devices = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .unspecified
    ).devices
    return devices.contains { $0.position == .back } && devices.contains { $0.position == .front }
  }

  private func onSessionQueue<T>(_ body: @escaping (Camera) throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      sessionQueue.async { [weak self] in
        guard let self = self, !self.isDisposed else {
          continuation.resume(throwing: ScannerError.notInitialized)
          return
        }
        do {
          continuation.resume(returning: try body(self))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func configureSession(configuration: CameraConfiguration) async throws -> CameraInformation {
    try await onSessionQueue { camera in
      try camera.configureSessionOnQueue(configuration: configuration)
    }
  }

  func updateConfiguration(args: Any?) async throws -> CameraInformation {
    try await onSessionQueue { camera in
      guard let config = camera.targetConfiguration.copy(with: args) else {
        throw ScannerError.invalidArguments(args)
      }
      return try camera.configureSessionOnQueue(configuration: config)
    }
  }

  private func configureSessionOnQueue(configuration: CameraConfiguration) throws -> CameraInformation {
    let device =
      AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: configuration.position)
      ?? AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: configuration.position == .back ? .front : .back)

    guard let device = device else {
      throw ScannerError.noInputDeviceForConfig(configuration)
    }

    // Create new input before mutating session so failures never leave the session inputless.
    let newInput = try AVCaptureDeviceInput(device: device)

    session.beginConfiguration()
    defer { session.commitConfiguration() }

    let previousInputs = session.inputs
    previousInputs.forEach(session.removeInput)

    guard session.canAddInput(newInput) else {
      previousInputs.filter(session.canAddInput).forEach(session.addInput)
      throw ScannerError.configurationError("Could not add video device input to session")
    }

    session.addInput(newInput)
    self.deviceInput = newInput

    let detectionMode = configuration.detectionMode
    scanner.session = session
    scanner.symbologies = configuration.codes
    scanner.onDetection = { [weak self] in
      guard let self = self else { return }
      switch detectionMode {
      case .pauseDetection:
        self.scanner.stop()
      case .pauseVideo:
        self.scanner.stop()
        Task { await self.stop() }
      case .continuous:
        break
      }
    }

    applyPerformanceMode(configuration.performanceMode, to: device)
    self.targetConfiguration = configuration

    let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    let minZoom = Double(device.minAvailableVideoZoomFactor)
    let maxZoom = max(minZoom, min(Double(device.activeFormat.videoMaxZoomFactor), 10.0))

    return CameraInformation(
      videoWidth: dims.width,
      videoHeight: dims.height,
      sensorOrientation: 90,
      minZoom: minZoom,
      maxZoom: maxZoom
    )
  }

  private func applyPerformanceMode(_ mode: PerformanceMode, to device: AVCaptureDevice) {
    let (targetW, targetH) = mode.targetSize
    let targetFps = mode.targetFramerate

    let optimalFormat = device.formats
      .filter { format in
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let subType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
        return (subType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
          || subType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
          && dims.width >= targetW
          && dims.height >= targetH
          && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= targetFps }
      }
      .min { lhs, rhs in
        let l = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
        let r = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
        return (Int64(l.width) * Int64(l.height)) < (Int64(r.width) * Int64(r.height))
      }

    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }

      if let format = optimalFormat {
        device.activeFormat = format
        let range =
          format.videoSupportedFrameRateRanges.first { $0.maxFrameRate >= targetFps }
          ?? format.videoSupportedFrameRateRanges.first
        if let range = range {
          let desiredFps = max(range.minFrameRate, min(targetFps, range.maxFrameRate))
          let duration = CMTime(value: 1, timescale: CMTimeScale(desiredFps))
          device.activeVideoMinFrameDuration = duration
          device.activeVideoMaxFrameDuration = duration
        }
      } else if session.canSetSessionPreset(mode.fallbackPreset) {
        session.sessionPreset = mode.fallbackPreset
      }

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
    try await onSessionQueue { camera in
      if !camera.session.isRunning {
        camera.scanner.start()
        camera.session.startRunning()
      }
      if camera.wasUsingTorch {
        _ = try? camera.setTorchOnQueue(enabled: true)
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
        self.session.inputs.forEach(self.session.removeInput)
        self.session.outputs.forEach(self.session.removeOutput)
        self.session.commitConfiguration()
        self.deviceInput = nil
        continuation.resume()
      }
    }
  }

  func toggleTorch() async throws -> Bool {
    try await onSessionQueue { camera in
      guard let device = camera.captureDevice, device.isTorchAvailable else { return false }
      return try camera.setTorchOnQueue(enabled: !device.isTorchActive)
    }
  }

  private func setTorchOnQueue(enabled: Bool) throws -> Bool {
    guard let device = captureDevice, device.isTorchAvailable else { return false }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    device.torchMode = enabled ? .on : .off
    return device.torchMode == .on
  }

  func setZoom(_ factor: Double) async throws -> Double {
    try await onSessionQueue { camera in
      guard let device = camera.captureDevice else { throw ScannerError.notInitialized }
      let minZoom = Double(device.minAvailableVideoZoomFactor)
      let maxZoom = max(minZoom, min(Double(device.activeFormat.videoMaxZoomFactor), 10.0))
      let clamped = max(minZoom, min(factor, maxZoom))
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      device.videoZoomFactor = CGFloat(clamped)
      return Double(device.videoZoomFactor)
    }
  }

  func startScanner() {
    sessionQueue.async { [weak self] in
      guard let self = self, !self.isDisposed else { return }
      self.scanner.start()
    }
  }

  func stopScanner() {
    sessionQueue.async { [weak self] in
      self?.scanner.stop()
    }
  }

  private func addObservers() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(sessionRuntimeError),
      name: .AVCaptureSessionRuntimeError, object: session)
  }

  private func removeObservers() {
    NotificationCenter.default.removeObserver(
      self, name: .AVCaptureSessionRuntimeError, object: session)
  }

  @objc
  private func sessionRuntimeError(notification: NSNotification) {
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError,
      error.code == .mediaServicesWereReset
    else { return }
    sessionQueue.async { [weak self] in
      guard let self = self, !self.isDisposed, !self.session.isRunning else { return }
      self.session.startRunning()
    }
  }
}
