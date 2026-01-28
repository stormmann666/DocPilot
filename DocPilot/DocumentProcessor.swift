//
//  DocumentProcessor.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
import Vision
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

struct DocumentProcessingResult {
    let text: String
    let imageFilenames: [String]
}

enum DocumentProcessingError: LocalizedError {
    case noClipboardContent
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .noClipboardContent:
            return "No hay texto ni imagen en el portapapeles."
        case .unsupportedPlatform:
            return "Esta funcion no esta disponible en esta plataforma."
        }
    }
}

final class DocumentProcessor {
#if canImport(UIKit)
    func processImages(_ images: [UIImage], store: DocumentStore, completion: @escaping (Result<DocumentProcessingResult, Error>) -> Void) {
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
            completion(.success(DocumentProcessingResult(text: combinedText, imageFilenames: filenames)))
        }
    }

    func processClipboard(store: DocumentStore, completion: @escaping (Result<DocumentProcessingResult, Error>) -> Void) {
        loadImageFromPasteboard { image in
            if let image {
                self.processImages([image], store: store, completion: completion)
            } else if let text = UIPasteboard.general.string, !text.isEmpty {
                completion(.success(DocumentProcessingResult(text: text, imageFilenames: [])))
            } else {
                completion(.failure(DocumentProcessingError.noClipboardContent))
            }
        }
    }

    private func loadImageFromPasteboard(completion: @escaping (UIImage?) -> Void) {
        let providers = UIPasteboard.general.itemProviders
        guard !providers.isEmpty else {
            completion(UIPasteboard.general.image)
            return
        }

        func load(from index: Int) {
            if index >= providers.count {
                completion(UIPasteboard.general.image)
                return
            }

            let provider = providers[index]
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        completion(image)
                    } else {
                        load(from: index + 1)
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data, let image = UIImage(data: data) {
                        completion(image)
                    } else {
                        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                            if let url, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                                completion(image)
                            } else {
                                load(from: index + 1)
                            }
                        }
                    }
                }
                return
            }

            load(from: index + 1)
        }

        load(from: 0)
    }
#else
    func processImages(_ images: [Any], store: DocumentStore, completion: @escaping (Result<DocumentProcessingResult, Error>) -> Void) {
        completion(.failure(DocumentProcessingError.unsupportedPlatform))
    }

    func processClipboard(store: DocumentStore, completion: @escaping (Result<DocumentProcessingResult, Error>) -> Void) {
        completion(.failure(DocumentProcessingError.unsupportedPlatform))
    }
#endif
}
