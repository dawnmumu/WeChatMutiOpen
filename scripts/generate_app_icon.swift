import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icns = resources.appendingPathComponent("AppIcon.icns")
let preview = resources.appendingPathComponent("AppIconPreview.png")
let fileManager = FileManager.default

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ path: NSBezierPath, _ color: NSColor) {
    color.setFill()
    path.fill()
}

func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

func drawIcon(size: CGFloat) {
    let unit = size / 1024
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let base = roundedRect(
        NSRect(x: 48 * unit, y: 48 * unit, width: 928 * unit, height: 928 * unit),
        radius: 210 * unit
    )
    let baseGradient = NSGradient(colors: [
        color(0x10d56c),
        color(0x12c186),
        color(0x18a8f2)
    ])!
    baseGradient.draw(in: base, angle: 135)

    fill(
        roundedRect(NSRect(x: 174 * unit, y: 610 * unit, width: 462 * unit, height: 246 * unit), radius: 86 * unit),
        color(0xffffff, alpha: 0.16)
    )
    fill(
        roundedRect(NSRect(x: 250 * unit, y: 528 * unit, width: 462 * unit, height: 246 * unit), radius: 86 * unit),
        color(0xffffff, alpha: 0.20)
    )

    let largeBubble = roundedRect(
        NSRect(x: 190 * unit, y: 318 * unit, width: 492 * unit, height: 338 * unit),
        radius: 128 * unit
    )
    fill(largeBubble, color(0xffffff, alpha: 0.96))
    let largeTail = NSBezierPath()
    largeTail.move(to: NSPoint(x: 328 * unit, y: 334 * unit))
    largeTail.line(to: NSPoint(x: 244 * unit, y: 244 * unit))
    largeTail.line(to: NSPoint(x: 446 * unit, y: 318 * unit))
    largeTail.close()
    fill(largeTail, color(0xffffff, alpha: 0.96))

    let smallBubble = roundedRect(
        NSRect(x: 470 * unit, y: 472 * unit, width: 330 * unit, height: 230 * unit),
        radius: 92 * unit
    )
    fill(smallBubble, color(0xffffff, alpha: 0.90))
    let smallTail = NSBezierPath()
    smallTail.move(to: NSPoint(x: 690 * unit, y: 486 * unit))
    smallTail.line(to: NSPoint(x: 796 * unit, y: 406 * unit))
    smallTail.line(to: NSPoint(x: 604 * unit, y: 468 * unit))
    smallTail.close()
    fill(smallTail, color(0xffffff, alpha: 0.90))

    for x in [322, 434, 546] {
        fill(
            NSBezierPath(ovalIn: NSRect(x: CGFloat(x) * unit, y: 456 * unit, width: 46 * unit, height: 46 * unit)),
            color(0x10b965, alpha: 0.92)
        )
    }
    for x in [572, 656] {
        fill(
            NSBezierPath(ovalIn: NSRect(x: CGFloat(x) * unit, y: 560 * unit, width: 34 * unit, height: 34 * unit)),
            color(0x12a8d8, alpha: 0.78)
        )
    }

    let badge = NSBezierPath(ovalIn: NSRect(x: 690 * unit, y: 126 * unit, width: 222 * unit, height: 222 * unit))
    let badgeGradient = NSGradient(colors: [
        color(0x2563eb),
        color(0x0ea5e9)
    ])!
    badgeGradient.draw(in: badge, angle: 90)
    stroke(badge, color(0xffffff, alpha: 0.82), width: 18 * unit)

    let plus = NSBezierPath()
    plus.lineCapStyle = .round
    plus.move(to: NSPoint(x: 802 * unit, y: 190 * unit))
    plus.line(to: NSPoint(x: 802 * unit, y: 286 * unit))
    plus.move(to: NSPoint(x: 754 * unit, y: 238 * unit))
    plus.line(to: NSPoint(x: 850 * unit, y: 238 * unit))
    stroke(plus, color(0xffffff), width: 34 * unit)
}

func makeImage(pixels: Int) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(size: CGFloat(pixels))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.addRepresentation(rep)
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGenerator", code: 1)
    }
    try png.write(to: url, options: .atomic)
}

try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in outputs {
    try writePNG(makeImage(pixels: pixels), to: iconset.appendingPathComponent(name))
}
try writePNG(makeImage(pixels: 1024), to: preview)

try? fileManager.removeItem(at: icns)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "IconGenerator", code: Int(process.terminationStatus))
}

print(icns.path)
