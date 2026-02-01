//
//  DebugLogger.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation

enum DebugLogger {
    private static let enabledKey = "debugLoggingEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        if isEnabled {
            print(message())
        }
#endif
    }
}
