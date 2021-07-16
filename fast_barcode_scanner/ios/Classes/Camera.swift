import AVFoundation

class Camera: NSObject {

    // MARK: Session Management

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "fbs.session.serial")
    private var deviceInput: AVCaptureDeviceInput!
    private var captureDevice: AVCaptureDevice { deviceInput.device }
    private var scanner: BarcodeScanner

    private(set) var configuration: ScannerConfiguration
    private(set) var previewConfiguration: PreviewConfiguration!
    private var torchState = false
    private var isSessionRunning = false

    init(configuration: ScannerConfiguration, scanner: BarcodeScanner) throws {
        self.scanner = scanner
        self.configuration = configuration
        super.init()

        var authorizationGranted = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                authorizationGranted = granted
                self.sessionQueue.resume()
            }
        default:
            authorizationGranted = false
        }

        try sessionQueue.sync {
            if authorizationGranted {
                try self.configureSession(configuration: configuration)
                self.addObservers()
            } else {
                throw ScannerError.unauthorized
            }
        }
    }

    func configureSession(configuration: ScannerConfiguration) throws {
        let requestedDevice: AVCaptureDevice?

        // Grab the requested camera device, otherwise toggle the position and try again.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: configuration.position) {
            requestedDevice = device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: configuration.position == .back ? .front : .back) {
            requestedDevice = device
        } else {
            requestedDevice = nil
        }

        guard let device = requestedDevice else {
            throw ScannerError.noInputDeviceForConfig(configuration)
        }

        session.beginConfiguration()

        session.inputs.forEach(session.removeInput)

        let deviceInput = try AVCaptureDeviceInput(device: device)

        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
            self.deviceInput = deviceInput
        } else {
            throw ScannerError.configurationError("Could not add video device input to session")
        }

        // Attach scanner to the session
        self.scanner.session = session
        self.scanner.symbologies = configuration.codes
        self.scanner.onDetection = { [unowned self] in
            switch configuration.detectionMode {
            case .pauseDetection:
                self.scanner.stop()
            case .pauseVideo:
                self.stop()
            case .continuous: break
            }
        }
        session.commitConfiguration()

        // Find the optimal settings for the requested resolution and frame rate.
        guard let optimalFormat = captureDevice.formats.first(where: {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let mediaSubType = CMFormatDescriptionGetMediaSubType($0.formatDescription).toString()

            return $0.videoSupportedFrameRateRanges.first!.maxFrameRate >= configuration.framerate.doubleValue
                && dimensions.height >= configuration.resolution.height
                && dimensions.width >= configuration.resolution.width
                && mediaSubType == "420f" // maybe 420v is also ok? Who knows...
        }) else {
            throw ScannerError.cameraNotSuitable(configuration.resolution, configuration.framerate)
        }

        do {
            try captureDevice.lockForConfiguration()
            captureDevice.activeFormat = optimalFormat
            captureDevice.activeVideoMaxFrameDuration =
                optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
            captureDevice.unlockForConfiguration()
        } catch {
            throw ScannerError.configurationError(error.localizedDescription)
        }

        let previewSize = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)

        self.configuration = configuration

        self.previewConfiguration = PreviewConfiguration(width: previewSize.width,
                             height: previewSize.height,
                             targetRotation: 0,
                             textureId: 0)
    }

    func start() throws {
        scanner.start()
        session.startRunning()
        isSessionRunning = session.isRunning

        if torchState {
            try toggleTorch()
        }
    }

    func stop() {
        torchState = captureDevice.isTorchActive
        session.stopRunning()
        isSessionRunning = session.isRunning
    }

    @discardableResult
    func toggleTorch() throws -> Bool {
        guard captureDevice.isTorchAvailable else { return false }

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = captureDevice.isTorchActive ? .off : .on
        captureDevice.unlockForConfiguration()

        return captureDevice.torchMode == .on
    }

    // MARK: KVO and Notifications
//    private var keyValueObservations = [NSKeyValueObservation]()

    func addObservers() {
//        var keyValueObservation: NSKeyValueObservation

//        keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
//            guard let isRunning = change.newValue else { return }
//            self.changeHandler(.init(isRunning: isRunning, isTorchOn: self.deviceInput.device.torchMode == .on))
//        }
//        keyValueObservations.append(keyValueObservation)
//
//        keyValueObservation = deviceInput.device.observe(\.torchMode, options: .new) { _, change in
//            guard let isTorchOn = change.newValue else { return }
//            self.changeHandler(.init(isRunning: self.session.isRunning, isTorchOn: isTorchOn == .on))
//        }
//        keyValueObservations.append(keyValueObservation)

        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
    }

    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: session)

//        for keyValueObservation in keyValueObservations {
//            keyValueObservation.invalidate()
//        }
//        keyValueObservations.removeAll()
    }

    // MARK: AVError handling

    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

        // Try to restart, if session was running
        if error.code == .mediaServicesWereReset && isSessionRunning {
            sessionQueue.async {
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
}
