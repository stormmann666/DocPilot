//
//  ShortcutService.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ShortcutService {
    private static let pendingClipboardKey = "pendingClipboardCapture"
    private static let lastProcessedKey = "lastProcessedClipboardCapture"
    private static let lastRequestedKey = "lastRequestedClipboardCapture"
    private static let lastClipboardChangeCountKey = "lastClipboardChangeCount"

    static func markPendingClipboardCapture() {
        DebugLogger.log("[ShortcutService] markPendingClipboardCapture")
        let now = Date().timeIntervalSince1970
        let lastRequested = UserDefaults.standard.double(forKey: lastRequestedKey)
        if now - lastRequested < 3 {
            DebugLogger.log("[ShortcutService] skipped (cooldown)")
            return
        }
        UserDefaults.standard.set(now, forKey: lastRequestedKey)
        UserDefaults.standard.set(true, forKey: pendingClipboardKey)
    }

    static func consumePendingClipboardCapture() -> Bool {
        let shouldProcess = UserDefaults.standard.bool(forKey: pendingClipboardKey)
        if shouldProcess {
            UserDefaults.standard.set(false, forKey: pendingClipboardKey)
            DebugLogger.log("[ShortcutService] pending capture consumed")
        }
        return shouldProcess
    }

    static func handlePendingClipboardCapture(store: DocumentStore) {
        DebugLogger.log("[ShortcutService] handlePendingClipboardCapture")
        guard consumePendingClipboardCapture() else {
            return
        }
        let now = Date().timeIntervalSince1970
        let lastProcessed = UserDefaults.standard.double(forKey: lastProcessedKey)
        if now - lastProcessed < 3 {
            DebugLogger.log("[ShortcutService] skipped (cooldown)")
            return
        }
#if canImport(UIKit)
        let changeCount = UIPasteboard.general.changeCount
        let lastChangeCount = UserDefaults.standard.integer(forKey: lastClipboardChangeCountKey)
        if changeCount == lastChangeCount {
            DebugLogger.log("[ShortcutService] skipped (same pasteboard changeCount)")
            return
        }
        UserDefaults.standard.set(changeCount, forKey: lastClipboardChangeCountKey)
#endif
        UserDefaults.standard.set(now, forKey: lastProcessedKey)
        let useCase = DocumentUseCase(store: store)
        useCase.handleClipboard { _ in
            return
        }
    }
}
