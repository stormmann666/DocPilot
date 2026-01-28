//
//  DocPilotApp.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI

@main
struct DocPilotApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
