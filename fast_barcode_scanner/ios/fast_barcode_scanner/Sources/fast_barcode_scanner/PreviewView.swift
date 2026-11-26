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

  func view() -> UIView { self }

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

  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateVideoOrientation()
  }

  private func updateVideoOrientation() {
    guard
      let connection = videoPreviewLayer.connection,
      let orientation = window?.windowScene?.interfaceOrientation
    else { return }

    if #available(iOS 17.0, *) {
      let angle: CGFloat = switch orientation {
      case .portraitUpsideDown: 270
      case .landscapeLeft: 180
      case .landscapeRight: 0
      default: 90
      }
      if connection.isVideoRotationAngleSupported(angle), connection.videoRotationAngle != angle {
        connection.videoRotationAngle = angle
      }
    } else if connection.isVideoOrientationSupported {
      let videoOrientation: AVCaptureVideoOrientation = switch orientation {
      case .portraitUpsideDown: .portraitUpsideDown
      case .landscapeLeft: .landscapeLeft
      case .landscapeRight: .landscapeRight
      default: .portrait
      }
      if connection.videoOrientation != videoOrientation {
        connection.videoOrientation = videoOrientation
      }
    }
  }
}
