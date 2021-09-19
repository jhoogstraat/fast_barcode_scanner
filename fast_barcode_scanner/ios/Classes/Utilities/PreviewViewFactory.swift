import Flutter
import AVFoundation

class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    var session: AVCaptureSession?

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = PreviewView(frame: frame)
        view.session = session
        return view
    }
}
