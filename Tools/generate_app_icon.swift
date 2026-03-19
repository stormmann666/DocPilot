import AppKit

let outputDirectory = URL(fileURLWithPath: "DocPilot/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let iconSpecs: [(name: String, size: CGFloat)] = [
    ("ios-1024.png", 1024),
    ("ios-1024-dark.png", 1024),
    ("ios-1024-tinted.png", 1024),
    ("mac-16.png", 16),
    ("mac-16@2x.png", 32),
    ("mac-32.png", 32),
    ("mac-32@2x.png", 64),
    ("mac-128.png", 128),
    ("mac-128@2x.png", 256),
    ("mac-256.png", 256),
    ("mac-256@2x.png", 512),
    ("mac-512.png", 512),
    ("mac-512@2x.png", 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawIcon(size: CGFloat, variant: String) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to obtain graphics context")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.225
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundPath.addClip()

    let backgroundColors: [CGColor]
    let accentColor: NSColor
    let detailColor: NSColor

    switch variant {
    case "dark":
        backgroundColors = [
            color(10, 30, 44).cgColor,
            color(18, 77, 104).cgColor,
            color(90, 186, 199).cgColor
        ]
        accentColor = color(246, 184, 76)
        detailColor = color(189, 238, 240, 0.85)
    case "tinted":
        backgroundColors = [
            color(24, 79, 91).cgColor,
            color(47, 135, 145).cgColor,
            color(181, 219, 210).cgColor
        ]
        accentColor = color(255, 244, 214)
        detailColor = color(228, 247, 240, 0.9)
    default:
        backgroundColors = [
            color(14, 93, 103).cgColor,
            color(36, 151, 168).cgColor,
            color(163, 230, 213).cgColor
        ]
        accentColor = color(244, 166, 74)
        detailColor = color(220, 248, 242, 0.9)
    }

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: backgroundColors as CFArray,
        locations: [0.0, 0.58, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: size * 0.15, y: size),
        end: CGPoint(x: size * 0.85, y: 0),
        options: []
    )

    context.saveGState()
    context.setBlendMode(.screen)
    context.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    context.fillEllipse(in: CGRect(x: size * 0.08, y: size * 0.62, width: size * 0.54, height: size * 0.42))
    context.restoreGState()

    let docRect = CGRect(x: size * 0.20, y: size * 0.18, width: size * 0.48, height: size * 0.62)
    let docRadius = size * 0.06
    let documentPath = NSBezierPath(roundedRect: docRect, xRadius: docRadius, yRadius: docRadius)
    NSColor.white.withAlphaComponent(0.98).setFill()
    documentPath.fill()

    let shadow = NSShadow()
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.set()
    documentPath.fill()
    NSShadow().set()

    let foldPath = NSBezierPath()
    let foldSize = size * 0.115
    foldPath.move(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY))
    foldPath.line(to: CGPoint(x: docRect.maxX, y: docRect.maxY))
    foldPath.line(to: CGPoint(x: docRect.maxX, y: docRect.maxY - foldSize))
    foldPath.close()
    detailColor.setFill()
    foldPath.fill()

    context.setStrokeColor(color(73, 157, 166, 0.42).cgColor)
    context.setLineWidth(size * 0.018)
    context.setLineCap(.round)
    let lines = [
        CGRect(x: docRect.minX + size * 0.08, y: docRect.minY + size * 0.39, width: docRect.width * 0.52, height: 0),
        CGRect(x: docRect.minX + size * 0.08, y: docRect.minY + size * 0.30, width: docRect.width * 0.44, height: 0),
        CGRect(x: docRect.minX + size * 0.08, y: docRect.minY + size * 0.21, width: docRect.width * 0.32, height: 0)
    ]
    for line in lines {
        context.move(to: CGPoint(x: line.minX, y: line.minY))
        context.addLine(to: CGPoint(x: line.minX + line.width, y: line.minY))
        context.strokePath()
    }

    let scanFrame = CGRect(x: docRect.minX - size * 0.02, y: docRect.minY - size * 0.02, width: docRect.width + size * 0.04, height: docRect.height + size * 0.04)
    context.setStrokeColor(detailColor.withAlphaComponent(0.75).cgColor)
    context.setLineWidth(size * 0.014)
    let cornerLength = size * 0.08
    let corners = [
        (CGPoint(x: scanFrame.minX, y: scanFrame.maxY - cornerLength), CGPoint(x: scanFrame.minX, y: scanFrame.maxY), CGPoint(x: scanFrame.minX + cornerLength, y: scanFrame.maxY)),
        (CGPoint(x: scanFrame.maxX - cornerLength, y: scanFrame.maxY), CGPoint(x: scanFrame.maxX, y: scanFrame.maxY), CGPoint(x: scanFrame.maxX, y: scanFrame.maxY - cornerLength)),
        (CGPoint(x: scanFrame.minX, y: scanFrame.minY + cornerLength), CGPoint(x: scanFrame.minX, y: scanFrame.minY), CGPoint(x: scanFrame.minX + cornerLength, y: scanFrame.minY)),
        (CGPoint(x: scanFrame.maxX - cornerLength, y: scanFrame.minY), CGPoint(x: scanFrame.maxX, y: scanFrame.minY), CGPoint(x: scanFrame.maxX, y: scanFrame.minY + cornerLength))
    ]
    for (start, middle, end) in corners {
        context.move(to: start)
        context.addLine(to: middle)
        context.addLine(to: end)
        context.strokePath()
    }

    let lensCenter = CGPoint(x: size * 0.70, y: size * 0.31)
    let lensRadius = size * 0.155
    let lensRect = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    let lensGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            accentColor.highlight(withLevel: 0.15)!.cgColor,
            accentColor.shadow(withLevel: 0.12)!.cgColor
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.saveGState()
    context.addEllipse(in: lensRect)
    context.clip()
    context.drawRadialGradient(
        lensGradient,
        startCenter: CGPoint(x: lensCenter.x - size * 0.03, y: lensCenter.y + size * 0.03),
        startRadius: size * 0.02,
        endCenter: lensCenter,
        endRadius: lensRadius,
        options: []
    )
    context.restoreGState()

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    context.setLineWidth(size * 0.028)
    context.strokeEllipse(in: lensRect.insetBy(dx: size * 0.014, dy: size * 0.014))

    context.setStrokeColor(accentColor.shadow(withLevel: 0.32)!.cgColor)
    context.setLineWidth(size * 0.052)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: lensCenter.x + lensRadius * 0.60, y: lensCenter.y - lensRadius * 0.58))
    context.addLine(to: CGPoint(x: lensCenter.x + lensRadius * 1.10, y: lensCenter.y - lensRadius * 1.08))
    context.strokePath()

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.30).cgColor)
    context.setLineWidth(size * 0.018)
    context.move(to: CGPoint(x: lensCenter.x - lensRadius * 0.42, y: lensCenter.y + lensRadius * 0.52))
    context.addLine(to: CGPoint(x: lensCenter.x + lensRadius * 0.15, y: lensCenter.y + lensRadius * 0.78))
    context.strokePath()

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage, size: CGFloat) -> Data? {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData)
    else {
        return nil
    }

    bitmap.size = NSSize(width: size, height: size)
    return bitmap.representation(using: .png, properties: [:])
}

let fileManager = FileManager.default

for spec in iconSpecs {
    let variant: String
    if spec.name.contains("dark") {
        variant = "dark"
    } else if spec.name.contains("tinted") {
        variant = "tinted"
    } else {
        variant = "default"
    }

    let image = drawIcon(size: spec.size, variant: variant)
    guard let data = pngData(from: image, size: spec.size) else {
        fatalError("Failed to generate PNG data for \(spec.name)")
    }

    let destination = outputDirectory.appendingPathComponent(spec.name)
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try data.write(to: destination)
    print("Wrote \(destination.path)")
}
