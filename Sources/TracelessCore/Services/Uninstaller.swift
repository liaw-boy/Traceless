import Foundation
import AppKit

public struct UninstallResult: Sendable {
    public let trashedCount: Int
    public let failedCount: Int
    public let freedBytes: Int64
    public let errors: [String]
    public let hasPermissionError: Bool
    public let failedItems: [ResidualItem]
    /// A kernel extension was removed; it stays loaded until the Mac restarts.
    public var needsRestart = false

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

        // Never force-quit: an app showing "save changes?" would lose the user's work.
        let start = Date()
        while Date().timeIntervalSince(start) < 5.0 {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return false
    }

    /// Moves selected residual items to the macOS Trash using multi-tier fallback.
    public func uninstall(
        items: [ResidualItem],
        appBundleIdentifier: String? = nil,
        quitIfRunning: Bool = true
    ) async -> UninstallResult {
        if quitIfRunning, let bundleId = appBundleIdentifier, !bundleId.isEmpty {
            guard await terminateAppIfRunning(bundleIdentifier: bundleId) else {
                return UninstallResult(trashedCount: 0, failedCount: 0, freedBytes: 0,
                                       errors: ["App 仍在執行（可能有未儲存的文件），請先手動結束再試一次"])
            }
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
                    if item.url.path.hasPrefix(PathUtils.homeDirectory.path + "/") || !Self.hasRootOnlyAncestors(item.url) {
                        recordFailure(item)
                    } else {
                        needsPrivilege.append(item)
                    }
                }
            }
        }

        // Tier 3: one administrator prompt for every remaining item (root-owned files).
        if !needsPrivilege.isEmpty && !Self.isRealUserDirectory(trashDir) {
            needsPrivilege.forEach(recordFailure)
            needsPrivilege = []
        }
        if !needsPrivilege.isEmpty {
            var reserved = Set<String>()
            let pairs = needsPrivilege.map { item -> (URL, URL) in
                let dst = Self.uniqueTrashURL(for: item.url, in: trashDir, reserved: reserved)
                reserved.insert(dst.path)
                return (item.url, dst)
            }
            let removesAudioDriver = needsPrivilege.contains { $0.category == .audioPlugins }
            runPrivileged(Self.privilegedMoveScript(pairs, restartAudio: removesAudioDriver))
            for item in needsPrivilege {
                if !fileManager.fileExists(atPath: item.url.path) && !isSymlink(item.url) {
                    trashedCount += 1
                    freedBytes += item.size
                } else {
                    recordFailure(item)
                }
            }
        }

        var result = UninstallResult(
            trashedCount: trashedCount,
            failedCount: failedCount,
            freedBytes: freedBytes,
            errors: errors,
            hasPermissionError: hasPermissionError,
            failedItems: failedItems
        )
        result.needsRestart = itemsToTrash.contains {
            $0.category == .kernelExtensions && !fileManager.fileExists(atPath: $0.url.path)
        }
        return result
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }

    /// Root may only move an item if no ancestor folder could be swapped for a symlink by a non-admin
    /// process between our check and the move: every ancestor must be a real directory owned by root
    /// (admin group write is accepted) and not world-writable.
    static func hasRootOnlyAncestors(_ url: URL) -> Bool {
        var dir = url.deletingLastPathComponent().path
        while true {
            var st = stat()
            guard lstat(dir, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR, st.st_uid == 0,
                  st.st_mode & S_IWOTH == 0 else { return false }
            if dir == "/" { return true }
            dir = (dir as NSString).deletingLastPathComponent
        }
    }

    /// The Trash must be a real directory owned by the current user (not a planted symlink).
    static func isRealUserDirectory(_ url: URL) -> Bool {
        var st = stat()
        return lstat(url.path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR && st.st_uid == getuid()
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
    /// `restartAudio` restarts coreaudiod afterwards so a removed virtual audio device disappears from
    /// the Sound menu immediately (launchd relaunches it within a second).
    static func privilegedMoveScript(_ pairs: [(URL, URL)], restartAudio: Bool = false) -> String {
        func literal(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        var commands = pairs.map { src, dst in
            "\"/bin/mv -n -h -- \" & quoted form of \(literal(src.path)) & \" \" & quoted form of \(literal(dst.path))"
        }
        if restartAudio {
            commands.append("\"/usr/bin/killall coreaudiod\"")
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
