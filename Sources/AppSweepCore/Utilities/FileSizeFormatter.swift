import Foundation

public enum FileSizeFormatter {
    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter
    }()

    public static func format(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        return byteCountFormatter.string(fromByteCount: bytes)
    }
}
