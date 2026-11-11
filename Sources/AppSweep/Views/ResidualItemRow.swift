import SwiftUI
import AppSweepCore

public struct ResidualItemRow: View {
    public let item: ResidualItem
    public let onToggle: () -> Void
    public let onReveal: () -> Void

    @State private var isHovered: Bool = false
    @State private var copied: Bool = false

    public init(
        item: ResidualItem,
        onToggle: @escaping () -> Void,
        onReveal: @escaping () -> Void
    ) {
        self.item = item
        self.onToggle = onToggle
        self.onReveal = onReveal
    }

    public var body: some View {
        HStack(spacing: 11) {
            // Custom Checkbox
            CustomCheckbox(
                isChecked: item.isSelected,
                isProtected: item.isProtected,
                onToggle: onToggle
            )

            // Category Icon Badge
            Image(systemName: item.category.iconName)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 26, height: 26)
                .background(iconColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(iconColor.opacity(0.25), lineWidth: 0.8)
                )

            // Item Information
            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if item.isProtected {
                        StatusBadge(text: "系統保護", icon: "shield.fill", color: .secondary)
                    }
                }

                Text(item.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Item Size
            Text(item.formattedSize)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)

            // Action Buttons (Reveal & Copy Path)
            HStack(spacing: 4) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.url.path, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(copied ? AppTheme.emerald : .secondary)
                        .padding(5)
                        .background(isHovered ? Color.white.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help(copied ? "已複製完整路徑" : "複製檔案路徑")

                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(isHovered ? Color.white.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("在 Finder 中顯示此檔案")
            }
            .opacity(isHovered ? 1.0 : 0.6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture {
            if !item.isProtected {
                onToggle()
            }
        }
        .onHover { isHovered = $0 }
    }

    private var iconColor: Color {
        switch item.category {
        case .appBundle: return AppTheme.accent
        case .caches: return AppTheme.cyan
        case .applicationSupport: return AppTheme.violet
        case .containers, .groupContainers: return Color.indigo
        case .preferences: return AppTheme.amber
        case .savedState: return AppTheme.emerald
        case .logs: return Color.brown
        default: return AppTheme.coral
        }
    }
}
