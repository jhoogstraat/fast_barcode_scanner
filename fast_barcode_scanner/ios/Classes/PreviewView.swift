//
//  PreviewView.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 09.07.21.
//

import AVFoundation
import Flutter

class PreviewView: UIView, FlutterPlatformView {
    func view() -> UIView {
        self
    }

    // MARK: AVFoundation session
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }

        set {
            videoPreviewLayer.session = newValue
        }
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        (layer as! AVCaptureVideoPreviewLayer)
    }

    // MARK: UIView
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

}
