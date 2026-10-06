#!/usr/bin/env swift
import AppKit
import Foundation

// Draw the app's vector icon at every macOS icon size. No external art packages.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent(".build/icon/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: root.appendingPathComponent("Assets"), withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func rounded(_ rect: NSRect, _ radius: CGFloat, _ fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    let outline = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 196, yRadius: 196)
    NSGradient(starting: color(0xFFD5A0), ending: color(0xE39149))!.draw(in: outline, angle: -90)
    rounded(NSRect(x: 189, y: 258, width: 646, height: 480), 90, color(0xAD6634))
    rounded(NSRect(x: 189, y: 281, width: 646, height: 480), 90, color(0x171D26))
    for row in 0..<2 {
        for column in 0..<4 {
            let x = CGFloat(234 + column * 143)
            let y = CGFloat(483 + row * 128)
            rounded(NSRect(x: x, y: y - 9, width: 126, height: 108), 24, color(0x555A61))
            let fill: UInt32 = row == 1 && column == 0 ? 0x8ABBF0 : (row == 1 && column == 1 ? 0xCE9F7A : (row == 1 && column == 2 ? 0xEC9290 : 0xF1EDE4))
            rounded(NSRect(x: x, y: y, width: 126, height: 108), 24, color(fill))
        }
    }
    rounded(NSRect(x: 234, y: 333, width: 555, height: 119), 26, color(0x555A61))
    rounded(NSRect(x: 234, y: 342, width: 555, height: 119), 26, color(0xF1EDE4))
    rounded(NSRect(x: 437, y: 373, width: 148, height: 10), 5, color(0xCECAC3))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        try drawIcon(size: points * scale).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Assets/AppIcon.icns").path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
print("Created Assets/AppIcon.icns")
