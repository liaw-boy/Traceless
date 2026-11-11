import SwiftUI

public enum AppTheme {
    // Canvas & Containers
    public static let canvasBg = Color(red: 0.07, green: 0.08, blue: 0.11)
    public static let sidebarBg = Color(red: 0.05, green: 0.06, blue: 0.08)
    public static let cardBg = Color(red: 0.11, green: 0.13, blue: 0.18)
    public static let cardSubtle = Color(red: 0.09, green: 0.10, blue: 0.14)
    public static let cardBorder = Color.white.opacity(0.08)
    public static let cardBorderHighlight = Color.blue.opacity(0.5)

    // Accents
    public static let accent = Color(red: 0.08, green: 0.52, blue: 1.0)
    public static let cyan = Color(red: 0.0, green: 0.88, blue: 0.95)
    public static let emerald = Color(red: 0.19, green: 0.82, blue: 0.35)
    public static let amber = Color(red: 1.0, green: 0.62, blue: 0.04)
    public static let coral = Color(red: 1.0, green: 0.27, blue: 0.23)
    public static let violet = Color(red: 0.75, green: 0.35, blue: 0.95)

    // Gradients
    public static let buttonGradient = LinearGradient(
        colors: [Color(red: 0.12, green: 0.55, blue: 1.0), Color(red: 0.02, green: 0.38, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let dangerGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.32, blue: 0.28), Color(red: 0.88, green: 0.15, blue: 0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let resetGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.65, blue: 0.1), Color(red: 0.95, green: 0.45, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
