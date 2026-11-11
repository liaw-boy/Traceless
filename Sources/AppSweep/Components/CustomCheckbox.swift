import SwiftUI

public struct CustomCheckbox: View {
    public let isChecked: Bool
    public let isProtected: Bool
    public let onToggle: () -> Void

    @State private var isHovered: Bool = false

    public init(isChecked: Bool, isProtected: Bool = false, onToggle: @escaping () -> Void) {
        self.isChecked = isChecked
        self.isProtected = isProtected
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(backgroundColor)
                    .frame(width: 17, height: 17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(borderColor, lineWidth: 1.2)
                    )

                if isProtected {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                } else if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isProtected)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if isProtected {
            return Color.white.opacity(0.04)
        }
        if isChecked {
            return AppTheme.accent
        }
        return isHovered ? Color.white.opacity(0.08) : Color.black.opacity(0.3)
    }

    private var borderColor: Color {
        if isProtected {
            return Color.white.opacity(0.12)
        }
        if isChecked {
            return AppTheme.accent
        }
        return isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.2)
    }
}
