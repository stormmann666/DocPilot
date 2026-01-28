//
//  DocumentUseCase.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
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
            completion(self.savePayload(result))
        }
    }

    func handleClipboard(completion: @escaping (Result<DocumentUseCaseResult, Error>) -> Void) {
        processor.processClipboard { result in
            completion(self.savePayload(result))
        }
    }

    private func savePayload(_ result: Result<DocumentProcessingPayload, Error>) -> Result<DocumentUseCaseResult, Error> {
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let payload):
            if let fileURL = payload.fileURL {
                return performStoreUpdate {
                    if let saved = store.saveFile(from: fileURL, prefix: "pdf") {
                        let title = payload.title ?? fileURL.lastPathComponent
                        store.addEntry(title: title, text: payload.text ?? "", imageFilenames: [], fileFilename: saved)
                        return .success(DocumentUseCaseResult(title: title, text: payload.text ?? ""))
                    }
                    return .failure(DocumentProcessingError.noClipboardContent)
                }
            }

            if !payload.images.isEmpty {
                return performStoreUpdate {
                    let filenames = store.saveImages(payload.images, prefix: "scan")
                    let text = payload.text ?? ""
                    store.addEntry(title: payload.title, text: text, imageFilenames: filenames, fileFilename: nil)
                    return .success(DocumentUseCaseResult(title: payload.title, text: text))
                }
            }

            return performStoreUpdate {
                let text = payload.text ?? ""
                store.addEntry(title: payload.title, text: text, imageFilenames: [], fileFilename: nil)
                return .success(DocumentUseCaseResult(title: payload.title, text: text))
            }
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
#endif
}
