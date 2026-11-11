import Foundation
import AppKit

public struct AppInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String
    public let url: URL
    public let version: String
    public var size: Int64
    public let lastModified: Date?
    public let installDate: Date?
    public let lastUsedDate: Date?
    public let architecture: String
    public let isSystemApp: Bool
    public let executableName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        url: URL,
        version: String,
        size: Int64 = 0,
        lastModified: Date? = nil,
        installDate: Date? = nil,
        lastUsedDate: Date? = nil,
        architecture: String = "Universal",
        isSystemApp: Bool = false,
        executableName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.version = version
        self.size = size
        self.lastModified = lastModified
        self.installDate = installDate
        self.lastUsedDate = lastUsedDate
        self.architecture = architecture
        self.isSystemApp = isSystemApp
        self.executableName = executableName
    }

    public var formattedSize: String {
        FileSizeFormatter.format(size)
    }

    public var isRunning: Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    public var lastUsedDescription: String {
        guard let date = lastUsedDate else { return "從未開啟" }
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 0 { return "剛剛" }
        let days = Int(interval / 86400)
        if days == 0 { return "今天" }
        if days == 1 { return "昨天" }
        if days < 7 { return "\(days) 天前" }
        if days < 30 { return "\(max(1, days / 7)) 週前" }
        if days < 365 { return "\(max(1, days / 30)) 個月前" }
        return "超過 1 年未使用"
    }

    public var isUnusedOver3Months: Bool {
        guard let date = lastUsedDate else { return true }
        return Date().timeIntervalSince(date) > 90 * 86400
    }

    /// Icons are cached per bundle path: SwiftUI re-evaluates rows often and
    /// NSWorkspace.icon(forFile:) hits the disk every call.
    public func icon(size: CGFloat = 64) -> NSImage {
        let key = url.path as NSString
        if let cached = AppIconCache.shared.object(forKey: key) { return cached }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        AppIconCache.shared.setObject(img, forKey: key)
        return img
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.url == rhs.url
    }
}

private enum AppIconCache {
    nonisolated(unsafe) static let shared = NSCache<NSString, NSImage>()
}
