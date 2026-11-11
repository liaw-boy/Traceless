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
        var needsPrivilege: [ResidualItem] = []

        func recordFailure(_ item: ResidualItem) {
            failedCount += 1
            failedItems.append(item)
            if item.category == .containers || item.category == .groupContainers {
                hasPermissionError = true
                errors.append("無法移除沙盒容器（\(item.name)）：受 macOS 隱私保護，需要「完全取用磁碟」權限。")
            } else {
                errors.append("無法移至垃圾桶（\(item.name)）：權限不足或檔案正被使用。")
            }
        }

        for item in itemsToTrash {
            guard PathUtils.isSafeToDelete(url: item.url) else {
                failedCount += 1
                errors.append("路徑受到系統保護，已略過：\(item.path)")
                failedItems.append(item)
                continue
            }

            // Already gone (e.g. removed together with its parent folder): nothing to do.
            guard fileManager.fileExists(atPath: item.url.path) || isSymlink(item.url) else {
                continue
            }

            do {
                // Tier 1: official Trash API (supports "Put Back" in Finder).
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                trashedCount += 1
                freedBytes += item.size
            } catch {
                do {
                    // Tier 2: plain move into ~/.Trash with a non-clobbering name.
                    try fileManager.moveItem(at: item.url, to: Self.uniqueTrashURL(for: item.url, in: trashDir))
                    trashedCount += 1
                    freedBytes += item.size
                } catch {
                    // Files inside the home folder are user-owned; root cannot bypass TCC there,
                    // so only system locations (/Applications, /Library) get the admin fallback.
                    if item.url.path.hasPrefix(PathUtils.homeDirectory.path + "/") {
                        recordFailure(item)
                    } else {
                        needsPrivilege.append(item)
                    }
                }
            }
        }

        // Tier 3: one administrator prompt for every remaining item (root-owned files).
        if !needsPrivilege.isEmpty {
            var reserved = Set<String>()
            let pairs = needsPrivilege.map { item -> (URL, URL) in
                let dst = Self.uniqueTrashURL(for: item.url, in: trashDir, reserved: reserved)
                reserved.insert(dst.path)
                return (item.url, dst)
            }
            runPrivileged(Self.privilegedMoveScript(pairs))
            for item in needsPrivilege {
                if !fileManager.fileExists(atPath: item.url.path) && !isSymlink(item.url) {
                    trashedCount += 1
                    freedBytes += item.size
                } else {
                    recordFailure(item)
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

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }

    /// Returns a URL in `trashDir` that does not collide with an existing item.
    static func uniqueTrashURL(
        for source: URL,
        in trashDir: URL,
        reserved: Set<String> = [],
        fileManager: FileManager = .default
    ) -> URL {
        func taken(_ url: URL) -> Bool { reserved.contains(url.path) || fileManager.fileExists(atPath: url.path) }
        let name = source.lastPathComponent
        var candidate = trashDir.appendingPathComponent(name)
        guard taken(candidate) else { return candidate }
        let ext = source.pathExtension
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        var n = 2
        repeat {
            let numbered = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = trashDir.appendingPathComponent(numbered)
            n += 1
        } while taken(candidate)
        return candidate
    }

    /// Builds an AppleScript that moves every pair with root privileges.
    /// Paths are passed through `quoted form of` so the shell never interprets them.
    static func privilegedMoveScript(_ pairs: [(URL, URL)]) -> String {
        func literal(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let commands = pairs.map { src, dst in
            "\"/bin/mv -n -- \" & quoted form of \(literal(src.path)) & \" \" & quoted form of \(literal(dst.path))"
        }
        return "do shell script (" + commands.joined(separator: " & \" ; \" & ") + ") with administrator privileges"
    }

    /// Runs the script through osascript (no shell; NSAppleScript is not safe off the main thread).
    private func runPrivileged(_ source: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
    }
}
