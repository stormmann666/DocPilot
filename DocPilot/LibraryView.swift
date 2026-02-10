//
//  LibraryView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var viewModel: LibraryViewModel
    @State private var selectedEntryId: UUID?

    init(store: DocumentStore) {
        _viewModel = StateObject(wrappedValue: LibraryViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Buscar en OCR", text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Picker("Filtro", selection: $viewModel.filter) {
                    ForEach(LibraryViewModel.Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                List {
                    ForEach(viewModel.entries) { entry in
                        NavigationLink(tag: entry.id, selection: $selectedEntryId) {
                            DocumentDetailView(entryId: entry.id, viewModel: viewModel)
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                selectedEntryId = entry.id
                            }
                        )
                        .onLongPressGesture {
                            viewModel.beginEditingTitle(for: entry)
                        }
                    }
                    .onDelete(perform: store.deleteEntries)
                }
                .overlay {
                    if viewModel.isEmptyState(viewModel.entries) {
                        Text("No hay documentos guardados.")
                            .foregroundStyle(.secondary)
                    }
                }
                .refreshable {
                    viewModel.refresh()
                }
                .alert("Editar titulo", isPresented: Binding(
                    get: { viewModel.isEditingTitlePresented() },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.cancelEditingTitle()
                        }
                    }
                )) {
                    TextField("Titulo", text: $viewModel.draftTitle)
                    Button("Guardar") {
                        viewModel.saveEditingTitle()
                    }
                    Button("Cancelar", role: .cancel) {
                        viewModel.cancelEditingTitle()
                    }
                }
            }
            .navigationTitle("Documentos")
            .onAppear {
                viewModel.refresh()
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
    let entryId: UUID
    let viewModel: LibraryViewModel
    @EnvironmentObject private var store: DocumentStore
    @State private var selectedImageItem: ImageItem?
    @State private var isShowingDeleteAlert = false
    @State private var pdfErrorMessage: String?
    @State private var isShowingCamera = false
    @State private var isShowingFilePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if let entry = store.entries.first(where: { $0.id == entryId }) {
                VStack(alignment: .leading, spacing: 16) {
#if canImport(UIKit)
                    Button("Añadir PDF desde portapapeles") {
                        viewModel.addPDFToEntryFromClipboard(entry) { result in
                            if case .failure(let error) = result {
                                pdfErrorMessage = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Añadir PDF desde Archivos") {
                        isShowingFilePicker = true
                    }
                    .buttonStyle(.bordered)

                    Button("Añadir foto con OCR") {
                        isShowingCamera = true
                    }
                    .buttonStyle(.bordered)
#endif

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

                    if !entry.pdfs.isEmpty {
                        ForEach(entry.pdfs) { pdf in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PDF: \(pdf.filename)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if !pdf.ocrText.isEmpty {
                                    Button("Copiar OCR PDF") {
                                        copyText(pdf.ocrText)
                                    }
                                    .buttonStyle(.bordered)

                                    Text(pdf.ocrText)
                                        .textSelection(.enabled)
                                        .font(.body)
                                } else {
                                    Text("Sin OCR")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if let file = entry.fileFilename, !file.isEmpty {
                        Text("PDF guardado: \(file)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(store.entries.first(where: { $0.id == entryId }).map { $0.title ?? viewModel.formattedDate($0.createdAt) } ?? "Documento")
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
                if let entry = store.entries.first(where: { $0.id == entryId }) {
                    store.deleteEntry(entry)
                }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrara la imagen y el texto OCR.")
        }
        .alert("No se pudo añadir el PDF", isPresented: Binding(get: {
            pdfErrorMessage != nil
        }, set: { isPresented in
            if !isPresented {
                pdfErrorMessage = nil
            }
        })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(pdfErrorMessage ?? "")
        }
        .sheet(item: $selectedImageItem) { item in
            ImagePreview(image: item.image, viewModel: viewModel)
        }
#if canImport(UIKit)
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { result in
                switch result {
                case .success(let image):
                    if let entry = store.entries.first(where: { $0.id == entryId }) {
                        viewModel.addImagesToEntry(entry, images: [image]) { outcome in
                            if case .failure(let error) = outcome {
                                pdfErrorMessage = error.localizedDescription
                            }
                        }
                    }
                case .failure:
                    pdfErrorMessage = "No se pudo obtener la imagen."
                }
            }
        }
        .sheet(isPresented: $isShowingFilePicker) {
            PDFDocumentPicker { url in
                guard let url else {
                    return
                }
                if let entry = store.entries.first(where: { $0.id == entryId }) {
                    viewModel.addPDFToEntryFromFile(entry, fileURL: url) { result in
                        if case .failure(let error) = result {
                            pdfErrorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
#endif
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
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()
                platformImageView(image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / max(lastScale, 0.01)
                                scale = min(max(scale * delta, 1), 6)
                                lastScale = value
                            }
                            .onEnded { _ in
                                lastScale = 1
                                if scale == 1 {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                guard scale > 1 else { return }
                                lastOffset = offset
                            }
                    )
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

#if canImport(UIKit)
struct PDFDocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let completion: (URL?) -> Void

        init(completion: @escaping (URL?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil)
        }
    }
}
#endif

#Preview {
    LibraryView(store: DocumentStore())
        .environmentObject(DocumentStore())
}
