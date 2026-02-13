//
//  AddTextIntent.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import AppIntents
import Foundation

struct AddTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Añade texto"
    static let description = IntentDescription("Crea un documento nuevo con el texto dictado.")

    static let openAppWhenRun = true

    @Parameter(title: "Texto")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DocumentStore()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .result(dialog: "No hay texto para guardar.")
        }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        let title = words.prefix(2).joined(separator: " ")
        store.addEntry(title: title.isEmpty ? nil : title, text: trimmed, imageFilenames: [], fileFilename: nil, linkURL: nil)
        return .result(dialog: "Texto guardado en documentos.")
    }
}
