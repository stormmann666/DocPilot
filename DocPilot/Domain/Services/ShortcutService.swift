//
//  ShortcutService.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation

enum ShortcutService {
    private static let pendingClipboardKey = "pendingClipboardCapture"

    static func markPendingClipboardCapture() {
        UserDefaults.standard.set(true, forKey: pendingClipboardKey)
    }

    static func consumePendingClipboardCapture() -> Bool {
        let shouldProcess = UserDefaults.standard.bool(forKey: pendingClipboardKey)
        if shouldProcess {
            UserDefaults.standard.set(false, forKey: pendingClipboardKey)
        }
        return shouldProcess
    }

    static func handlePendingClipboardCapture(store: DocumentStore) {
        guard consumePendingClipboardCapture() else {
            return
        }
        let useCase = DocumentUseCase(store: store)
        useCase.handleClipboard { _ in
            return
        }
    }
}
