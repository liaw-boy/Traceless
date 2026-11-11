import SwiftUI
import AppKit
import TracelessCore

// MARK: - Palette

/// Traceless palette. Every colour adapts to light/dark through a dynamic NSColor.
enum Palette {
    // Graphite monochrome: the accent is near-black in light mode and near-white in dark mode,
    // so anything drawn on it uses `onAccent`, which flips the other way.
    static let accent = dynamic(light: 0x1D1D1F, dark: 0xEDEDEF)        // selection, checkbox, primary action
    static let accentFill = accent
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x1D1D1F)      // text/marks on accent fills
    static let accentWash = dynamic(light: 0xE8E8EA, dark: 0x2A2A2E)    // hover
    static let canvas = dynamic(light: 0xF5F5F7, dark: 0x161618)        // window background
    static let sidebar = dynamic(light: 0xEDEDEF, dark: 0x111113)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1E1E21)       // content panels
    static let slot = dynamic(light: 0xE6E6E9, dark: 0x0D0D0F)          // recessed track
    static let ink = dynamic(light: 0x1D1D1F, dark: 0xEDEDEF)
    static let muted = dynamic(light: 0x6E6E73, dark: 0x98989F)
    static let hairline = dynamic(light: 0xDADADD, dark: 0x2C2C30)
    static let brick = dynamic(light: 0xC23B2B, dark: 0xE5604D)         // destructive (the only colour)
    static let brickFill = dynamic(light: 0xC23B2B, dark: 0xB8372A)
    static let ochre = dynamic(light: 0xB7791F, dark: 0xD9A04A)         // warnings

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension ResidualCategory {
    /// Muted, related hues so the storage slot reads as one family rather than a rainbow.
    var tint: Color {
        switch self {
        case .appBundle: return Palette.accent
        case .applicationSupport: return Palette.dynamic(light: 0x4F7A9A, dark: 0x7AA3C2)
        case .preferences: return Palette.dynamic(light: 0xB7791F, dark: 0xD9A04A)
        case .caches: return Palette.dynamic(light: 0x6E9C8C, dark: 0x8DBBAA)
        case .containers, .groupContainers: return Palette.dynamic(light: 0x6B6496, dark: 0x9A93C4)
        case .savedState: return Palette.dynamic(light: 0x8A9A5B, dark: 0xAFBF7E)
        case .webData: return Palette.dynamic(light: 0xA2615E, dark: 0xC98986)
        case .logs: return Palette.dynamic(light: 0x8C7B6B, dark: 0xB2A291)
        case .launchAgents: return Palette.dynamic(light: 0x9A4F3C, dark: 0xC27762)
        case .other: return Palette.muted
        }
    }
}

// MARK: - Type

extension Font {
    /// Rounded display face echoes the soft tile in the icon; used for names and numbers.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum AppVersion {
    /// "1.1.0 (5)" from the bundle; "開發版" when run via `swift run` without an Info.plist.
    static var display: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "開發版" }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short)（\($0)）" } ?? short
    }
}

// MARK: - Brand mark

/// The icon's motif drawn live: an app tile dissolving into smaller and smaller squares.
/// Same geometry as scripts/generate_icon.swift. `dissolving: false` shows the whole tile.
struct TraceMark: View {
    var size: CGFloat = 64
    var color: Color = Palette.accent
    var dissolving = true

    private static let rows = 4
    private static let pitch: CGFloat = 0.16
    private static let top: CGFloat = 0.5 - CGFloat(rows) * pitch / 2
    private static let solidLeft: CGFloat = 0.04
    private static let solidRight: CGFloat = 0.42
    private static let columns: [[CGFloat?]] = [
        [0.86, 0.86, 0.86, 0.86],
        [0.62, nil, 0.62, 0.62],
        [nil, 0.40, nil, 0.40],
        [0.22, nil, nil, nil],
    ]
    private static let smallColumns: [[CGFloat?]] = [
        [0.8, 0.8, 0.8, 0.8],
        [0.5, nil, 0.5, nil],
    ]

    var body: some View {
        Canvas { ctx, canvas in
            let m = canvas.width
            let height = CGFloat(Self.rows) * Self.pitch * m
            if !dissolving {
                let rect = CGRect(x: Self.solidLeft * m, y: Self.top * m, width: (Self.solidRight - Self.solidLeft + 0.5) * m, height: height)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 0.13 * m, style: .continuous), with: .color(color))
                return
            }
            let solid = CGRect(x: Self.solidLeft * m, y: Self.top * m, width: (Self.solidRight - Self.solidLeft) * m, height: height)
            ctx.fill(Path(roundedRect: solid, cornerRadii: RectangleCornerRadii(topLeading: 0.13 * m, bottomLeading: 0.13 * m), style: .continuous),
                     with: .color(color))
            let cols = size <= 32 ? Self.smallColumns : Self.columns
            for (c, column) in cols.enumerated() {
                let cx = Self.solidRight + 0.02 + Self.pitch * (CGFloat(c) + 0.5) + 0.012 * CGFloat(c)
                for (r, scale) in column.enumerated() {
                    guard let scale else { continue }
                    let side = Self.pitch * scale * m
                    let cy = (Self.top + Self.pitch * (CGFloat(r) + 0.5)) * m
                    let rect = CGRect(x: cx * m - side / 2, y: cy - side / 2, width: side, height: side)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: side * 0.22, style: .continuous), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// Flat checkbox in brand colour with a real mixed state (macOS 14 SwiftUI has none).
struct Checkbox: View {
    enum Value { case on, off, mixed }
    let value: Value
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(value == .off ? Color.clear : Palette.accent)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(value == .off ? Palette.muted.opacity(0.7) : Palette.accent, lineWidth: 1.2)
                switch value {
                case .on:
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Palette.onAccent)
                case .mixed:
                    Capsule().fill(Palette.onAccent).frame(width: 8, height: 2)
                case .off:
                    EmptyView()
                }
            }
            .frame(width: 16, height: 16)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityValue(value == .on ? "已勾選" : value == .mixed ? "部分勾選" : "未勾選")
    }
}

/// Capsule filter chips; selection is a solid accent pill.
struct FilterChips<Option: Hashable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isOn = option == selection
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Palette.onAccent : Palette.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isOn ? Palette.accentFill : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Palette.slot, in: Capsule())
    }
}

/// Filled action button: graphite accent for primary, brick for destructive.
struct SolidButtonStyle: ButtonStyle {
    var color: Color = Palette.accentFill
    var textColor: Color = Palette.onAccent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Quiet secondary button: text on a faint wash.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.ink.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Palette.slot.opacity(configuration.isPressed ? 1 : 0.7),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
