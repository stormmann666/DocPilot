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
        print("[ShortcutService] markPendingClipboardCapture at \(Date())")
        let now = Date().timeIntervalSince1970
        let lastRequested = UserDefaults.standard.double(forKey: lastRequestedKey)
        if now - lastRequested < 3 {
            print("[ShortcutService] markPendingClipboardCapture skipped (cooldown)")
            return
        }
        UserDefaults.standard.set(now, forKey: lastRequestedKey)
        UserDefaults.standard.set(true, forKey: pendingClipboardKey)
        print("[ShortcutService] pendingClipboardKey set true")
    }

    static func consumePendingClipboardCapture() -> Bool {
        let shouldProcess = UserDefaults.standard.bool(forKey: pendingClipboardKey)
        if shouldProcess {
            UserDefaults.standard.set(false, forKey: pendingClipboardKey)
            print("[ShortcutService] pendingClipboardKey set false")
        }
        return shouldProcess
    }

    static func handlePendingClipboardCapture(store: DocumentStore) {
        print("[ShortcutService] handlePendingClipboardCapture at \(Date())")
        guard consumePendingClipboardCapture() else {
            print("[ShortcutService] no pending capture")
            return
        }
        print("[ShortcutService] pending capture consumed")
        let now = Date().timeIntervalSince1970
        let lastProcessed = UserDefaults.standard.double(forKey: lastProcessedKey)
        if now - lastProcessed < 3 {
            print("[ShortcutService] skipped (cooldown)")
            return
        }
#if canImport(UIKit)
        let changeCount = UIPasteboard.general.changeCount
        let lastChangeCount = UserDefaults.standard.integer(forKey: lastClipboardChangeCountKey)
        print("[ShortcutService] pasteboard changeCount: \(changeCount) last: \(lastChangeCount)")
        if changeCount == lastChangeCount {
            print("[ShortcutService] skipped (same pasteboard changeCount)")
            return
        }
        UserDefaults.standard.set(changeCount, forKey: lastClipboardChangeCountKey)
#endif
        UserDefaults.standard.set(now, forKey: lastProcessedKey)
        let useCase = DocumentUseCase(store: store)
        useCase.handleClipboard { _ in
            print("[ShortcutService] handleClipboard completed")
            return
        }
    }
}
