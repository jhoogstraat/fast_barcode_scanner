import PhotosUI
import UIKit

@MainActor
protocol ImagePicker: AnyObject {
  func show(over viewController: UIViewController) async -> UIImage?
}

@available(iOS 14, *)
final class PHImagePicker: NSObject, ImagePicker, PHPickerViewControllerDelegate,
  UIAdaptivePresentationControllerDelegate
{
  private var continuation: CheckedContinuation<UIImage?, Never>?

  func show(over viewController: UIViewController) async -> UIImage? {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    picker.presentationController?.delegate = self

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      viewController.present(picker, animated: true)
    }
  }

  private func finish(with image: UIImage?) {
    continuation?.resume(returning: image)
    continuation = nil
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finish(with: nil)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)

    guard let itemProvider = results.first?.itemProvider,
      itemProvider.canLoadObject(ofClass: UIImage.self)
    else {
      finish(with: nil)
      return
    }

    itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
      DispatchQueue.main.async {
        if let error = error {
          print("fast_barcode_scanner: Error loading picked image: \(error)")
          self?.finish(with: nil)
          return
        }
        self?.finish(with: object as? UIImage)
      }
    }
  }
}

final class UIImagePicker: NSObject, ImagePicker, UIImagePickerControllerDelegate,
  UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate
{
  private var continuation: CheckedContinuation<UIImage?, Never>?

  func show(over viewController: UIViewController) async -> UIImage? {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.presentationController?.delegate = self

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      viewController.present(picker, animated: true)
    }
  }

  private func finish(with image: UIImage?) {
    continuation?.resume(returning: image)
    continuation = nil
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finish(with: nil)
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)
    finish(with: info[.originalImage] as? UIImage)
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    finish(with: nil)
  }
}
