//
//  StillBarcodeScanner.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 07.07.21.
//

import Vision

class StillBarcodeScanner: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    typealias ResultHandler = ((VNBarcodeObservation?) -> Void)

    let symbologies: [VNBarcodeSymbology]

    var root: UIViewController?
    var picker: UIImagePickerController?
    var resultHandler: ResultHandler?

    init(symbologies: [VNBarcodeSymbology], on result: ResultHandler?) {
        self.symbologies = symbologies
        self.resultHandler = result
        super.init()
    }

    func show(over root: UIViewController) {
        let picker = UIImagePickerController()
        picker.delegate = self

        self.root = root
        self.picker = picker

        root.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let uiImage = info[.originalImage] as? UIImage,
              let cgImage = uiImage.cgImage
        else {
            resultHandler?(nil)
            return
        }

        let cgOrientation = CGImagePropertyOrientation(uiImage.imageOrientation)

        performVisionRequest(image: cgImage, orientation: cgOrientation)

        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        resultHandler?(nil)
    }

    func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
        let imageRequestHandler = VNImageRequestHandler(cgImage: image,
                                                        orientation: orientation,
                                                        options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandler.perform([self.barcodeDetectionRequest])
            } catch let error as NSError {
                print("Failed to perform image request \(error)")
                self.resultHandler?(nil)
                return
            }
        }
    }

    /// - Tag: ConfigureDetectionHandler
    func handleDetectedBarcodes(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            print("Error performing detection \(nsError)")
            resultHandler?(nil)
        } else {
            guard let results = request?.results as? [VNBarcodeObservation] else {
                resultHandler?(nil)
                return
            }

            resultHandler?(results.max(by: { $0.confidence < $1.confidence }))
        }
    }

    /// - Tag: ConfigureCompletionHandler
    lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
        let request = VNDetectBarcodesRequest(completionHandler: self.handleDetectedBarcodes)
        request.symbologies = symbologies
        return request
    }()
}

extension CGImagePropertyOrientation {
    init(_ uiImageOrientation: UIImage.Orientation) {
        switch uiImageOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        default: self = .up
        }
    }
}
