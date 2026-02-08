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
import PDFKit
#endif

struct DocumentProcessingPayload {
    let title: String?
    let text: String?
    let images: [UIImage]
    let fileURL: URL?
    let linkURL: URL?
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
    func processImages(_ images: [UIImage], completion: @escaping (Result<DocumentProcessingPayload, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let combinedText = self.recognizeText(in: images)
            completion(.success(DocumentProcessingPayload(title: nil, text: combinedText, images: images, fileURL: nil, linkURL: nil)))
        }
    }

    func processClipboard(completion: @escaping (Result<DocumentProcessingPayload, Error>) -> Void) {
        loadTextFromPasteboard { text, title in
            if let text, !text.isEmpty {
                if let url = self.linkURL(from: text) {
                    completion(.success(DocumentProcessingPayload(title: title, text: text, images: [], fileURL: nil, linkURL: url)))
                } else {
                    completion(.success(DocumentProcessingPayload(title: title, text: text, images: [], fileURL: nil, linkURL: nil)))
                }
                return
            }

            self.loadPDFFileFromPasteboard { pdfURL in
                if let pdfURL {
                    self.processPDF(at: pdfURL) { text in
                        let title = pdfURL.lastPathComponent
                        completion(.success(DocumentProcessingPayload(title: title, text: text, images: [], fileURL: pdfURL, linkURL: nil)))
                        return
                    }
                }

                self.loadImageFromPasteboard { image in
                    if let image {
                        self.processImages([image], completion: completion)
                    } else if let text = UIPasteboard.general.string, !text.isEmpty {
                        if let url = self.linkURL(from: text) {
                            completion(.success(DocumentProcessingPayload(title: nil, text: text, images: [], fileURL: nil, linkURL: url)))
                        } else {
                            completion(.success(DocumentProcessingPayload(title: nil, text: text, images: [], fileURL: nil, linkURL: nil)))
                        }
                    } else {
                        completion(.failure(DocumentProcessingError.noClipboardContent))
                    }
                }
            }
        }
    }

    func processClipboardPDF(completion: @escaping (Result<(url: URL, text: String), Error>) -> Void) {
        loadPDFFileFromPasteboard { pdfURL in
            guard let pdfURL else {
                completion(.failure(DocumentProcessingError.noClipboardContent))
                return
            }
            self.processPDF(at: pdfURL) { text in
                completion(.success((url: pdfURL, text: text)))
            }
        }
    }

    private func loadTextFromPasteboard(completion: @escaping (String?, String?) -> Void) {
        let providers = UIPasteboard.general.itemProviders
        guard !providers.isEmpty else {
            completion(nil, nil)
            return
        }

        func load(from index: Int) {
            if index >= providers.count {
                completion(nil, nil)
                return
            }

            let provider = providers[index]
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                    if let data, let text = String(data: data, encoding: .utf8) {
                        completion(text, nil)
                    } else {
                        load(from: index + 1)
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.rtf.identifier) { data, _ in
                    if let data,
                       let attributed = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
                        completion(attributed.string, nil)
                    } else {
                        load(from: index + 1)
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
                    if let data, let text = String(data: data, encoding: .utf8) {
                        completion(text, nil)
                    } else {
                        load(from: index + 1)
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString),
                       let result = self.readTextFile(from: url) {
                        completion(result.text, result.title)
                    } else if let url = item as? URL, let result = self.readTextFile(from: url) {
                        completion(result.text, result.title)
                    } else {
                        load(from: index + 1)
                    }
                }
                return
            }

            load(from: index + 1)
        }

        load(from: 0)
    }

    private func linkURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = detector?.firstMatch(in: trimmed, options: [], range: range),
              let url = match.url else {
            return nil
        }
        if match.range.length == range.length {
            return url
        }
        return nil
    }

    private func readTextFile(from url: URL) -> (text: String, title: String)? {
        let allowedExtensions = ["txt", "md", "rtf"]
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "rtf" {
                let attributed = try NSAttributedString(data: data, options: [:], documentAttributes: nil)
                return (attributed.string, url.lastPathComponent)
            }
            if let text = String(data: data, encoding: .utf8) {
                return (text, url.lastPathComponent)
            }
            return nil
        } catch {
            return nil
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

    private func loadPDFFileFromPasteboard(completion: @escaping (URL?) -> Void) {
        let providers = UIPasteboard.general.itemProviders
        guard !providers.isEmpty else {
            completion(nil)
            return
        }

        func load(from index: Int) {
            if index >= providers.count {
                completion(nil)
                return
            }

            let provider = providers[index]
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, _ in
                    if let url {
                        completion(url)
                    } else {
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, _ in
                            if let data {
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
                                if (try? data.write(to: tempURL, options: [.atomic])) != nil {
                                    completion(tempURL)
                                } else {
                                    load(from: index + 1)
                                }
                            } else {
                                load(from: index + 1)
                            }
                        }
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString),
                       url.pathExtension.lowercased() == "pdf" {
                        completion(url)
                    } else if let url = item as? URL, url.pathExtension.lowercased() == "pdf" {
                        completion(url)
                    } else {
                        load(from: index + 1)
                    }
                }
                return
            }

            load(from: index + 1)
        }

        load(from: 0)
    }

    private func processPDF(at url: URL, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(url: url) else {
                completion("")
                return
            }

            var images: [UIImage] = []
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let targetSize = CGSize(width: 1200, height: 1600)
                let image = page.thumbnail(of: targetSize, for: .mediaBox)
                images.append(image)
            }

            let ocrText = self.recognizeText(in: images)
            if ocrText.isEmpty, let embedded = document.string {
                completion(embedded)
            } else {
                completion(ocrText)
            }
        }
    }

    private func recognizeText(in images: [UIImage]) -> String {
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

        return fullText.joined(separator: "\n\n")
    }
#else
    func processImages(_ images: [Any], completion: @escaping (Result<DocumentProcessingPayload, Error>) -> Void) {
        completion(.failure(DocumentProcessingError.unsupportedPlatform))
    }

    func processClipboard(completion: @escaping (Result<DocumentProcessingPayload, Error>) -> Void) {
        completion(.failure(DocumentProcessingError.unsupportedPlatform))
    }

    func processClipboardPDF(completion: @escaping (Result<(url: URL, text: String), Error>) -> Void) {
        completion(.failure(DocumentProcessingError.unsupportedPlatform))
    }
#endif
}
