//
//  ContentView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @State private var isShowingCamera = false

    init(store: DocumentStore) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("OCR de documentos")
                    .font(.title2)

#if canImport(UIKit)
                Button("Capturar foto y OCR") {
                    isShowingCamera = true
                }
                .buttonStyle(.borderedProminent)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
#endif

                if viewModel.isProcessing {
                    ProgressView("Reconociendo texto...")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button("Copy clipboard") {
                        viewModel.processClipboard()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                    if let title = viewModel.recognizedTitle {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $viewModel.recognizedText)
                        .frame(minHeight: 380)
                        .border(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
        .padding()
#if canImport(UIKit)
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { result in
                switch result {
                case .success(let image):
                    viewModel.processCameraImage(image)
                case .failure:
                    viewModel.errorMessage = "No se pudo obtener la imagen."
                }
            }
        }
#endif
    }

}

#Preview {
    ContentView(store: DocumentStore())
}

#if canImport(UIKit)
struct CameraPicker: UIViewControllerRepresentable {
    var completion: (Result<UIImage, Error>) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let completion: (Result<UIImage, Error>) -> Void

        init(completion: @escaping (Result<UIImage, Error>) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                completion(.success(image))
            } else {
                completion(.failure(NSError(domain: "CameraPicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener la imagen."])))
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
