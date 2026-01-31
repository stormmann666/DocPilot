//
//  LibraryViewModel.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class LibraryViewModel: ObservableObject {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func entryLabel(for entry: DocumentEntry) -> String {
        entry.displayLabel
    }

    func formattedDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    func fileURL(for filename: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }

    func loadImage(for filename: String) -> PlatformImage? {
        guard let url = fileURL(for: filename) else {
            return nil
        }
        return loadImage(from: url)
    }

    func copyText(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }

    func copyImage(_ image: PlatformImage) {
#if canImport(UIKit)
        UIPasteboard.general.image = image
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
#endif
    }

    private func loadImage(from url: URL) -> PlatformImage? {
#if canImport(UIKit)
        UIImage(contentsOfFile: url.path)
#elseif canImport(AppKit)
        NSImage(contentsOf: url)
#endif
    }
}
