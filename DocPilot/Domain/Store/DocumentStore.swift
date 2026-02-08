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
    let title: String?
    let text: String?
    let imageFilenames: [String]
    let fileFilename: String?
    let linkURL: String?
    let pdfs: [DocumentPDF]

    init(
        id: UUID,
        createdAt: Date,
        title: String?,
        text: String?,
        imageFilenames: [String],
        fileFilename: String?,
        linkURL: String?,
        pdfs: [DocumentPDF] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.text = text
        self.imageFilenames = imageFilenames
        self.fileFilename = fileFilename
        self.linkURL = linkURL
        self.pdfs = pdfs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case title
        case text
        case imageFilenames
        case fileFilename
        case linkURL
        case pdfs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageFilenames = try container.decodeIfPresent([String].self, forKey: .imageFilenames) ?? []
        fileFilename = try container.decodeIfPresent(String.self, forKey: .fileFilename)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        pdfs = try container.decodeIfPresent([DocumentPDF].self, forKey: .pdfs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encode(imageFilenames, forKey: .imageFilenames)
        try container.encodeIfPresent(fileFilename, forKey: .fileFilename)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
        try container.encode(pdfs, forKey: .pdfs)
    }
}

struct DocumentPDF: Identifiable, Codable {
    let id: UUID
    let filename: String
    let ocrText: String

    init(filename: String, ocrText: String) {
        self.id = UUID()
        self.filename = filename
        self.ocrText = ocrText
    }
}

extension DocumentEntry {
    var displayLabel: String {
        if linkURL != nil {
            return "Link"
        }
        if fileFilename != nil || !pdfs.isEmpty {
            return "PDF"
        }
        if let text, !text.isEmpty, !imageFilenames.isEmpty {
            return "OCR + Fotos"
        }
        if let text, !text.isEmpty {
            return "OCR"
        }
        return "Fotos"
    }
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

    @discardableResult
    func addEntry(title: String? = nil, text: String?, imageFilenames: [String], fileFilename: String? = nil, linkURL: String? = nil, pdfs: [DocumentPDF] = []) -> UUID {
        DebugLogger.log("[DocumentStore] addEntry title=\(title ?? "nil") images=\(imageFilenames.count) file=\(fileFilename != nil) link=\(linkURL != nil)")
        let entryId = UUID()
        let entry = DocumentEntry(
            id: entryId,
            createdAt: Date(),
            title: title,
            text: text,
            imageFilenames: imageFilenames,
            fileFilename: fileFilename,
            linkURL: linkURL,
            pdfs: pdfs
        )
        entries.insert(entry, at: 0)
        save()
        return entryId
    }

    func deleteEntry(_ entry: DocumentEntry) {
        for filename in entry.imageFilenames {
            deleteImage(named: filename)
        }
        if let fileFilename = entry.fileFilename {
            deleteFile(named: fileFilename)
        }
        for pdf in entry.pdfs {
            deleteFile(named: pdf.filename)
        }
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { entries[$0] }
        for entry in entriesToDelete {
            deleteEntry(entry)
        }
    }

    func updateEntryTitle(id: UUID, title: String?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        let entry = entries[index]
        let updated = DocumentEntry(
            id: entry.id,
            createdAt: entry.createdAt,
            title: title,
            text: entry.text,
            imageFilenames: entry.imageFilenames,
            fileFilename: entry.fileFilename,
            linkURL: entry.linkURL,
            pdfs: entry.pdfs
        )
        entries[index] = updated
        save()
    }

    func appendPDF(to entryId: UUID, filename: String, ocrText: String) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else {
            return
        }
        let entry = entries[index]
        let updatedPDFs = entry.pdfs + [DocumentPDF(filename: filename, ocrText: ocrText)]
        let updated = DocumentEntry(
            id: entry.id,
            createdAt: entry.createdAt,
            title: entry.title,
            text: entry.text,
            imageFilenames: entry.imageFilenames,
            fileFilename: entry.fileFilename,
            linkURL: entry.linkURL,
            pdfs: updatedPDFs
        )
        entries[index] = updated
        save()
    }

    func appendImages(to entryId: UUID, filenames: [String], ocrText: String) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else {
            return
        }
        let entry = entries[index]
        let updatedImages = entry.imageFilenames + filenames
        let updatedText: String?
        if let existing = entry.text, !existing.isEmpty {
            if ocrText.isEmpty {
                updatedText = existing
            } else {
                updatedText = existing + "\n\n" + ocrText
            }
        } else {
            updatedText = ocrText.isEmpty ? entry.text : ocrText
        }
        let updated = DocumentEntry(
            id: entry.id,
            createdAt: entry.createdAt,
            title: entry.title,
            text: updatedText,
            imageFilenames: updatedImages,
            fileFilename: entry.fileFilename,
            linkURL: entry.linkURL,
            pdfs: entry.pdfs
        )
        entries[index] = updated
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

    func saveFile(from url: URL, prefix: String) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(prefix)_\(timestamp)_\(url.lastPathComponent)"
        let destination = documentsURL.appendingPathComponent(filename)

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            return filename
        } catch {
            return nil
        }
    }

    private func deleteImage(named filename: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = documentsURL.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }

    private func deleteFile(named filename: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = documentsURL.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
}

extension DocumentStore {
    func searchEntries(in entries: [DocumentEntry], query: String) -> [DocumentEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return entries
        }
        return entries.filter { entry in
            if let title = entry.title, !title.isEmpty, matches(query: trimmed, in: title) {
                return true
            }
            if entry.pdfs.contains(where: { matches(query: trimmed, in: $0.ocrText) }) {
                return true
            }
            guard let text = entry.text, !text.isEmpty else {
                return false
            }
            return matches(query: trimmed, in: text)
        }
    }

    private func matches(query: String, in text: String) -> Bool {
        let normalizedQuery = normalize(query)
        let words = extractWords(from: text)
        for word in words {
            let similarity = similarityScore(normalizedQuery, normalize(word))
            if similarity >= 0.7 {
                return true
            }
        }
        return false
    }

    private func extractWords(from text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func normalize(_ value: String) -> String {
        value.lowercased()
    }

    private func similarityScore(_ a: String, _ b: String) -> Double {
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1 }
        let distance = levenshteinDistance(a, b)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var distances = Array(0...bChars.count)

        for (i, aChar) in aChars.enumerated() {
            var previous = distances[0]
            distances[0] = i + 1
            for (j, bChar) in bChars.enumerated() {
                let old = distances[j + 1]
                let cost = aChar == bChar ? 0 : 1
                distances[j + 1] = min(
                    distances[j + 1] + 1,
                    min(distances[j] + 1, previous + cost)
                )
                previous = old
            }
        }
        return distances[bChars.count]
    }
}
