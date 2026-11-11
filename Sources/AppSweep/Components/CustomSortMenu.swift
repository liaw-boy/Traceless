import SwiftUI

public struct CustomSortMenu: View {
    @Binding var currentSort: AppSortOption

    public var body: some View {
        Menu {
            ForEach(AppSortOption.allCases) { opt in
                Button {
                    currentSort = opt
                } label: {
                    HStack {
                        Image(systemName: opt.icon)
                        Text(opt.rawValue)
                        if currentSort == opt {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: currentSort.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(currentSort.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
