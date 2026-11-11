import AppKit
import CoreGraphics
import Foundation

// Flat AppSweep icon: a solid blue squircle with a white app tile being swept to the right,
// three motion strokes trailing behind it. Two colors, no gradients or glows.
// Usage: swift scripts/generate_icon.swift <output.iconset>

let iconsetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let background = CGColor(red: 0.16, green: 0.42, blue: 0.93, alpha: 1)   // #296BED
let foreground = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

func renderIcon(pixelSize: Int) -> Data? {
    let s = CGFloat(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }

    // macOS grid: 824/1024 body with ~22.5% corner radius, small soft shadow like system icons.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let squircle = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.025, color: CGColor(gray: 0, alpha: 0.28))
    ctx.addPath(squircle)
    ctx.setFillColor(background)
    ctx.fillPath()
    ctx.restoreGState()

    // White app tile with its motion strokes; the whole group is centered in the body.
    let tile = body.width * 0.36
    let gap = tile * 0.16
    let longest = body.width * 0.30
    let groupLeft = body.midX - (longest + gap + tile) / 2
    let tileRect = CGRect(x: groupLeft + longest + gap, y: body.midY - tile / 2, width: tile, height: tile)
    ctx.addPath(CGPath(roundedRect: tileRect, cornerWidth: tile * 0.24, cornerHeight: tile * 0.24, transform: nil))
    ctx.setFillColor(foreground)
    ctx.fillPath()

    // Motion strokes trailing to the left, decreasing in length.
    ctx.setStrokeColor(foreground)
    ctx.setLineCap(.round)
    ctx.setLineWidth(body.width * 0.055)
    let right = tileRect.minX - gap
    let lengths: [CGFloat] = [0.20, 0.30, 0.20]
    let ys: [CGFloat] = [tileRect.minY + tile * 0.2, tileRect.midY, tileRect.maxY - tile * 0.2]
    for (len, y) in zip(lengths, ys) {
        ctx.move(to: CGPoint(x: right - body.width * len, y: y))
        ctx.addLine(to: CGPoint(x: right, y: y))
    }
    ctx.strokePath()

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
