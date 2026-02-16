//
//  DocumentDetailViewModel.swift
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
final class DocumentDetailViewModel: ObservableObject {
    @Published var isShowingCamera = false
    @Published var isShowingFilePicker = false
    @Published var errorMessage: String?

    private let entryId: UUID
    private let store: DocumentStore
    private let useCase: DocumentUseCase
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(entryId: UUID, store: DocumentStore) {
        self.entryId = entryId
        self.store = store
        self.useCase = DocumentUseCase(store: store)
    }

    var entry: DocumentEntry? {
        store.entries.first(where: { $0.id == entryId })
    }

    var navigationTitle: String {
        if let entry, let title = entry.title, !title.isEmpty {
            return title
        }
        if let entry {
            return dateFormatter.string(from: entry.createdAt)
        }
        return "Documento"
    }

    func startAddPDFfromClipboard() {
        useCase.addPDFToEntryFromClipboard(entryId: entryId) { [weak self] result in
            if case .failure(let error) = result {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func startAddPDFfromFile(url: URL) {
        useCase.addPDFToEntryFromFile(entryId: entryId, fileURL: url) { [weak self] result in
            if case .failure(let error) = result {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

#if canImport(UIKit)
    func startAddImages(_ images: [UIImage]) {
        useCase.addImagesToEntry(entryId, images: images) { [weak self] result in
            if case .failure(let error) = result {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
#endif

    func deleteEntry() {
        guard let entry else { return }
        store.deleteEntry(entry)
    }
}
