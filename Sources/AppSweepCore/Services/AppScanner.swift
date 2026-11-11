import Foundation
import AppKit
import CoreServices

public actor AppScanner {
    public init() {}

    /// Scans standard application directories and Spotlight metadata, returning all detected AppInfo list.
    public func scanInstalledApplications() async -> [AppInfo] {
        var results: [AppInfo] = []
        var seenBundleIDs: Set<String> = []
        var seenURLs: Set<URL> = []

        let searchDirs: [(url: URL, isSystem: Bool)] = [
            (URL(fileURLWithPath: "/Applications"), false),
            (PathUtils.homeDirectory.appendingPathComponent("Applications"), false),
            (URL(fileURLWithPath: "/System/Applications"), true),
            (URL(fileURLWithPath: "/System/Library/CoreServices/Applications"), true)
        ]

        let fileManager = FileManager.default

        // 1. Scan standard top-level application directories
        for (dirURL, isSystem) in searchDirs {
            guard fileManager.fileExists(atPath: dirURL.path) else { continue }

            let contents = (try? fileManager.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for fileURL in contents {
                if fileURL.pathExtension == "app" {
                    if let appInfo = parseApp(at: fileURL, isSystemDir: isSystem) {
                        if !seenURLs.contains(fileURL) {
                            seenURLs.insert(fileURL)
                            if !appInfo.bundleIdentifier.isEmpty {
                                seenBundleIDs.insert(appInfo.bundleIdentifier.lowercased())
                            }
                            results.append(appInfo)
                        }
                    }
                } else {
                    // Check subdirectories (e.g. /Applications/Utilities/*.app, /Applications/Xcode.app, etc.)
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        let subContents = (try? fileManager.contentsOfDirectory(
                            at: fileURL,
                            includingPropertiesForKeys: [.contentModificationDateKey],
                            options: [.skipsHiddenFiles]
                        )) ?? []
                        for subURL in subContents where subURL.pathExtension == "app" {
                            if let appInfo = parseApp(at: subURL, isSystemDir: isSystem) {
                                if !seenURLs.contains(subURL) {
                                    seenURLs.insert(subURL)
                                    if !appInfo.bundleIdentifier.isEmpty {
                                        seenBundleIDs.insert(appInfo.bundleIdentifier.lowercased())
                                    }
                                    results.append(appInfo)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2. Discover system-wide applications via Spotlight MDQuery to catch non-standard paths (Discord, Setapp, etc.)
        let query = MDQueryCreate(kCFAllocatorDefault, "kMDItemContentType == \"com.apple.application-bundle\"" as CFString, nil, nil)
        MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        let count = MDQueryGetResultCount(query)

        for i in 0..<count {
            guard let rawResult = MDQueryGetResultAtIndex(query, i) else { continue }
            let mdItem = unsafeBitCast(rawResult, to: MDItem.self)
            guard let rawPath = MDItemCopyAttribute(mdItem, kMDItemPath) as? String else { continue }
            let fileURL = URL(fileURLWithPath: rawPath)

            // Skip if already parsed
            if seenURLs.contains(fileURL) { continue }

            if Self.shouldSkipSpotlightPath(rawPath) { continue }

            if let appInfo = parseApp(at: fileURL) {
                seenURLs.insert(fileURL)
                if !appInfo.bundleIdentifier.isEmpty {
                    seenBundleIDs.insert(appInfo.bundleIdentifier.lowercased())
                }
                results.append(appInfo)
            }
        }

        // Sort by size descending by default
        return results.sorted { $0.size > $1.size }
    }

    /// Spotlight also returns helper apps embedded in other bundles, apps in the Trash,
    /// on mounted disk images and inside SDKs — none of which the user can uninstall on their own.
    static func shouldSkipSpotlightPath(_ path: String) -> Bool {
        let parent = (path as NSString).deletingLastPathComponent
        if parent.contains(".app/") || parent.hasSuffix(".app") { return true }
        let skippedFragments = ["/.Trash/", "/.Trashes/", "/Developer/Platforms/", "/usr/local/", "/Library/Developer/"]
        if skippedFragments.contains(where: path.contains) { return true }
        return path.hasPrefix("/Volumes/") || path.hasPrefix("/private/") || path.hasPrefix("/Library/Apple/")
    }

    /// Parses an application at a specific file URL.
    public func parseApp(at url: URL, isSystemDir: Bool? = nil) -> AppInfo? {
        guard let bundle = Bundle(url: url) else { return nil }

        let bundleIdentifier = bundle.bundleIdentifier ?? ""
        let isSystem = isSystemDir ?? (
            url.path.hasPrefix("/System/") ||
            bundleIdentifier.starts(with: "com.apple.") && url.path.hasPrefix("/Applications/Safari.app")
        )

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? ""

        let executableName = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        let executableURL = bundle.executableURL

        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        // Extract Spotlight metadata (size, last used, install date)
        var lastUsedDate: Date? = nil
        var installDate: Date? = modDate
        var size: Int64 = 0

        if let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) {
            lastUsedDate = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) as? Date
            if let added = MDItemCopyAttribute(mdItem, kMDItemDateAdded) as? Date {
                installDate = added
            }
            if let mdSize = MDItemCopyAttribute(mdItem, kMDItemFSSize) as? Int64, mdSize > 0 {
                size = mdSize
            }
        }

        if size == 0 {
            size = PathUtils.fastSize(of: url)
        }

        let arch = detectArchitecture(for: executableURL)

        return AppInfo(
            name: displayName,
            bundleIdentifier: bundleIdentifier,
            url: url,
            version: version,
            size: size,
            lastModified: modDate,
            installDate: installDate,
            lastUsedDate: lastUsedDate,
            architecture: arch,
            isSystemApp: isSystem,
            executableName: executableName
        )
    }

    private func detectArchitecture(for executableURL: URL?) -> String {
        guard let url = executableURL,
              let handle = try? FileHandle(forReadingFrom: url) else {
            return "Universal"
        }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8), data.count >= 4 else {
            return "Universal"
        }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        if magic == 0xbebafeca || magic == 0xcafebabe {
            return "Universal"
        }
        if magic == 0xcffaedfe || magic == 0xfeedfacf {
            let cpuType = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
            if cpuType == 0x0100000c || cpuType == 0x0c000001 {
                return "Apple Silicon"
            } else {
                return "Intel"
            }
        }
        return "Universal"
    }
}
