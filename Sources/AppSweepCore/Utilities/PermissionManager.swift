import Foundation
import AppKit

public enum PermissionManager {
    /// Checks whether the application has been granted Full Disk Access (FDA).
    /// Probes known TCC-protected paths that fail with EPERM when FDA is not granted.
    public static var hasFullDiskAccess: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let testPaths = [
            home.appendingPathComponent("Library/Safari/Bookmarks.plist").path,
            home.appendingPathComponent("Library/Suggestions").path,
            home.appendingPathComponent("Library/Containers/com.apple.mail").path
        ]

        for path in testPaths {
            let fd = open(path, O_RDONLY)
            if fd != -1 {
                close(fd)
                return true
            }
            if errno == EPERM || errno == EACCES {
                return false
            }
        }
        return false
    }

    /// Opens macOS System Settings directly to Privacy & Security > Full Disk Access.
    public static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
