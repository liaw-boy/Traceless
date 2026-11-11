import Foundation
import AppKit

public struct UninstallResult: Sendable {
    public let trashedCount: Int
    public let failedCount: Int
    public let freedBytes: Int64
    public let errors: [String]
    public let hasPermissionError: Bool
    public let failedItems: [ResidualItem]

    public init(
        trashedCount: Int,
        failedCount: Int,
        freedBytes: Int64,
        errors: [String] = [],
        hasPermissionError: Bool = false,
        failedItems: [ResidualItem] = []
    ) {
        self.trashedCount = trashedCount
        self.failedCount = failedCount
        self.freedBytes = freedBytes
        self.errors = errors
        self.hasPermissionError = hasPermissionError
        self.failedItems = failedItems
    }

    public var formattedFreedBytes: String {
        FileSizeFormatter.format(freedBytes)
    }

    public var isSuccess: Bool {
        failedCount == 0 && trashedCount > 0
    }
}

public actor Uninstaller {
    private let fileManager = FileManager.default

    public init() {}

    /// Safely terminates running instances of an application if requested.
    public func terminateAppIfRunning(bundleIdentifier: String) async -> Bool {
        guard !bundleIdentifier.isEmpty else { return true }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !running.isEmpty else { return true }

        for app in running {
            app.terminate()
        }

        // Wait up to 2 seconds for graceful quit
        let start = Date()
        while Date().timeIntervalSince(start) < 2.0 {
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            if stillRunning.isEmpty {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Force terminate if still running
        let stubborn = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        for app in stubborn {
            app.forceTerminate()
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Moves selected residual items to the macOS Trash using multi-tier fallback.
    public func uninstall(
        items: [ResidualItem],
        appBundleIdentifier: String? = nil,
        quitIfRunning: Bool = true
    ) async -> UninstallResult {
        if quitIfRunning, let bundleId = appBundleIdentifier, !bundleId.isEmpty {
            _ = await terminateAppIfRunning(bundleIdentifier: bundleId)
        }

        var trashedCount = 0
        var failedCount = 0
        var freedBytes: Int64 = 0
        var errors: [String] = []
        var hasPermissionError = false
        var failedItems: [ResidualItem] = []

        let itemsToTrash = items.filter { $0.isSelected && !$0.isProtected }
        let trashDir = PathUtils.homeDirectory.appendingPathComponent(".Trash")

        for item in itemsToTrash {
            guard PathUtils.isSafeToDelete(url: item.url) else {
                failedCount += 1
                errors.append("路徑受到系統保護，已略過: \(item.path)")
                failedItems.append(item)
                continue
            }

            guard fileManager.fileExists(atPath: item.url.path) else {
                continue
            }

            // Tier 1: Standard macOS trashItem API
            var moved = false
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &resultingURL)
                moved = true
            } catch {
                // Tier 2: Try direct move into ~/.Trash
                let targetURL = trashDir.appendingPathComponent(item.url.lastPathComponent)
                do {
                    // If target already exists in trash, append timestamp
                    let uniqueTargetURL: URL
                    if fileManager.fileExists(atPath: targetURL.path) {
                        let timestamp = Int(Date().timeIntervalSince1970)
                        uniqueTargetURL = trashDir.appendingPathComponent("\(item.url.deletingPathExtension().lastPathComponent)_\(timestamp).\(item.url.pathExtension)")
                    } else {
                        uniqueTargetURL = targetURL
                    }

                    try fileManager.moveItem(at: item.url, to: uniqueTargetURL)
                    moved = true
                } catch {
                    // Tier 3: Privileged Administrator Escalation
                    moved = performPrivilegedMoveToTrash(source: item.url, trashDir: trashDir)
                }
            }

            if moved {
                trashedCount += 1
                freedBytes += item.size
            } else {
                failedCount += 1
                failedItems.append(item)

                if item.url.path.contains("/Library/Containers") || item.category == .containers {
                    hasPermissionError = true
                    errors.append("無法清理沙盒容器 (\(item.name))：受 macOS TCC 機制保護，需要「完全取用磁碟」權限。")
                } else {
                    errors.append("無法移至垃圾桶 (\(item.name))：權限不足或檔案被系統鎖定。")
                }
            }
        }

        return UninstallResult(
            trashedCount: trashedCount,
            failedCount: failedCount,
            freedBytes: freedBytes,
            errors: errors,
            hasPermissionError: hasPermissionError,
            failedItems: failedItems
        )
    }

    private func performPrivilegedMoveToTrash(source: URL, trashDir: URL) -> Bool {
        let dest = trashDir.appendingPathComponent(source.lastPathComponent).path
        let escapedSource = source.path.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedDest = dest.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"/bin/mv -f \\\"\(escapedSource)\\\" \\\"\(escapedDest)\\\"\" with administrator privileges"

        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let _ = appleScript.executeAndReturnError(&errorDict)
            return errorDict == nil
        }
        return false
    }
}
