import AVFoundation
import Flutter

@MainActor
final class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
  var session: AVCaptureSession? {
    didSet { preview?.session = session }
  }

  weak var preview: PreviewView?

  nonisolated func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    MainActor.assumeIsolated {
      let view = PreviewView(frame: frame)
      view.session = session
      preview = view
      return view
    }
  }
}
