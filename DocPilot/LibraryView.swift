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
                                Text(entry.title ?? formatter.string(from: entry.createdAt))
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

                            if entry.title != nil {
                                Text(formatter.string(from: entry.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: store.deleteEntries)
            }
            .navigationTitle("Documentos")
            .toolbar {
                EditButton()
            }
        }
    }

    private func entryLabel(for entry: DocumentEntry) -> String {
        if entry.fileFilename != nil {
            return "PDF"
        }
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
    @EnvironmentObject private var store: DocumentStore
    @State private var selectedImageItem: ImageItem?
    @State private var isShowingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

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
                    Button("Copiar texto") {
                        copyText(text)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(text)
                        .textSelection(.enabled)
                        .font(.body)
                }

                if let file = entry.fileFilename, !file.isEmpty {
                    Text("PDF guardado: \(file)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(entry.title ?? formatter.string(from: entry.createdAt))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(role: .destructive) {
                isShowingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .alert("Borrar documento", isPresented: $isShowingDeleteAlert) {
            Button("Borrar", role: .destructive) {
                store.deleteEntry(entry)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrara la imagen y el texto OCR.")
        }
        .sheet(item: $selectedImageItem) { item in
            ImagePreview(image: item.image)
        }
    }

    private func fileURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }

    @ViewBuilder
    private func detailImageView(for filename: String) -> some View {
        if let url = fileURL(for: filename) {
            if let image = loadImage(from: url) {
                platformImageView(image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 380)
                    .cornerRadius(10)
                    .onTapGesture {
                        selectedImageItem = ImageItem(image: image)
                    }
                    .contextMenu {
                        Button("Copiar imagen") {
                            copyImage(image)
                        }
                    }
            }
        }
    }

    private func copyText(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}

struct ImageItem: Identifiable {
    let id = UUID()
    let image: PlatformImage
}

private let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#if canImport(UIKit)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
#endif

private func platformImageView(_ image: PlatformImage) -> Image {
#if canImport(UIKit)
    return Image(uiImage: image)
#elseif canImport(AppKit)
    return Image(nsImage: image)
#endif
}

private func loadImage(from url: URL) -> PlatformImage? {
#if canImport(UIKit)
    UIImage(contentsOfFile: url.path)
#elseif canImport(AppKit)
    NSImage(contentsOf: url)
#endif
}

private func copyImage(_ image: PlatformImage) {
#if canImport(UIKit)
    UIPasteboard.general.image = image
#elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([image])
#endif
}

struct ImagePreview: View {
    let image: PlatformImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()
                platformImageView(image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copiar imagen") {
                        copyImage(image)
                    }
                }
            }
        }
    }
}
