//
//  RootView.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Capturar", systemImage: "camera")
                }

            LibraryView()
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
