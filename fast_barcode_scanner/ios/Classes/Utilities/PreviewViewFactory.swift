import Flutter
import AVFoundation

class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    var session: AVCaptureSession?

    // TODO: find out if there is a standard way to get a reference to the FlutterPlatformView instance
    public static var preview: PreviewView?

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = PreviewView(frame: frame)
        view.session = session
        // TODO: this is a hack because I cannot find a standard way to reference the created FlutterPlatformView. We need it to be able to correctly translate scanned code coordinates
        PreviewViewFactory.preview = view
        return view
    }
}
