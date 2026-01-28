//
//  LibraryView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        NavigationStack {
            List {
                if store.entries.isEmpty {
                    Text("No hay documentos guardados.")
                        .foregroundStyle(.secondary)
                }

                ForEach(store.entries) { entry in
                    NavigationLink {
                        DocumentDetailView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(formatter.string(from: entry.createdAt))
                                    .font(.subheadline)
                                Spacer()
                                Text(entryLabel(for: entry))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !entry.imageFilenames.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(entry.imageFilenames, id: \.self) { filename in
                                            thumbnailView(for: filename)
                                        }
                                    }
                                }
                            }

                            if let text = entry.text, !text.isEmpty {
                                Text(text)
                                    .font(.caption)
                                    .lineLimit(3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Documentos")
        }
    }

    private func entryLabel(for entry: DocumentEntry) -> String {
        if entry.text != nil && !entry.imageFilenames.isEmpty {
            return "OCR + Fotos"
        }
        if entry.text != nil {
            return "OCR"
        }
        return "Fotos"
    }

    private func fileURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }

    @ViewBuilder
    private func thumbnailView(for filename: String) -> some View {
        if let url = fileURL(for: filename) {
#if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            }
#elseif canImport(AppKit)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            }
#endif
        }
    }
}

struct DocumentDetailView: View {
    let entry: DocumentEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !entry.imageFilenames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(entry.imageFilenames, id: \.self) { filename in
                                detailImageView(for: filename)
                            }
                        }
                    }
                }

                if let text = entry.text, !text.isEmpty {
                    Text(text)
                        .textSelection(.enabled)
                        .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle(formatter.string(from: entry.createdAt))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fileURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }

    @ViewBuilder
    private func detailImageView(for filename: String) -> some View {
        if let url = fileURL(for: filename) {
#if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 380)
                    .cornerRadius(10)
            }
#elseif canImport(AppKit)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 380)
                    .cornerRadius(10)
            }
#endif
        }
    }
}

private let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()
