//
//  PlatformImage.swift
//  DocPilot
//
//  Created by Antonio Muñoz on 27/1/26.
//

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif
