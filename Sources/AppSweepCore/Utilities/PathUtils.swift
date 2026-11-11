import Foundation
import CoreServices

public enum PathUtils {
    public static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    public static var userLibrary: URL {
        homeDirectory.appendingPathComponent("Library")
    }

    /// Formats a URL path by replacing the user home path with `~` for concise display.
    public static func abbreviatingWithTilde(url: URL) -> String {
        let homePath = homeDirectory.path
        let fullPath = url.path
        if fullPath.hasPrefix(homePath) {
            let relative = fullPath.dropFirst(homePath.count)
            return "~" + relative
        }
        return fullPath
    }

    /// Retrieves file or bundle size quickly via macOS Spotlight metadata if available,
    /// falling back to recursive directory enumeration.
    public static func fastSize(of url: URL) -> Int64 {
        if let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
           let size = MDItemCopyAttribute(item, kMDItemFSSize) as? Int64, size > 0 {
            return size
        }
        return calculateSize(of: url)
    }

    /// Recursively calculates the byte size of a file or directory.
    public static func calculateSize(of url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    /// Checks if a file or directory is safe to move to trash.
    /// Strictly protects critical system directories, user personal data directories,
    /// and ensures only approved residual locations or application bundles can be deleted.
    public static func isSafeToDelete(url: URL) -> Bool {
        let normalized = url.standardizedFileURL.path

        // Disallow root and empty paths
        guard normalized != "/" && normalized.hasPrefix("/") else {
            return false
        }

        // 1. Prohibited Root and System Directories
        let prohibitedExactPaths: Set<String> = [
            "/", "/Applications", "/System", "/Library", "/usr", "/bin", "/sbin", "/private",
            "/var", "/tmp", "/etc", "/Users", "/opt", "/Volumes",
            homeDirectory.path,
            userLibrary.path,
            userLibrary.appendingPathComponent("Application Support").path,
            userLibrary.appendingPathComponent("Caches").path,
            userLibrary.appendingPathComponent("Preferences").path,
            userLibrary.appendingPathComponent("Containers").path,
            userLibrary.appendingPathComponent("Group Containers").path,
            userLibrary.appendingPathComponent("Saved Application State").path,
            userLibrary.appendingPathComponent("Logs").path,
            userLibrary.appendingPathComponent("LaunchAgents").path,
            userLibrary.appendingPathComponent("WebKit").path,
            userLibrary.appendingPathComponent("HTTPStorages").path
        ]

        if prohibitedExactPaths.contains(normalized) {
            return false
        }

        // Prohibit all system core directories
        let prohibitedSystemPrefixes = [
            "/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/var",
            "/Library/Apple", "/Library/Preferences", "/Library/Extensions",
            "/Library/SystemExtensions", "/Library/Security"
        ]
        for prefix in prohibitedSystemPrefixes {
            if normalized == prefix || normalized.hasPrefix(prefix + "/") {
                return false
            }
        }

        // 2. Strict Protection for User Personal Folders
        // AppSweep must NEVER delete user personal documents, desktop files, downloads, code or developer files!
        let protectedUserFolders = [
            "Desktop", "Documents", "Downloads", "Pictures", "Music", "Movies",
            "Developer", ".ssh", ".config", ".gnupg", ".aws", ".git", ".profile",
            ".zshrc", ".bashrc", ".bash_profile", "Public"
        ]
        let homePrefix = homeDirectory.path + "/"
        for folder in protectedUserFolders {
            let fullFolderPath = homePrefix + folder
            if normalized == fullFolderPath || normalized.hasPrefix(fullFolderPath + "/") {
                return false
            }
        }

        // 3. Protected macOS User Library Subdirectories
        let protectedSystemSubdirs = [
            "Keychains", "Accounts", "AddressBook", "CallHistoryDB", "CallHistoryTransactions",
            "CloudDocs", "CoreSimulator", "Developer", "FontCollections", "Fonts",
            "IdentityServices", "Keyboard", "Messages", "Photos", "Safari",
            "PersonalizationPortrait", "HomeKit", "Reminders", "Notes", "Mail",
            "Calendar", "CoreData", "Biome", "Spotlight", "Suggestions"
        ]

        let appSupportPrefix = userLibrary.appendingPathComponent("Application Support").path + "/"
        for protected in protectedSystemSubdirs {
            let protectedPath = appSupportPrefix + protected
            if normalized == protectedPath || normalized.hasPrefix(protectedPath + "/") {
                return false
            }
        }

        // 4. Allowed Deletion Domains Allowlist
        // Any deleted file MUST reside within authorized application or library residual folders:
        let isApplicationBundle = normalized.hasSuffix(".app") && (
            normalized.hasPrefix("/Applications/") ||
            normalized.hasPrefix(homeDirectory.path + "/Applications/") ||
            normalized.hasPrefix("/Users/")
        )

        let isApprovedUserLibraryResidual = normalized.hasPrefix(userLibrary.path + "/") && (
            normalized.hasPrefix(userLibrary.appendingPathComponent("Application Support").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("Caches").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("Preferences").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("Containers").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("Group Containers").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("Saved Application State").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("Logs").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("LaunchAgents").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("WebKit").path + "/") ||
            normalized.hasPrefix(userLibrary.appendingPathComponent("HTTPStorages").path + "/")
        )

        let isApprovedSharedLibraryResidual = normalized.hasPrefix("/Library/") && (
            normalized.hasPrefix("/Library/Application Support/") ||
            normalized.hasPrefix("/Library/Caches/") ||
            normalized.hasPrefix("/Library/LaunchAgents/") ||
            normalized.hasPrefix("/Library/LaunchDaemons/")
        )

        guard isApplicationBundle || isApprovedUserLibraryResidual || isApprovedSharedLibraryResidual else {
            return false
        }

        return true
    }
}
