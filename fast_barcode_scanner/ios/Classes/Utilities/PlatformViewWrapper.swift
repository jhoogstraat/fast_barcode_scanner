import Flutter
import AVFoundation

class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    var session: AVCaptureSession?

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let viewWrapper = FlutterViewWrapper<PreviewView>(frame: frame)
        viewWrapper._view.session = session
        return viewWrapper
    }
}

class FlutterViewWrapper<View: UIView>: NSObject, FlutterPlatformView {
    let _view: View

    init(frame: CGRect) {
        _view = View(frame: frame)
    }

    func view() -> UIView { _view }
}
