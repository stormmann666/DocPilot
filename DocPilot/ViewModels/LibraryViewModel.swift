//
//  LibraryViewModel.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var filter: Filter = .all
    @Published private(set) var entries: [DocumentEntry] = []
    @Published var editingEntry: DocumentEntry?
    @Published var draftTitle = ""
    @Published var searchQuery = ""

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case photos = "Photos"
        case links = "Links"
        case text = "Text"
        case today = "Hoy"
        case week = "Semana"

        var id: String { rawValue }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let store: DocumentStore
    private var cancellables = Set<AnyCancellable>()

    init(store: DocumentStore) {
        self.store = store
        bind()
    }

    func entryLabel(for entry: DocumentEntry) -> String {
        entry.displayLabel
    }

    func formattedDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    func beginEditingTitle(for entry: DocumentEntry) {
        editingEntry = entry
        draftTitle = entry.title ?? ""
    }

    func cancelEditingTitle() {
        editingEntry = nil
        draftTitle = ""
    }

    func saveEditingTitle() {
        guard let entry = editingEntry else {
            return
        }
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = trimmed.isEmpty ? nil : trimmed
        store.updateEntryTitle(id: entry.id, title: newTitle)
        editingEntry = nil
        draftTitle = ""
    }

    func isEditingTitlePresented() -> Bool {
        editingEntry != nil
    }

    func isEmptyState(_ entries: [DocumentEntry]) -> Bool {
        entries.isEmpty
    }

    private func filteredEntries(_ entries: [DocumentEntry], filter: Filter) -> [DocumentEntry] {
        switch filter {
        case .all:
            return entries
        case .photos:
            return entries.filter { !$0.imageFilenames.isEmpty && $0.linkURL == nil }
        case .links:
            return entries.filter { $0.linkURL != nil }
        case .text:
            return entries.filter {
                ($0.text?.isEmpty == false) &&
                    $0.imageFilenames.isEmpty &&
                    $0.fileFilename == nil &&
                    $0.linkURL == nil &&
                    $0.pdfs.isEmpty
            }
        case .today:
            let interval = Calendar.current.dateInterval(of: .day, for: Date())
            return entries.filter { entry in
                guard let interval else { return false }
                return interval.contains(entry.createdAt)
            }
        case .week:
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            return entries.filter { entry in
                guard let interval else { return false }
                return interval.contains(entry.createdAt)
            }
        }
    }

    func fileURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }

    func loadImage(for filename: String) -> PlatformImage? {
        guard let url = fileURL(for: filename) else {
            return nil
        }
        return loadImage(from: url)
    }

    func copyText(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }

    func copyImage(_ image: PlatformImage) {
#if canImport(UIKit)
        UIPasteboard.general.image = image
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
#endif
    }

    private func loadImage(from url: URL) -> PlatformImage? {
#if canImport(UIKit)
        UIImage(contentsOfFile: url.path)
#elseif canImport(AppKit)
        NSImage(contentsOf: url)
#endif
    }

    private func bind() {
        Publishers.CombineLatest3(store.$entries, $filter, $searchQuery)
            .map { [weak self] entries, filter, query in
                guard let self else { return [] }
                let filtered = self.filteredEntries(entries, filter: filter)
                return self.store.searchEntries(in: filtered, query: query)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$entries)
    }

    func refresh() {
        store.load()
    }

#if canImport(UIKit)
    func addPDFToEntryFromClipboard(_ entry: DocumentEntry, completion: @escaping (Result<Void, Error>) -> Void) {
        let useCase = DocumentUseCase(store: store)
        useCase.addPDFToEntryFromClipboard(entryId: entry.id, completion: completion)
    }

    func addPDFToEntryFromFile(_ entry: DocumentEntry, fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let useCase = DocumentUseCase(store: store)
        useCase.addPDFToEntryFromFile(entryId: entry.id, fileURL: fileURL, completion: completion)
    }

    func addImagesToEntry(_ entry: DocumentEntry, images: [UIImage], completion: @escaping (Result<Void, Error>) -> Void) {
        let useCase = DocumentUseCase(store: store)
        useCase.addImagesToEntry(entry.id, images: images, completion: completion)
    }
#endif

}
