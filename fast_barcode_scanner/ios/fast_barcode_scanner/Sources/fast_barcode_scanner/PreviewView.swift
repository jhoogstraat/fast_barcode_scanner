import AVFoundation
import Flutter
import UIKit

final class PreviewView: UIView, FlutterPlatformView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    videoPreviewLayer.videoGravity = .resizeAspectFill
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    videoPreviewLayer.videoGravity = .resizeAspectFill
  }

  func view() -> UIView {
    self
  }

  // MARK: AVFoundation session

  var session: AVCaptureSession? {
    get { videoPreviewLayer.session }
    set {
      videoPreviewLayer.session = newValue
      updateVideoOrientation()
    }
  }

  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }

  // MARK: UIView

  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    videoPreviewLayer.frame = bounds
    updateVideoOrientation()
  }

  private func updateVideoOrientation() {
    guard let connection = videoPreviewLayer.connection else { return }

    let interfaceOrientation: UIInterfaceOrientation?
    if #available(iOS 13.0, *) {
      interfaceOrientation = window?.windowScene?.interfaceOrientation
    } else {
      interfaceOrientation = nil
    }

    guard let orientation = interfaceOrientation else { return }

    if #available(iOS 17.0, *) {
      let angle: CGFloat
      switch orientation {
      case .portrait: angle = 90
      case .portraitUpsideDown: angle = 270
      case .landscapeLeft: angle = 180
      case .landscapeRight: angle = 0
      default: angle = 90
      }
      if connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    } else if connection.isVideoOrientationSupported {
      switch orientation {
      case .portrait: connection.videoOrientation = .portrait
      case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
      case .landscapeLeft: connection.videoOrientation = .landscapeLeft
      case .landscapeRight: connection.videoOrientation = .landscapeRight
      default: connection.videoOrientation = .portrait
      }
    }
  }
}
