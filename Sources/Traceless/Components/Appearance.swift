import SwiftUI
import AppKit

/// Light / dark choice, remembered across launches. "跟隨系統" follows macOS.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "跟隨系統"
    case light = "淺色"
    case dark = "深色"

    static let storageKey = "appearanceMode"
    var id: String { rawValue }

    /// Applied app-wide so every window, sheet and the About panel switch together.
    @MainActor func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppearanceMode.storageKey) private var mode: AppearanceMode = .system

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("外觀")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                FilterChips(options: AppearanceMode.allCases, selection: $mode)
                Text("「跟隨系統」會隨 macOS 的淺色／深色設定自動切換。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(24)
        .frame(width: 380, alignment: .leading)
        .background(Palette.surface)
        .onChange(of: mode) { _, new in new.apply() }
    }
}
