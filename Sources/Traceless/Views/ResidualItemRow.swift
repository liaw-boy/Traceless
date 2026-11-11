import SwiftUI
import AppKit
import TracelessCore

/// One file or folder that can be moved to the Trash.
public struct ResidualItemRow: View {
    public let item: ResidualItem
    public let onToggle: () -> Void
    public let onReveal: () -> Void

    @State private var isHovered = false

    public init(item: ResidualItem, onToggle: @escaping () -> Void, onReveal: @escaping () -> Void) {
        self.item = item
        self.onToggle = onToggle
        self.onReveal = onReveal
    }

    public var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { item.isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.isProtected)

            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .lineLimit(1)
                    if item.isProtected {
                        StatusBadge(text: "受保護", icon: "lock.fill")
                    }
                }
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if isHovered {
                Button(action: onReveal) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("在 Finder 中顯示")
            }

            Text(item.formattedSize)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { if !item.isProtected { onToggle() } }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("在 Finder 中顯示", action: onReveal)
            Button("拷貝路徑") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isSelected ? "已勾選" : "未勾選")
        .accessibilityAddTraits(.isButton)
    }
}
