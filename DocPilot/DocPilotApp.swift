//
//  DocPilotApp.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import SwiftUI
import Combine

@main
struct DocPilotApp: App {
    @StateObject private var store = DocumentStore()
    @Environment(\.scenePhase) private var scenePhase
    private let pendingPoller = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        DebugLogger.log("[DocPilotApp] scenePhase active")
                        ShortcutService.handlePendingClipboardCapture(store: store)
                    }
                }
                .onReceive(pendingPoller) { _ in
                    guard scenePhase == .active else { return }
                    DebugLogger.log("[DocPilotApp] poller tick")
                    ShortcutService.handlePendingClipboardCapture(store: store)
                }
        }
    }
}
