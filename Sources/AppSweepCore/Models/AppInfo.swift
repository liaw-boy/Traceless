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
        guard let date = lastUsedDate else { return "沒有開啟紀錄" }
        let days = Int(Date().timeIntervalSince(date) / 86400)
        switch days {
        case ..<1: return "今天開啟過"
        case 1: return "昨天開啟過"
        case 2..<7: return "\(days) 天前開啟"
        case 7..<30: return "\(days / 7) 週前開啟"
        case 30..<365: return "\(days / 30) 個月前開啟"
        default: return "超過一年未開啟"
        }
    }

    /// Never-opened apps count from their install date, so a fresh install is not "unused".
    public var isUnusedOver3Months: Bool {
        guard let reference = lastUsedDate ?? installDate ?? lastModified else { return true }
        return Date().timeIntervalSince(reference) > 90 * 86400
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
