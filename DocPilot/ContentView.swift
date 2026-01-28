//
//  ContentView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI
import Vision
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VisionKit)
import VisionKit
#endif

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var recognizedText = ""
    @State private var isShowingScanner = false
    @State private var isShowingCamera = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("OCR de documentos")
                .font(.title2)

#if canImport(VisionKit)
            Button("Escanear documento") {
                isShowingScanner = true
            }
            .buttonStyle(.borderedProminent)
#else
            Text("Escaner no disponible en esta plataforma.")
#endif

#if canImport(UIKit)
            Button("Capturar foto y OCR") {
                isShowingCamera = true
            }
            .buttonStyle(.bordered)
#endif

            if isProcessing {
                ProgressView("Reconociendo texto...")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            TextEditor(text: $recognizedText)
                .frame(minHeight: 300)
                .border(.gray.opacity(0.4))
        }
        .padding()
#if canImport(VisionKit)
        .sheet(isPresented: $isShowingScanner) {
            DocumentScannerView { result in
                switch result {
                case .success(let images):
                    recognizeText(from: images)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
#endif
#if canImport(UIKit)
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { result in
                switch result {
                case .success(let image):
                    recognizeText(from: [image])
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
#endif
    }

#if canImport(UIKit)
    private func recognizeText(from images: [UIImage]) {
        isProcessing = true
        errorMessage = nil
        recognizedText = ""

        DispatchQueue.global(qos: .userInitiated).async {
            var fullText: [String] = []

            for image in images {
                guard let cgImage = image.cgImage else { continue }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["es-ES", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    if !lines.isEmpty {
                        fullText.append(lines.joined(separator: "\n"))
                    }
                } catch {
                    fullText.append("[Error OCR: \(error.localizedDescription)]")
                }
            }

            let combinedText = fullText.joined(separator: "\n\n")
            let filenames = store.saveImages(images, prefix: "scan")

            DispatchQueue.main.async {
                recognizedText = combinedText
                isProcessing = false
                store.addEntry(text: combinedText, imageFilenames: filenames)
            }
        }
    }

#endif
}

#Preview {
    ContentView()
        .environmentObject(DocumentStore())
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

#if canImport(VisionKit)
struct DocumentScannerView: UIViewControllerRepresentable {
    var completion: (Result<[UIImage], Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let completion: (Result<[UIImage], Error>) -> Void

        init(completion: @escaping (Result<[UIImage], Error>) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            controller.dismiss(animated: true)
            completion(.success(images))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            completion(.failure(error))
        }
    }
}
#endif
