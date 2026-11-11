import SwiftUI
import TracelessCore

/// Proportional bar of where an app's disk usage lives, with a compact legend.
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
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(segments, id: \.category) { seg in
                        Rectangle()
                            .fill(seg.category.tint)
                            .frame(width: max(2, geo.size.width * CGFloat(seg.size) / CGFloat(total)))
                            .help("\(seg.category.displayName)：\(FileSizeFormatter.format(seg.size))")
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("儲存空間分布")
            .accessibilityValue(segments.map { "\($0.category.displayName) \(FileSizeFormatter.format($0.size))" }.joined(separator: "，"))

            FlowLegend(segments: segments)
        }
    }
}

private struct FlowLegend: View {
    let segments: [(category: ResidualCategory, size: Int64)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { entries }
            VStack(alignment: .leading, spacing: 4) { entries }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var entries: some View {
        ForEach(segments, id: \.category) { seg in
            HStack(spacing: 5) {
                Circle().fill(seg.category.tint).frame(width: 7, height: 7)
                Text(seg.category.displayName)
                Text(FileSizeFormatter.format(seg.size)).monospacedDigit()
            }
            .fixedSize()
        }
    }
}
