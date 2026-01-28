//
//  DocumentStore.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct DocumentEntry: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let text: String?
    let imageFilenames: [String]
}

final class DocumentStore: ObservableObject {
    @Published private(set) var entries: [DocumentEntry] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        fileURL = (documentsURL ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("documents.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    func addEntry(text: String?, imageFilenames: [String]) {
        let entry = DocumentEntry(id: UUID(), createdAt: Date(), text: text, imageFilenames: imageFilenames)
        entries.insert(entry, at: 0)
        save()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([DocumentEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    func save() {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }

#if canImport(UIKit)
    func saveImages(_ images: [UIImage], prefix: String) -> [String] {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        var filenames: [String] = []
        let timestamp = Int(Date().timeIntervalSince1970)

        for (index, image) in images.enumerated() {
            let filename = "\(prefix)_\(timestamp)_\(index).jpg"
            let url = documentsURL.appendingPathComponent(filename)
            if let data = image.jpegData(compressionQuality: 0.9) {
                do {
                    try data.write(to: url, options: [.atomic])
                    filenames.append(filename)
                } catch {
                    continue
                }
            }
        }

        return filenames
    }
#endif
}
