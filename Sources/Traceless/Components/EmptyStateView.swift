import SwiftUI

/// Empty and result states share the brand mark, drawn quietly in the muted tone.
struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            TraceMark(size: 54, color: Palette.muted.opacity(0.45))
            VStack(spacing: 5) {
                Text(title)
                    .font(.display(17))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(title: String, message: String) {
        self.init(title: title, message: message, actions: { EmptyView() })
    }
}
