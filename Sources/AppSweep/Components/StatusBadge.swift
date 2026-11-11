import SwiftUI

public struct StatusBadge: View {
    public let text: String
    public let icon: String?
    public let color: Color

    public init(text: String, icon: String? = nil, color: Color = .secondary) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.14))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.25), lineWidth: 0.8)
        )
    }
}
