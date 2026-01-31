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

    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DocumentStore()
        let useCase = DocumentUseCase(store: store)
        let result = await withCheckedContinuation { continuation in
            useCase.handleClipboard { outcome in
                continuation.resume(returning: outcome)
            }
        }

        switch result {
        case .success:
            return .result(dialog: "Listo, guardado en documentos.")
        case .failure:
            return .result(dialog: "No pude guardar el portapapeles.")
        }
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
