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
    @Published var recognizedTitle: String?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var isResultPresented = false
    @Published var currentEntryId: UUID?

    private let useCase: DocumentUseCase

    init(store: DocumentStore) {
        self.useCase = DocumentUseCase(store: store)
    }

#if canImport(UIKit)
    func processCameraImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        recognizedText = ""
        recognizedTitle = nil
        isResultPresented = false
        currentEntryId = nil

        useCase.handleCameraImage(image) { [weak self] result in
            DispatchQueue.main.async {
                self?.handle(result: result)
            }
        }
    }

    func processClipboard() {
        isProcessing = true
        errorMessage = nil
        recognizedTitle = nil
        isResultPresented = false
        currentEntryId = nil

        useCase.handleClipboard { [weak self] result in
            DispatchQueue.main.async {
                self?.handle(result: result)
            }
        }
    }
#endif

    private func handle(result: Result<DocumentUseCaseResult, Error>) {
        isProcessing = false
        switch result {
        case .success(let result):
            recognizedText = result.text
            recognizedTitle = result.title
            isResultPresented = true
            currentEntryId = result.entryId
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func appendCameraImage(_ image: UIImage) {
        guard let entryId = currentEntryId else {
            processCameraImage(image)
            return
        }
        isProcessing = true
        errorMessage = nil

        useCase.addImagesToEntry(entryId, images: [image]) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                switch result {
                case .success(let text):
                    if !text.isEmpty {
                        if !(self?.recognizedText.isEmpty ?? true) {
                            self?.recognizedText.append("\n\n")
                        }
                        self?.recognizedText.append(text)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearResult() {
        recognizedText = ""
        recognizedTitle = nil
        isResultPresented = false
        currentEntryId = nil
    }
}
