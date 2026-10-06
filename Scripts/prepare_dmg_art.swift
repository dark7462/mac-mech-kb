#!/usr/bin/env swift
import AppKit
import Foundation

// Finder background: draw at 1x and 2x, then bundle both in a Retina TIFF.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let work = root.appendingPathComponent(".build/dmg-art")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: root.appendingPathComponent("Assets"), withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func background(scale: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640 * scale, pixelsHigh: 360 * scale,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(scale))
    transform.concat()

    let bounds = NSRect(x: 0, y: 0, width: 640, height: 360)
    NSGradient(starting: color(0xFCFAF6), ending: color(0xEFEAE3))!.draw(in: bounds, angle: -90)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    ("Drag me to Applications" as NSString).draw(
        in: NSRect(x: 30, y: 275, width: 580, height: 40),
        withAttributes: [.font: NSFont.systemFont(ofSize: 28, weight: .semibold),
                         .foregroundColor: color(0x252B35), .paragraphStyle: paragraph])

    // These coordinates line up with the icon centers in dmg_settings.py.
    color(0xB68858).setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 3.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 282, y: 170))
    arrow.line(to: NSPoint(x: 358, y: 170))
    arrow.move(to: NSPoint(x: 344, y: 184))
    arrow.line(to: NSPoint(x: 358, y: 170))
    arrow.line(to: NSPoint(x: 344, y: 156))
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let normal = work.appendingPathComponent("background.png")
let retina = work.appendingPathComponent("background@2x.png")
try background(scale: 1).write(to: normal)
try background(scale: 2).write(to: retina)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
task.arguments = ["-cathidpicheck", normal.path, retina.path, "-out", root.appendingPathComponent("Assets/DMGBackground.tiff").path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { exit(task.terminationStatus) }
print("Created Assets/DMGBackground.tiff")
