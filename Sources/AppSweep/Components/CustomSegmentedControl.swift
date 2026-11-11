import SwiftUI

public struct CustomSegmentedControl: View {
    @Binding var selected: AppFilterMode
    @Namespace private var animation

    public init(selected: Binding<AppFilterMode>) {
        self._selected = selected
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(AppFilterMode.allCases) { mode in
                let isSelected = selected == mode
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selected = mode
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppTheme.accent)
                                    .matchedGeometryEffect(id: "FILTER_PILL", in: animation)
                                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 4, y: 1)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}
