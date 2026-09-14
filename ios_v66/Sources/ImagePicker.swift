import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var c = PHPickerConfiguration(photoLibrary: .shared())
        c.filter = .images
        c.selectionLimit = 1
        let vc = PHPickerViewController(configuration: c)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
            item.loadObject(ofClass: UIImage.self) { obj, _ in
                guard let image = obj as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onImage(image) }
            }
        }
    }
}
