//
//  AddClipIntent.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import AppIntents
import Foundation

struct AddClipIntent: AppIntent {
    static let title: LocalizedStringResource = "Añade clip"
    static let description = IntentDescription("Guarda el portapapeles en Documentos.")

    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        DebugLogger.log("[AddClipIntent] perform() start")
        ShortcutService.markPendingClipboardCapture()
        DebugLogger.log("[AddClipIntent] pending capture requested")
        return .result(dialog: "Abriendo DocPilot para guardar el clip.")
    }
}

struct DocPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddClipIntent(),
            phrases: [
                "Añade clip en \(.applicationName)",
                "Añade clip con \(.applicationName)",
                "Agregar clip con \(.applicationName)"
            ],
            shortTitle: "Añade clip",
            systemImageName: "doc.on.clipboard"
        )
    }
}
