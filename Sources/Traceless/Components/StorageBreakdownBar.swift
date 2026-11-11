import SwiftUI
import TracelessCore

/// The app's footprint shown as the recessed slot from the icon, filled in proportion to
/// where its bytes live. Legend entries double as the reading of the bar.
public struct StorageBreakdownBar: View {
    let items: [ResidualItem]

    private var segments: [(category: ResidualCategory, size: Int64)] {
        Dictionary(grouping: items, by: \.category)
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.size }) }
            .filter { $0.1 > 0 }
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    public var body: some View {
        let segments = self.segments
        let total = max(segments.reduce(0) { $0 + $1.size }, 1)
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                // Every segment gets a visible minimum; the rest is shared by size, so the sum always fits.
                let minWidth: CGFloat = 4
                let spare = max(0, geo.size.width - 6 - CGFloat(segments.count - 1) * 2 - minWidth * CGFloat(segments.count))
                HStack(spacing: 2) {
                    ForEach(segments, id: \.category) { seg in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(seg.category.tint)
                            .frame(width: minWidth + spare * CGFloat(seg.size) / CGFloat(total))
                            .help("\(seg.category.displayName)：\(FileSizeFormatter.format(seg.size))")
                    }
                    Spacer(minLength: 0)
                }
                .padding(3)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                .background(Palette.slot, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 0.5)
                )
            }
            .frame(height: 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("儲存空間分布")
            .accessibilityValue(segments.map { "\($0.category.displayName) \(FileSizeFormatter.format($0.size))" }.joined(separator: "，"))

            Legend(segments: segments)
        }
    }
}

private struct Legend: View {
    let segments: [(category: ResidualCategory, size: Int64)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { entries }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 4) { entries }
        }
    }

    @ViewBuilder private var entries: some View {
        ForEach(segments, id: \.category) { seg in
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(seg.category.tint).frame(width: 8, height: 8)
                Text(seg.category.displayName)
                    .foregroundStyle(Palette.muted)
                Text(FileSizeFormatter.format(seg.size))
                    .font(.display(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .font(.system(size: 12))
            .fixedSize()
        }
    }
}
