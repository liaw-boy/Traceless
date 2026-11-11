import SwiftUI
import AppSweepCore

public struct StorageBreakdownBar: View {
    public let items: [ResidualItem]

    public init(items: [ResidualItem]) {
        self.items = items
    }

    private var totalBytes: Int64 {
        max(1, items.reduce(0) { $0 + $1.size })
    }

    private var categorySizes: [(category: ResidualCategory, size: Int64, percentage: Double)] {
        var dict: [ResidualCategory: Int64] = [:]
        for item in items {
            dict[item.category, default: 0] += item.size
        }
        let total = Double(totalBytes)
        return dict.compactMap { cat, size in
            guard size > 0 else { return nil }
            return (category: cat, size: size, percentage: Double(size) / total)
        }.sorted { $0.size > $1.size }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Visual Segmented Bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(categorySizes, id: \.category) { item in
                        let width = max(4, geo.size.width * CGFloat(item.percentage))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: item.category))
                            .frame(width: width, height: 8)
                            .help("\(item.category.displayName): \(FileSizeFormatter.format(item.size)) (\(Int(item.percentage * 100))%)")
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .background(Color.white.opacity(0.06))

            // Legend Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categorySizes.prefix(5), id: \.category) { item in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(color(for: item.category))
                                .frame(width: 6, height: 6)
                            Text(item.category.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(FileSizeFormatter.format(item.size))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func color(for category: ResidualCategory) -> Color {
        switch category {
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
