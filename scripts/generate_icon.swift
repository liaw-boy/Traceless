import AppKit
import CoreGraphics
import Foundation

// Generates world-class macOS AppIcon for AppSweep:
// Inspired by top open-source Mac utilities (Pearcleaner, AppCleaner, CleanMyMac).
// Features a deep midnight sapphire squircle, an energetic neon-cyan sonic vortex ring,
// a floating 3D holographic frosted-glass app cube, and brilliant diamond sparkles.

let iconsetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func renderIcon(pixelSize: Int) -> Data? {
    let s = CGFloat(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else {
        return nil
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Standard macOS squircle dimensions (HIG: ~824x824 inside 1024x1024)
    let pad = s * 0.095
    let rect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let corner = rect.width * 0.225
    let squircle = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // 1. Realistic Ambient Drop Shadow for Squircle
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.038),
        blur: s * 0.065,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.52)
    )
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Base Squircle Clipping & Deep Midnight Sapphire Gradient
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.08, green: 0.16, blue: 0.32, alpha: 1.0), // Top: Luminous Deep Sapphire
        CGColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 1.0), // Mid: Midnight Navy
        CGColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1.0)  // Bottom: Deep Obsidian
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    if let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )
    }

    // Inner subtle rim lighting (Apple Bevel)
    ctx.addPath(squircle)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.28))
    ctx.setLineWidth(s * 0.012)
    ctx.strokePath()

    let cx = rect.midX
    let cy = rect.midY

    // 3. Radiant Ambient Backlight / Glow Aura
    ctx.saveGState()
    let glowColors = [
        CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.35),
        CGColor(red: 0.0, green: 0.45, blue: 0.95, alpha: 0.18),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(
            glowGrad,
            startCenter: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endCenter: CGPoint(x: cx, y: cy),
            endRadius: s * 0.38,
            options: []
        )
    }
    ctx.restoreGState()

    // 4. Dynamic Sonic Clean Vortex Sweeper (Glowing Cyan & Emerald Arc)
    // Draw dual sweeping speed rings representing deep system cleaning
    ctx.saveGState()
    ctx.setLineWidth(s * 0.028)
    ctx.setLineCap(.round)

    // Outer Sweeping Vortex Ring
    let rVortex1 = s * 0.26
    let arc1 = CGMutablePath()
    arc1.addArc(center: CGPoint(x: cx, y: cy - s * 0.01), radius: rVortex1, startAngle: -.pi * 0.75, endAngle: .pi * 0.85, clockwise: false)
    ctx.addPath(arc1)
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.92, blue: 0.98, alpha: 0.85))
    ctx.setShadow(offset: .zero, blur: s * 0.035, color: CGColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.75))
    ctx.strokePath()

    // Inner Counter-Sweep Ring (Electric Azure)
    let rVortex2 = s * 0.20
    let arc2 = CGMutablePath()
    arc2.addArc(center: CGPoint(x: cx, y: cy - s * 0.01), radius: rVortex2, startAngle: .pi * 0.4, endAngle: -.pi * 0.8, clockwise: true)
    ctx.addPath(arc2)
    ctx.setStrokeColor(CGColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.65))
    ctx.setLineWidth(s * 0.018)
    ctx.strokePath()
    ctx.restoreGState()

    // 5. 3D Isometric Holographic Frosted-Glass App Cube (應用程式立方體)
    // Positioned gracefully inside the vortex
    let cubeCX = cx
    let cubeCY = cy + s * 0.03
    let cw = s * 0.16 // half-width of top diamond
    let ch = cw * 0.58 // half-height of top diamond
    let cubeDepth = s * 0.17 // vertical extrusion height

    // Top Face Points
    let pTop = CGPoint(x: cubeCX, y: cubeCY + ch)
    let pRight = CGPoint(x: cubeCX + cw, y: cubeCY)
    let pBottom = CGPoint(x: cubeCX, y: cubeCY - ch)
    let pLeft = CGPoint(x: cubeCX - cw, y: cubeCY)

    // Left Face Bottom Points
    let pLeftBottom = CGPoint(x: pLeft.x, y: pLeft.y - cubeDepth)
    let pCenterBottom = CGPoint(x: pBottom.x, y: pBottom.y - cubeDepth)

    // Right Face Bottom Points
    let pRightBottom = CGPoint(x: pRight.x, y: pRight.y - cubeDepth)

    // A. Left Extrusion Face (Translucent Sapphire Glass)
    ctx.saveGState()
    let leftFace = CGMutablePath()
    leftFace.move(to: pLeft)
    leftFace.addLine(to: pBottom)
    leftFace.addLine(to: pCenterBottom)
    leftFace.addLine(to: pLeftBottom)
    leftFace.closeSubpath()
    ctx.addPath(leftFace)
    ctx.setFillColor(CGColor(red: 0.06, green: 0.25, blue: 0.55, alpha: 0.82))
    ctx.fillPath()
    // Edge highlight
    ctx.addPath(leftFace)
    ctx.setStrokeColor(CGColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.5))
    ctx.setLineWidth(s * 0.005)
    ctx.strokePath()
    ctx.restoreGState()

    // B. Right Extrusion Face (Deeper Cobalt Shadow)
    ctx.saveGState()
    let rightFace = CGMutablePath()
    rightFace.move(to: pBottom)
    rightFace.addLine(to: pRight)
    rightFace.addLine(to: pRightBottom)
    rightFace.addLine(to: pCenterBottom)
    rightFace.closeSubpath()
    ctx.addPath(rightFace)
    ctx.setFillColor(CGColor(red: 0.03, green: 0.14, blue: 0.38, alpha: 0.88))
    ctx.fillPath()
    // Edge highlight
    ctx.addPath(rightFace)
    ctx.setStrokeColor(CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.4))
    ctx.setLineWidth(s * 0.005)
    ctx.strokePath()
    ctx.restoreGState()

    // C. Top Face (Luminous Ice-Blue Diamond with Specular Reflection)
    ctx.saveGState()
    let topFace = CGMutablePath()
    topFace.move(to: pTop)
    topFace.addLine(to: pRight)
    topFace.addLine(to: pBottom)
    topFace.addLine(to: pLeft)
    topFace.closeSubpath()
    ctx.addPath(topFace)

    let topColors = [
        CGColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.95), // Bright Ice Cyan
        CGColor(red: 0.12, green: 0.48, blue: 0.95, alpha: 0.85)  // Azure
    ] as CFArray
    if let topGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: topColors, locations: [0.0, 1.0]) {
        ctx.clip()
        ctx.drawLinearGradient(topGrad, start: pTop, end: pBottom, options: [])
    }
    ctx.restoreGState()

    // Top Face Rim
    ctx.saveGState()
    ctx.addPath(topFace)
    ctx.setStrokeColor(CGColor(red: 0.9, green: 0.98, blue: 1.0, alpha: 0.8))
    ctx.setLineWidth(s * 0.007)
    ctx.strokePath()
    ctx.restoreGState()

    // D. Minimalist App Symbol on Top Face (White Rounded Tile Grid)
    ctx.saveGState()
    ctx.translateBy(x: cubeCX, y: cubeCY)
    ctx.scaleBy(x: 1.0, y: 0.58) // Match isometric perspective
    ctx.rotate(by: .pi / 4)

    let iconW = s * 0.045
    let iconGrid: [CGPoint] = [
        CGPoint(x: -iconW * 0.6, y: -iconW * 0.6),
        CGPoint(x: iconW * 0.6, y: -iconW * 0.6),
        CGPoint(x: -iconW * 0.6, y: iconW * 0.6),
        CGPoint(x: iconW * 0.6, y: iconW * 0.6)
    ]
    for pt in iconGrid {
        let tileRect = CGRect(x: pt.x - iconW * 0.45, y: pt.y - iconW * 0.45, width: iconW * 0.9, height: iconW * 0.9)
        let tilePath = CGPath(roundedRect: tileRect, cornerWidth: iconW * 0.22, cornerHeight: iconW * 0.22, transform: nil)
        ctx.addPath(tilePath)
        ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // 6. Dissolving Stardust Particles & Micro Cubes (Being Cleaned Away)
    let particles: [(CGPoint, CGFloat, CGColor)] = [
        (CGPoint(x: cx + s * 0.22, y: cy + s * 0.16), s * 0.024, CGColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85)),
        (CGPoint(x: cx + s * 0.28, y: cy + s * 0.02), s * 0.016, CGColor(red: 0.19, green: 0.85, blue: 0.55, alpha: 0.8)),
        (CGPoint(x: cx - s * 0.24, y: cy - s * 0.14), s * 0.018, CGColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.7)),
        (CGPoint(x: cx - s * 0.18, y: cy + s * 0.22), s * 0.014, CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)),
        (CGPoint(x: cx + s * 0.08, y: cy - s * 0.25), s * 0.020, CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.6))
    ]
    for (pos, rad, col) in particles {
        ctx.saveGState()
        ctx.addArc(center: pos, radius: rad, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ctx.setFillColor(col)
        ctx.setShadow(offset: .zero, blur: rad * 2, color: col)
        ctx.fillPath()
        ctx.restoreGState()
    }

    // 7. Brilliant 4-Point Diamond Clean Sparkles (✦)
    drawSparkleStar(ctx: ctx, center: CGPoint(x: cx + s * 0.23, y: cy + s * 0.24), size: s * 0.065, color: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    drawSparkleStar(ctx: ctx, center: CGPoint(x: cx - s * 0.26, y: cy + s * 0.12), size: s * 0.048, color: CGColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 0.9))
    drawSparkleStar(ctx: ctx, center: CGPoint(x: cx + s * 0.16, y: cy - s * 0.22), size: s * 0.038, color: CGColor(red: 0.2, green: 0.88, blue: 0.55, alpha: 0.85))

    // 8. Apple Signature Curved Glass Specular Highlight (Top-Left Arc)
    ctx.saveGState()
    let glassPath = CGMutablePath()
    glassPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    glassPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    glassPath.addQuadCurve(
        to: CGPoint(x: rect.minX, y: rect.midY + s * 0.05),
        control: CGPoint(x: rect.midX + s * 0.15, y: rect.midY + s * 0.2)
    )
    glassPath.closeSubpath()
    ctx.addPath(glassPath)

    let glassColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let glassGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glassColors, locations: [0.0, 1.0]) {
        ctx.clip()
        ctx.drawLinearGradient(glassGrad, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.midY), options: [])
    }
    ctx.restoreGState()

    ctx.restoreGState() // End squircle clip

    return rep.representation(using: .png, properties: [:])
}

func drawSparkleStar(ctx: CGContext, center: CGPoint, size: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.setFillColor(color)
    ctx.setShadow(offset: .zero, blur: size * 0.8, color: color)

    let path = CGMutablePath()
    let rOuter = size
    let rInner = size * 0.16

    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 - .pi / 2
        let r = (i % 2 == 0) ? rOuter : rInner
        let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        if i == 0 {
            path.move(to: pt)
        } else {
            path.addLine(to: pt)
        }
    }
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, name) in sizes {
    if let data = renderIcon(pixelSize: px) {
        let fileURL = URL(fileURLWithPath: iconsetPath).appendingPathComponent(name)
        try? data.write(to: fileURL)
    }
}

// Generate in-app brand asset (256x256)
if let brandData = renderIcon(pixelSize: 256) {
    let brandURL = URL(fileURLWithPath: "Resources/app-brand-icon.png")
    try? brandData.write(to: brandURL)
    print("Saved Resources/app-brand-icon.png")
}

print("Generated iconset at \(iconsetPath)")
