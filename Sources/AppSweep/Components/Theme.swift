import SwiftUI
import AppSweepCore

/// Flat, system-driven styling: colors follow light/dark mode and the user's accent color.
extension ResidualCategory {
    var tint: Color {
        switch self {
        case .appBundle: return .blue
        case .applicationSupport: return .purple
        case .preferences: return .orange
        case .caches: return .teal
        case .containers, .groupContainers: return .indigo
        case .savedState: return .green
        case .webData: return .pink
        case .logs: return .brown
        case .launchAgents: return .red
        case .other: return .gray
        }
    }
}

enum AppVersion {
    /// "1.1.0 (3)" from the bundle; "開發版" when run via `swift run` without an Info.plist.
    static var display: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "開發版" }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}
