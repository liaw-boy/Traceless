import AppKit
import CoreGraphics
import Foundation

// Traceless icon: an app tile dissolving into ever-smaller squares — it leaves without a trace.
// Solid shapes only (no gradients, no transparency), so it also reads when macOS swaps the
// background in dark / tinted icon modes. Geometry is shared with TraceMark in the app (Theme.swift).
// Usage: swift scripts/generate_icon.swift <output.iconset> [--dark]

let args = CommandLine.arguments
let iconsetPath = args.count > 1 ? args[1] : "Resources/AppIcon.iconset"
let darkPreview = args.contains("--dark")
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let background = darkPreview ? CGColor(gray: 0.12, alpha: 1) : CGColor(red: 0.11, green: 0.50, blue: 0.40, alpha: 1)  // #1C8066
let ink = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

/// Unit-square geometry (origin top-left, y down), mirrored by TraceMark.
struct Dissolve {
    struct Cell { let x, y, size: CGFloat }
    static let rows = 4
    static let cellPitch: CGFloat = 0.16                 // row height and column width
    static let top: CGFloat = 0.5 - CGFloat(rows) * cellPitch / 2
    static let solidLeft: CGFloat = 0.04
    static let solidRight: CGFloat = 0.42
    static let corner: CGFloat = 0.13
    /// Columns to the right of the solid block: scale of each cell, nil = gone.
    static let columns: [[CGFloat?]] = [
        [0.86, 0.86, 0.86, 0.86],
        [0.62, nil, 0.62, 0.62],
        [nil, 0.40, nil, 0.40],
        [0.22, nil, nil, nil],
    ]
    /// Small sizes keep only the nearest fragments so they do not blur into noise.
    static let smallColumns: [[CGFloat?]] = [
        [0.8, 0.8, 0.8, 0.8],
        [0.5, nil, 0.5, nil],
    ]
    static func cells(small: Bool) -> [Cell] {
        var out: [Cell] = []
        for (c, column) in (small ? smallColumns : columns).enumerated() {
            let cx = solidRight + 0.02 + cellPitch * (CGFloat(c) + 0.5) + 0.012 * CGFloat(c)
            for (r, scale) in column.enumerated() {
                guard let scale else { continue }
                let size = cellPitch * scale
                let cy = top + cellPitch * (CGFloat(r) + 0.5)
                out.append(Cell(x: cx - size / 2, y: cy - size / 2, size: size))
            }
        }
        return out
    }
}

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

    // Mark occupies 62% of the body, centred; convert unit (y-down) to CG (y-up).
    let m = body.width * 0.62
    let ox = body.midX - m / 2, oy = body.midY - m / 2
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: ox + x * m, y: oy + (1 - y - h) * m, width: w * m, height: h * m)
    }
    ctx.setFillColor(ink)

    // Solid part of the tile: rounded on the left, square where it starts to break up.
    let solid = rect(Dissolve.solidLeft, Dissolve.top, Dissolve.solidRight - Dissolve.solidLeft + 0.002, Dissolve.cellPitch * CGFloat(Dissolve.rows))
    let r = Dissolve.corner * m
    let path = CGMutablePath()
    path.move(to: CGPoint(x: solid.maxX, y: solid.maxY))
    path.addLine(to: CGPoint(x: solid.minX + r, y: solid.maxY))
    path.addArc(tangent1End: CGPoint(x: solid.minX, y: solid.maxY), tangent2End: CGPoint(x: solid.minX, y: solid.minY), radius: r)
    path.addArc(tangent1End: CGPoint(x: solid.minX, y: solid.minY), tangent2End: CGPoint(x: solid.maxX, y: solid.minY), radius: r)
    path.addLine(to: CGPoint(x: solid.maxX, y: solid.minY))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()

    // Fragments, each slightly rounded.
    for cell in Dissolve.cells(small: pixelSize <= 64) {
        let rr = rect(cell.x, cell.y, cell.size, cell.size)
        let cr = rr.width * 0.22
        ctx.addPath(CGPath(roundedRect: rr, cornerWidth: cr, cornerHeight: cr, transform: nil))
        ctx.fillPath()
    }

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
