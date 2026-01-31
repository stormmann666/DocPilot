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
        processor.processClipboard { result in
            self.savePayload(result, completion: completion)
        }
    }

    private func savePayload(_ result: Result<DocumentProcessingPayload, Error>, completion: @escaping (Result<DocumentUseCaseResult, Error>) -> Void) {
        switch result {
        case .failure(let error):
            completion(.failure(error))
        case .success(let payload):
            if let linkURL = payload.linkURL {
                saveLinkPayload(payload, linkURL: linkURL, completion: completion)
                return
            }
            if let fileURL = payload.fileURL {
                let result = performStoreUpdate {
                    if let saved = store.saveFile(from: fileURL, prefix: "pdf") {
                        let title = payload.title ?? fileURL.lastPathComponent
                        store.addEntry(title: title, text: payload.text ?? "", imageFilenames: [], fileFilename: saved, linkURL: nil)
                        return .success(DocumentUseCaseResult(title: title, text: payload.text ?? ""))
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
                    store.addEntry(title: payload.title, text: text, imageFilenames: filenames, fileFilename: nil, linkURL: nil)
                    return .success(DocumentUseCaseResult(title: payload.title, text: text))
                }
                completion(result)
                return
            }

            let result = performStoreUpdate {
                let text = payload.text ?? ""
                store.addEntry(title: payload.title, text: text, imageFilenames: [], fileFilename: nil, linkURL: nil)
                return .success(DocumentUseCaseResult(title: payload.title, text: text))
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
                    self.store.addEntry(title: title, text: text, imageFilenames: [], fileFilename: nil, linkURL: linkURL.absoluteString)
                    return .success(DocumentUseCaseResult(title: title, text: text))
                }
                completion(result)
                return
            }

            imageProvider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                let result = self.performStoreUpdate {
                    let filenames = image.map { self.store.saveImages([$0], prefix: "link") } ?? []
                    self.store.addEntry(title: title, text: text, imageFilenames: filenames, fileFilename: nil, linkURL: linkURL.absoluteString)
                    return .success(DocumentUseCaseResult(title: title, text: text))
                }
                completion(result)
            }
        }
    }
#endif
}
