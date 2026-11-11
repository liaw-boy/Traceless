import SwiftUI

/// Small flat tag for states such as "執行中" or "系統".
public struct StatusBadge: View {
    let text: String
    var icon: String? = nil
    var color: Color = Palette.muted

    public var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(color.opacity(0.13), in: Capsule())
    }
}
