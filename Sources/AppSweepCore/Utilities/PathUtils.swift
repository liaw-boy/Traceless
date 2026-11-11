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
    /// Rejects traversal, control characters and symlinked parents, then requires the path to be
    /// outside every protected location and inside an approved residual location.
    /// Comparisons are case-insensitive because APFS volumes usually are.
    public static func isSafeToDelete(url: URL) -> Bool {
        let raw = url.path
        guard raw.hasPrefix("/"),
              !raw.split(separator: "/").contains(".."),
              !raw.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return false
        }
        // Resolve symlinks in the parent so "~/Library/Caches/x -> ~/Documents" style tricks on a parent
        // folder are judged by where they really point. The item itself may be a symlink: trashing moves the link.
        let standardized = url.standardizedFileURL
        let resolvedParent = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
        let resolved = resolvedParent.appendingPathComponent(standardized.lastPathComponent).path
        return isAllowed(standardized.path) && isAllowed(resolved)
    }

    private static func isAllowed(_ path: String) -> Bool {
        let p = path.lowercased()
        let home = homeDirectory.path.lowercased()
        let lib = home + "/library"
        guard p != "/" && p.hasPrefix("/") else { return false }

        func within(_ base: String) -> Bool { p == base || p.hasPrefix(base + "/") }
        func strictlyWithin(_ base: String) -> Bool { p.hasPrefix(base + "/") }

        // 1. Never the roots themselves.
        let rootFolders = ["/", "/applications", "/system", "/library", "/usr", "/bin", "/sbin", "/private",
                           "/var", "/tmp", "/etc", "/users", "/opt", "/volumes", home, lib]
        if rootFolders.contains(p) { return false }

        // 2. Never inside OS-owned trees.
        let systemTrees = ["/system", "/usr", "/bin", "/sbin", "/etc", "/private", "/var",
                           "/library/apple", "/library/preferences", "/library/extensions",
                           "/library/systemextensions", "/library/security", "/library/keychains"]
        if systemTrees.contains(where: within) { return false }

        // 3. Never personal data or credentials in the home folder.
        let personal = ["desktop", "documents", "downloads", "pictures", "music", "movies", "public",
                        "developer", ".ssh", ".config", ".gnupg", ".aws", ".git", ".profile",
                        ".zshrc", ".bashrc", ".bash_profile", ".trash"]
        if personal.contains(where: { within(home + "/" + $0) }) { return false }

        // 4. Never Apple's own data stores under Application Support.
        let appleStores = ["keychains", "accounts", "addressbook", "callhistorydb", "callhistorytransactions",
                           "clouddocs", "coresimulator", "developer", "fontcollections", "fonts",
                           "identityservices", "keyboard", "messages", "photos", "safari",
                           "personalizationportrait", "homekit", "reminders", "notes", "mail",
                           "calendar", "coredata", "biome", "spotlight", "suggestions", "mobilesync",
                           "knowledge", "com.apple.sharedfilelist", "com.apple.tcc"]
        if appleStores.contains(where: { within(lib + "/application support/" + $0) }) { return false }
        if within(lib + "/keychains") || within(lib + "/mail") || within(lib + "/messages") { return false }

        // 5. Must be a direct-or-deeper child of an approved location (never the location itself).
        let userResidualRoots = ["application support", "application scripts",
                                 "caches", "preferences", "containers", "group containers",
                                 "saved application state", "logs", "launchagents", "webkit",
                                 "httpstorages", "cookies"]
        if userResidualRoots.contains(where: { within(lib + "/" + $0) && !(p == lib + "/" + $0) }) {
            return true
        }
        let sharedResidualRoots = ["/library/application support", "/library/caches", "/library/logs",
                                   "/library/launchagents", "/library/launchdaemons",
                                   "/library/privilegedhelpertools"]
        if sharedResidualRoots.contains(where: strictlyWithin) { return true }

        // App bundles: only in the standard application folders.
        if p.hasSuffix(".app") && (strictlyWithin("/applications") || strictlyWithin(home + "/applications")) {
            return true
        }
        return false
    }

    /// A name taken from an app's Info.plist is only used as a path component if it cannot escape
    /// its parent folder (e.g. a hostile CFBundleIdentifier of "../../Documents").
    public static func isSafePathComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains(":")
            && !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }
}
