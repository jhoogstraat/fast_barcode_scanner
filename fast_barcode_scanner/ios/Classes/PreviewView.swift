//
//  PreviewView.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 06.07.21.
//

import AVFoundation
import Flutter

class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    var viewId: Int64?
    var session: AVCaptureSession?

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        self.viewId = viewId
        let view = PreviewView(frame: frame)
        view.setSession(session)
        return view
    }

}

class PreviewView: UIView, FlutterPlatformView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    func view() -> UIView { self }

    func setSession(_ session: AVCaptureSession?) {
        // swiftlint:disable:next force_cast
        (layer as! AVCaptureVideoPreviewLayer).session = session
    }
}
