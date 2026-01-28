//
//  ContentViewModel.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let store: DocumentStore
    private let processor: DocumentProcessor

    init(store: DocumentStore, processor: DocumentProcessor = DocumentProcessor()) {
        self.store = store
        self.processor = processor
    }

#if canImport(UIKit)
    func processCameraImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        recognizedText = ""

        processor.processImages([image], store: store) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle(result: result)
            }
        }
    }

    func processClipboard() {
        isProcessing = true
        errorMessage = nil

        processor.processClipboard(store: store) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle(result: result)
            }
        }
    }
#endif

    private func handle(result: Result<DocumentProcessingResult, Error>) {
        isProcessing = false
        switch result {
        case .success(let result):
            recognizedText = result.text
            store.addEntry(text: result.text, imageFilenames: result.imageFilenames)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
