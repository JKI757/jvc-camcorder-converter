import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL

let size: CGFloat = 1024
let canvas = NSSize(width: size, height: size)
let image = NSImage(size: canvas)

image.lockFocus()

let backgroundRect = NSRect(origin: .zero, size: canvas)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 180, yRadius: 180)
let backgroundGradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.98, green: 0.91, blue: 0.80, alpha: 1.0),
        NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.77, alpha: 1.0),
        NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.86, alpha: 1.0)
    ]
)
backgroundGradient?.draw(in: backgroundPath, angle: -25)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()

let bodyRect = NSRect(x: 200, y: 320, width: 600, height: 340)
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 110, yRadius: 110)
NSColor(calibratedRed: 0.20, green: 0.18, blue: 0.14, alpha: 1.0).setFill()
bodyPath.fill()

NSShadow().set()

let handleRect = NSRect(x: 320, y: 660, width: 260, height: 80)
let handlePath = NSBezierPath(roundedRect: handleRect, xRadius: 40, yRadius: 40)
NSColor(calibratedRed: 0.24, green: 0.22, blue: 0.18, alpha: 1.0).setFill()
handlePath.fill()

let lensRect = NSRect(x: 610, y: 390, width: 200, height: 200)
let lensPath = NSBezierPath(ovalIn: lensRect)
NSColor(calibratedRed: 0.85, green: 0.56, blue: 0.26, alpha: 1.0).setFill()
lensPath.fill()

let lensInnerRect = NSRect(x: 650, y: 430, width: 120, height: 120)
let lensInnerPath = NSBezierPath(ovalIn: lensInnerRect)
NSColor(calibratedRed: 0.96, green: 0.85, blue: 0.70, alpha: 1.0).setFill()
lensInnerPath.fill()

let viewfinderRect = NSRect(x: 250, y: 540, width: 160, height: 100)
let viewfinderPath = NSBezierPath(roundedRect: viewfinderRect, xRadius: 30, yRadius: 30)
NSColor(calibratedRed: 0.30, green: 0.28, blue: 0.22, alpha: 1.0).setFill()
viewfinderPath.fill()

let cardRect = NSRect(x: 280, y: 380, width: 180, height: 120)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 24, yRadius: 24)
NSColor(calibratedRed: 0.94, green: 0.90, blue: 0.82, alpha: 1.0).setFill()
cardPath.fill()

let notchPath = NSBezierPath()
notchPath.move(to: NSPoint(x: 410, y: 500))
notchPath.line(to: NSPoint(x: 460, y: 500))
notchPath.line(to: NSPoint(x: 460, y: 460))
notchPath.close()
NSColor(calibratedRed: 0.86, green: 0.82, blue: 0.74, alpha: 1.0).setFill()
notchPath.fill()

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render icon.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: outputURL, options: .atomic)
    print("Wrote icon to \(outputURL.path)")
} catch {
    fputs("Failed to write icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
