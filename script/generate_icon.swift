#!/usr/bin/env swift
import AppKit
import Foundation

let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    outputDir = FileManager.default.currentDirectoryPath
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// Background rounded rect — matches Settings header logo (light mode)
let bgRect = NSRect(origin: .zero, size: size)
let cornerRadius = size.width * 0.225
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

let gradient = NSGradient(colors: [
    NSColor.controlAccentColor,
    NSColor.systemBlue.withAlphaComponent(0.72)
])!
gradient.draw(in: bgPath, angle: 135)

let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.15),
    NSColor.white.withAlphaComponent(0.0)
])!
highlight.draw(in: bgPath, angle: -45)

// Hand SF Symbol — white, weight .semibold
if let hand = NSImage(systemSymbolName: "hand.point.up.left.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
    if let configured = hand.withSymbolConfiguration(config) {
        let symbolSize = configured.size
        let origin = NSPoint(
            x: (size.width - symbolSize.width) / 2,
            y: (size.height - symbolSize.height) / 2 + 20
        )
        NSColor.white.setFill()
        configured.draw(
            in: NSRect(origin: origin, size: symbolSize),
            from: .zero, operation: .sourceOver, fraction: 1.0
        )
    }
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: Failed to create PNG")
    exit(1)
}

let pngPath = "\(outputDir)/AppIcon.png"
try png.write(to: URL(fileURLWithPath: pngPath))
print("OK: \(pngPath)")
