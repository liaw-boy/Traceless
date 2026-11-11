import SwiftUI
import AppKit
import TracelessCore

/// One file or folder that can be moved to the Trash.
public struct ResidualItemRow: View {
    public let item: ResidualItem
    public var isLocked = false
    public let onToggle: () -> Void
    public let onReveal: () -> Void

    @State private var isHovered = false

    public init(item: ResidualItem, isLocked: Bool = false, onToggle: @escaping () -> Void, onReveal: @escaping () -> Void) {
        self.item = item
        self.isLocked = isLocked
        self.onToggle = onToggle
        self.onReveal = onReveal
    }

    private var canToggle: Bool { !item.isProtected && !isLocked }

    public var body: some View {
        HStack(spacing: 12) {
            Checkbox(value: item.isSelected ? .on : .off, isEnabled: canToggle, action: onToggle)

            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if item.isProtected {
                        StatusBadge(text: "受保護", icon: "lock.fill")
                    }
                }
                Text(item.path)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button(action: onReveal) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            .buttonStyle(.plain)
            .help("在 Finder 中顯示")
            .opacity(isHovered ? 1 : 0)
            .accessibilityLabel("在 Finder 中顯示")

            Text(item.formattedSize)
                .font(.display(13, .medium))
                .monospacedDigit()
                .foregroundStyle(item.isSelected ? Palette.ink : Palette.muted)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? Palette.canvas : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if canToggle { onToggle() } }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("在 Finder 中顯示", action: onReveal)
            Button("拷貝路徑") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
