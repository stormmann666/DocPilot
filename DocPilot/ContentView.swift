//
//  ContentView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @State private var isShowingCamera = false

    init(store: DocumentStore) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(store: store))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()

                Text("DocPilot")
                    .font(.largeTitle.weight(.semibold))

                VStack(spacing: 16) {
#if canImport(UIKit)
                    Button("Capturar foto y OCR") {
                        isShowingCamera = true
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
#endif

                    Button("Copy clipboard") {
                        viewModel.processClipboard()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer()
            }
            .padding()

            if viewModel.isProcessing {
                ProgressView("Reconociendo texto...")
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Error", isPresented: Binding(get: {
            viewModel.errorMessage != nil
        }, set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
#if canImport(UIKit)
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { result in
                switch result {
                case .success(let image):
                    viewModel.processCameraImage(image)
                case .failure:
                    viewModel.errorMessage = "No se pudo obtener la imagen."
                }
            }
        }
#endif
        .sheet(isPresented: $viewModel.isResultPresented) {
            VStack(alignment: .leading, spacing: 16) {
                if let title = viewModel.recognizedTitle {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $viewModel.recognizedText)
                    .frame(minHeight: 280)
                    .border(.gray.opacity(0.4))

                Button("Aceptar") {
                    viewModel.isResultPresented = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .presentationDetents([.medium, .large])
        }
    }

}

#Preview {
    ContentView(store: DocumentStore())
}
