#!/usr/bin/env swift
//
// Renders Caffeinum.app's icon into an .iconset directory.
// Usage: swift scripts/make-icon.swift <output.iconset>
//

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.iconset>\n".data(using: .utf8)!)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

/// A rounded-square macOS icon: warm gradient plate with a cup glyph on top.
///
/// Drawing straight into a bitmap rep with explicit pixel dimensions keeps every
/// variant at exactly the size `iconutil` expects, regardless of display scale.
func renderIcon(size: CGFloat) -> Data? {
    let pixels = Int(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    bitmap.size = NSSize(width: size, height: size)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext

    let inset = size * 0.06
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let plate = NSBezierPath(roundedRect: rect,
                             xRadius: rect.width * 0.235,
                             yRadius: rect.width * 0.235)

    context.saveGState()
    plate.addClip()
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.16, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.14, blue: 0.09, alpha: 1),
    ])
    gradient?.draw(in: rect, angle: -90)
    context.restoreGState()

    let symbolSize = size * 0.52
    let configuration = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let tinted = NSImage(size: symbol.size, flipped: false) { bounds in
            NSColor(calibratedRed: 0.99, green: 0.94, blue: 0.86, alpha: 1).set()
            bounds.fill()
            symbol.draw(in: bounds, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        let target = CGRect(
            x: (size - tinted.size.width) / 2,
            y: (size - tinted.size.height) / 2,
            width: tinted.size.width,
            height: tinted.size.height
        )
        tinted.draw(in: target)
    }

    graphicsContext.flushGraphics()
    return bitmap.representation(using: .png, properties: [:])
}

// The set of sizes `iconutil` expects.
let variants: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    guard let data = renderIcon(size: variant.size) else {
        FileHandle.standardError.write("failed to render \(variant.name)\n".data(using: .utf8)!)
        exit(1)
    }
    try data.write(to: outputURL.appendingPathComponent("\(variant.name).png"))
}

print("wrote \(variants.count) images to \(outputURL.path)")
