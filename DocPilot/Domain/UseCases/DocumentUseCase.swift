//
//  DocumentUseCase.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
import LinkPresentation
#endif

struct DocumentUseCaseResult {
    let title: String?
    let text: String
    let entryId: UUID?
}

final class DocumentUseCase {
    private let store: DocumentStore
    private let processor: DocumentProcessor

    init(store: DocumentStore, processor: DocumentProcessor = DocumentProcessor()) {
        self.store = store
        self.processor = processor
    }

#if canImport(UIKit)
    func handleCameraImage(_ image: UIImage, completion: @escaping (Result<DocumentUseCaseResult, Error>) -> Void) {
        processor.processImages([image]) { result in
            self.savePayload(result, completion: completion)
        }
    }

    func handleClipboard(completion: @escaping (Result<DocumentUseCaseResult, Error>) -> Void) {
        DebugLogger.log("[DocumentUseCase] handleClipboard")
        processor.processClipboard { result in
            self.savePayload(result, completion: completion)
        }
    }

    func addPDFToEntryFromClipboard(entryId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        processor.processClipboardPDF { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let payload):
                let saved = self.store.saveFile(from: payload.url, prefix: "pdf")
                guard let filename = saved else {
                    completion(.failure(DocumentProcessingError.noClipboardContent))
                    return
                }
                _ = self.performStoreUpdate {
                    self.store.appendPDF(to: entryId, filename: filename, ocrText: payload.text)
                    return .success(DocumentUseCaseResult(title: nil, text: payload.text, entryId: entryId))
                }
                completion(.success(()))
            }
        }
    }

    func addPDFToEntryFromFile(entryId: UUID, fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        processor.processPDFFile(at: fileURL) { text in
            let saved = self.store.saveFile(from: fileURL, prefix: "pdf")
            guard let filename = saved else {
                completion(.failure(DocumentProcessingError.noClipboardContent))
                return
            }
            _ = self.performStoreUpdate {
                self.store.appendPDF(to: entryId, filename: filename, ocrText: text)
                return .success(DocumentUseCaseResult(title: nil, text: text, entryId: entryId))
            }
            completion(.success(()))
        }
    }

    func addImagesToEntry(_ entryId: UUID, images: [UIImage], completion: @escaping (Result<String, Error>) -> Void) {
        processor.processImages(images) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let payload):
                let filenames = self.store.saveImages(payload.images, prefix: "scan")
                let text = payload.text ?? ""
                _ = self.performStoreUpdate {
                    self.store.appendImages(to: entryId, filenames: filenames, ocrText: text)
                    return .success(DocumentUseCaseResult(title: nil, text: text, entryId: entryId))
                }
                completion(.success(text))
            }
        }
    }

    private func savePayload(_ result: Result<DocumentProcessingPayload, Error>, completion: @escaping (Result<DocumentUseCaseResult, Error>) -> Void) {
        switch result {
        case .failure(let error):
            DebugLogger.log("[DocumentUseCase] savePayload failure: \(error.localizedDescription)")
            completion(.failure(error))
        case .success(let payload):
            DebugLogger.log("[DocumentUseCase] savePayload success link=\(payload.linkURL != nil) file=\(payload.fileURL != nil) images=\(payload.images.count)")
            if let linkURL = payload.linkURL {
                saveLinkPayload(payload, linkURL: linkURL, completion: completion)
                return
            }
            if let fileURL = payload.fileURL {
                let result = performStoreUpdate {
                    if let saved = store.saveFile(from: fileURL, prefix: "pdf") {
                        let title = payload.title ?? fileURL.lastPathComponent
                        let pdfText = payload.text ?? ""
                        let pdf = DocumentPDF(filename: saved, ocrText: pdfText)
                        let entryId = store.addEntry(title: title, text: nil, imageFilenames: [], fileFilename: nil, linkURL: nil, pdfs: [pdf])
                        return .success(DocumentUseCaseResult(title: title, text: pdfText, entryId: entryId))
                    }
                    return .failure(DocumentProcessingError.noClipboardContent)
                }
                completion(result)
                return
            }

            if !payload.images.isEmpty {
                let result = performStoreUpdate {
                    let filenames = store.saveImages(payload.images, prefix: "scan")
                    let text = payload.text ?? ""
                    let entryId = store.addEntry(title: payload.title, text: text, imageFilenames: filenames, fileFilename: nil, linkURL: nil)
                    return .success(DocumentUseCaseResult(title: payload.title, text: text, entryId: entryId))
                }
                completion(result)
                return
            }

            let result = performStoreUpdate {
                let text = payload.text ?? ""
                let entryId = store.addEntry(title: payload.title, text: text, imageFilenames: [], fileFilename: nil, linkURL: nil)
                return .success(DocumentUseCaseResult(title: payload.title, text: text, entryId: entryId))
            }
            completion(result)
        }
    }

    private func performStoreUpdate(_ work: () -> Result<DocumentUseCaseResult, Error>) -> Result<DocumentUseCaseResult, Error> {
        if Thread.isMainThread {
            return work()
        }
        return DispatchQueue.main.sync {
            work()
        }
    }

    private func saveLinkPayload(_ payload: DocumentProcessingPayload, linkURL: URL, completion: @escaping (Result<DocumentUseCaseResult, Error>) -> Void) {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: linkURL) { metadata, _ in
            let title = metadata?.title ?? payload.title ?? linkURL.host ?? linkURL.absoluteString
            let text = payload.text ?? linkURL.absoluteString

            guard let imageProvider = metadata?.imageProvider else {
                let result = self.performStoreUpdate {
                    let entryId = self.store.addEntry(title: title, text: text, imageFilenames: [], fileFilename: nil, linkURL: linkURL.absoluteString)
                    return .success(DocumentUseCaseResult(title: title, text: text, entryId: entryId))
                }
                completion(result)
                return
            }

            imageProvider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                let result = self.performStoreUpdate {
                    let filenames = image.map { self.store.saveImages([$0], prefix: "link") } ?? []
                    let entryId = self.store.addEntry(title: title, text: text, imageFilenames: filenames, fileFilename: nil, linkURL: linkURL.absoluteString)
                    return .success(DocumentUseCaseResult(title: title, text: text, entryId: entryId))
                }
                completion(result)
            }
        }
    }
#endif
}
