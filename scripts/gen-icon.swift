#!/usr/bin/env swift

import AppKit
import Foundation

let size: CGFloat = 1024
let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

// Rounded-rect purple gradient background.
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let radius = size * 0.225
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
path.addClip()
let gradient = NSGradient(colors: [
    NSColor(red: 0.22, green: 0.12, blue: 0.62, alpha: 1),
    NSColor(red: 0.10, green: 0.05, blue: 0.32, alpha: 1),
])!
gradient.draw(in: rect, angle: 90)

// Centred white character.bubble glyph.
let config = NSImage.SymbolConfiguration(pointSize: size * 0.55, weight: .medium)
if let glyph = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let w = glyph.size.width, h = glyph.size.height
    let origin = NSPoint(x: (size - w) / 2, y: (size - h) / 2 - size * 0.02)
    let glyphRect = NSRect(origin: origin, size: glyph.size)
    // Draw glyph, then paint white through it using sourceIn.
    glyph.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    NSColor.white.set()
    glyphRect.fill(using: .sourceIn)
}
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render PNG\n".utf8))
    exit(1)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(size))x\(Int(size)))")
