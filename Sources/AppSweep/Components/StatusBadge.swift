import SwiftUI

/// Small flat tag used for states such as "執行中" or "系統".
public struct StatusBadge: View {
    let text: String
    var icon: String? = nil
    var color: Color = .secondary

    public var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}
