//
//  RootView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        TabView {
            ContentView(store: store)
                .tabItem {
                    Label("Capturar", systemImage: "camera")
                }

            LibraryView(store: store)
                .tabItem {
                    Label("Documentos", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(DocumentStore())
}
