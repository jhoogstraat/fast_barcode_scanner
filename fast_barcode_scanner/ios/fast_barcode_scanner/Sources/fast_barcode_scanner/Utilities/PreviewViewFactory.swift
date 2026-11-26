import AVFoundation
import Flutter

final class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
  var session: AVCaptureSession? {
    didSet {
      DispatchQueue.main.async { [weak self] in
        self?.preview?.session = self?.session
      }
    }
  }

  weak var preview: PreviewView?

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let view = PreviewView(frame: frame)
    view.session = session
    preview = view
    return view
  }
}
