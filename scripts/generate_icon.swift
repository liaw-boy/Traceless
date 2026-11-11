import AppKit
import CoreGraphics
import Foundation

// Uproot icon: an app tile lifted up and out of the U-shaped slot it sat in — the app leaves cleanly,
// and the U doubles as the initial.
// Geometric, single-colour foreground so it also reads when macOS swaps the background
// (dark / tinted icon modes on macOS 26). No gradients, no glow.
// Usage: swift scripts/generate_icon.swift <output.iconset> [--dark]

let args = CommandLine.arguments
let iconsetPath = args.count > 1 ? args[1] : "Resources/AppIcon.iconset"
let darkPreview = args.contains("--dark")
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let background = darkPreview ? CGColor(gray: 0.12, alpha: 1) : CGColor(red: 0.11, green: 0.50, blue: 0.40, alpha: 1)  // #1C8066
let ink = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

func renderIcon(pixelSize: Int) -> Data? {
    let s = CGFloat(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }

    // macOS icon grid: 824/1024 body, ~22.5% corner radius, soft system-style shadow.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let squircle = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.025, color: CGColor(gray: 0, alpha: 0.28))
    ctx.addPath(squircle)
    ctx.setFillColor(background)
    ctx.fillPath()
    ctx.restoreGState()

    let w = body.width
    let tile = w * 0.40
    let corner = tile * 0.24
    let lift = tile * 0.58
    // Slot + tile lifted straight up out of it, centred as a group.
    let groupHeight = tile + lift
    let slotRect = CGRect(x: body.midX - tile / 2, y: body.midY - groupHeight / 2, width: tile, height: tile)
    let tileRect = slotRect.offsetBy(dx: 0, dy: lift)

    // "U": the lower part of the slot the app used to occupy (and Uproot's initial).
    let stroke = w * (pixelSize <= 64 ? 0.05 : 0.032)
    let slot = slotRect.insetBy(dx: stroke / 2, dy: stroke / 2)
    let topY = tileRect.minY + tile * 0.12              // rises behind the tile, which sits in front
    let r = corner - stroke / 2
    let u = CGMutablePath()
    u.move(to: CGPoint(x: slot.minX, y: topY))
    u.addLine(to: CGPoint(x: slot.minX, y: slot.minY + r))
    u.addArc(center: CGPoint(x: slot.minX + r, y: slot.minY + r), radius: r, startAngle: .pi, endAngle: 1.5 * .pi, clockwise: false)
    u.addLine(to: CGPoint(x: slot.maxX - r, y: slot.minY))
    u.addArc(center: CGPoint(x: slot.maxX - r, y: slot.minY + r), radius: r, startAngle: 1.5 * .pi, endAngle: 2 * .pi, clockwise: false)
    u.addLine(to: CGPoint(x: slot.maxX, y: topY))
    ctx.saveGState()
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(u)
    ctx.strokePath()
    ctx.restoreGState()

    // Lifted tile, ringed in the background colour so the U visibly passes behind it.
    let tilePath = CGPath(roundedRect: tileRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.addPath(tilePath)
    ctx.setStrokeColor(background)
    ctx.setLineWidth(stroke * 2.6)
    ctx.strokePath()
    ctx.addPath(tilePath)
    ctx.setFillColor(ink)
    ctx.fillPath()

    return rep.representation(using: .png, properties: [:])
}

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, px) in sizes {
    guard let data = renderIcon(pixelSize: px) else { fatalError("render failed for \(name)") }
    try data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}
print("Wrote \(sizes.count) icons to \(iconsetPath)")
