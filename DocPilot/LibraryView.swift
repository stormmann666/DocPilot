//
//  LibraryView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedFilter: LibraryViewModel.Filter = .all

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredEntries(store.entries, filter: selectedFilter)) { entry in
                    NavigationLink {
                        DocumentDetailView(entry: entry, viewModel: viewModel)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(entry.title ?? viewModel.formattedDate(entry.createdAt))
                                    .font(.subheadline)
                                Spacer()
                                Text(viewModel.entryLabel(for: entry))
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
                                Text(viewModel.formattedDate(entry.createdAt))
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
            .safeAreaInset(edge: .top) {
                Picker("Filtro", selection: $selectedFilter) {
                    ForEach(LibraryViewModel.Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .overlay {
                if viewModel.filteredEntries(store.entries, filter: selectedFilter).isEmpty {
                    Text("No hay documentos guardados.")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                EditButton()
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(for filename: String) -> some View {
        if let image = viewModel.loadImage(for: filename) {
            platformImageView(image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
        }
    }
}

struct DocumentDetailView: View {
    let entry: DocumentEntry
    let viewModel: LibraryViewModel
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
        .navigationTitle(entry.title ?? viewModel.formattedDate(entry.createdAt))
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
            ImagePreview(image: item.image, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func detailImageView(for filename: String) -> some View {
        if let image = viewModel.loadImage(for: filename) {
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
                        viewModel.copyImage(image)
                    }
                }
        }
    }

    private func copyText(_ text: String) {
        viewModel.copyText(text)
    }
}

struct ImageItem: Identifiable {
    let id = UUID()
    let image: PlatformImage
}

private func platformImageView(_ image: PlatformImage) -> Image {
#if canImport(UIKit)
    return Image(uiImage: image)
#elseif canImport(AppKit)
    return Image(nsImage: image)
#endif
}

struct ImagePreview: View {
    let image: PlatformImage
    let viewModel: LibraryViewModel
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
                        viewModel.copyImage(image)
                    }
                }
            }
        }
    }
}
