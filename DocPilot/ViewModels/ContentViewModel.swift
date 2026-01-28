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
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
