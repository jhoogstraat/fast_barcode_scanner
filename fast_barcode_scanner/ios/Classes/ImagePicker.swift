import PhotosUI

protocol ImagePicker {
    typealias ResultHandler = ((UIImage?) -> Void)

    var resultHandler: ResultHandler { get }

    func show(over viewController: UIViewController)
}

@available(iOS 14, *)
class PHImagePicker: ImagePicker, PHPickerViewControllerDelegate {

    let resultHandler: ResultHandler

    init(resultHandler: @escaping ResultHandler) {
        self.resultHandler = resultHandler
    }

    func show(over viewController: UIViewController) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let itemProvider = results.first?.itemProvider,
           itemProvider.canLoadObject(ofClass: UIImage.self) else {
            resultHandler(nil)
            return
        }

        itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            guard error == nil else {
                print("Error loading object \(error!)")
                self.resultHandler(nil)
                return
            }

            self.resultHandler(object as? UIImage)
        }
    }
}

class UIImagePicker: NSObject, ImagePicker, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    init(resultHandler: @escaping ResultHandler) {
        self.resultHandler = resultHandler
    }

    var resultHandler: ResultHandler

    func show(over viewController: UIViewController) {
        let picker = UIImagePickerController()
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        resultHandler(info[.originalImage] as? UIImage)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        resultHandler(nil)
    }
}
