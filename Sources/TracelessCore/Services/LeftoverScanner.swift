import Foundation
import AppKit

public enum LeftoverSortOption: String, CaseIterable, Identifiable, Sendable {
    case sizeDesc = "容量 (大到小)"
    case sizeAsc = "容量 (小到大)"
    case name = "名稱 (A-Z)"
    case itemCount = "項目數 (多到少)"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .sizeDesc: return "arrow.down.circle"
        case .sizeAsc: return "arrow.up.circle"
        case .name: return "textformat"
        case .itemCount: return "number"
        }
    }
}

public enum LeftoverFilterMode: String, CaseIterable, Identifiable, Sendable {
    case all = "全部"
    case large = "超過 50 MB"
    case containers = "容器"
    case caches = "快取"
    case preferences = "偏好設定"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .large: return "flame"
        case .containers: return "shippingbox"
        case .caches: return "bolt"
        case .preferences: return "slider.horizontal.3"
        }
    }
}

public struct LeftoverAppGroup: Identifiable, Sendable {
    public let id: String // Bundle ID or inferred name
    public let name: String
    public var items: [ResidualItem]

    public init(id: String, name: String, items: [ResidualItem]) {
        self.id = id
        self.name = name
        self.items = items
    }

    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSize: String {
        FileSizeFormatter.format(totalSize)
    }

    public var hasContainers: Bool {
        items.contains { $0.category == .containers }
    }

    public var hasCaches: Bool {
        items.contains { $0.category == .caches }
    }

    public var hasPreferences: Bool {
        items.contains { $0.category == .preferences }
    }
}

public actor LeftoverScanner {
    private let fileManager = FileManager.default

    public init() {}

    private let knownSystemIdentifiers: Set<String> = [
        "AddressBook", "Accounts", "Animoji", "App Store", "Apple", "Assistant",
        "CallHistoryDB", "CallHistoryTransactions", "CloudDocs", "CoreSimulator",
        "CrashReporter", "Developer", "DiagnosticReports", "DiskImages", "Dock",
        "FaceTime", "FileProvider", "Finder", "FontCollections", "Fonts",
        "GarageBand", "iCloud", "IdentityServices", "iLifeMediaBrowser", "Java",
        "Keyboard", "Keychains", "Knowledge", "Mail", "Messages", "MobileSync",
        "Music", "News", "Notes", "NotificationCenter", "Passes", "Photos",
        "Podcasts", "Quick Look", "Reminders", "Safari", "Screen Time",
        "Shortcuts", "Siri", "SyncServices", "TV", "VoiceMemos", "Weather",
        "WebKit", "HTTPStorages", "Preview", "TextInput", "System",
        "com.apple", "Biome", "HomeKit", "CoreData", "Spotlight", "Suggestions"
    ]

    static let recentUseInterval: TimeInterval = 30 * 86400

    static let genericNames: Set<String> = [
        "cache", "caches", "data", "logs", "log", "temp", "tmp", "backup", "backups", "config",
        "settings", "preferences", "support", "storage", "database", "crashreporter", "crashpad",
        "plugins", "extensions", "updates", "updater", "downloads", "default", "shared", "common",
        "helper", "agent", "service", "services", "launcher", "installer", "resources", "user",
        // Chromium/Electron internals that live inside an app's own folder.
        "codecache", "gpucache", "dawncache", "dawngraphitecache", "dawnwebgpucache", "grshadercache",
        "shadercache", "webstorage", "localstorage", "sessionstorage", "blobstorage", "indexeddb",
        "serviceworker", "cachedprofilesdata", "cacheddata", "shareddictionary", "networkpersistentstate"
    ]

    static let sensitiveKeywords = ["1password", "bitwarden", "lastpass", "dashlane", "keepass", "enpass",
                                    "keychain", "gnupg", "gpg", "ssh", "yubico", "authy", "wallet"]

    private lazy var lowercasedSystemIdentifiers = Set(knownSystemIdentifiers.map { $0.lowercased() })

    private let knownVendorDirectories: Set<String> = [
        "google", "microsoft", "adobe", "jetbrains", "mozilla", "bravesoftware",
        "apple", "steam", "cisco", "atlassian", "zoom", "wacom", "logitech",
        "razer", "corsair", "blackmagic design", "antigravity", "vmware",
        "oracle", "amazon", "dropbox", "spotify", "epic games", "ubisoft", "electronic arts"
    ]

    private let wellKnownAliases: [String: String] = [
        "code": "com.microsoft.VSCode",
        "discord": "com.hnc.Discord",
        "obs-studio": "com.obsproject.obs-studio",
        "bravesoftware": "com.brave.Browser",
        "steam": "com.valvesoftware.steam",
        "antigravity": "com.google.antigravity",
        "antigravity ide": "com.google.antigravity.ide",
        "docker desktop": "com.docker.docker",
        "coconutbattery": "com.coconut-flavour.coconutBattery",
        "stats": "eu.exelban.Stats",
        "droppy": "com.iordv.droppy",
        "kkbox": "com.kkbox.KKBOX",
        "openvpn connect": "net.openvpn.connect.mac",
        "iterm2": "com.googlecode.iterm2",
        "iterm": "com.googlecode.iterm2",
        "sublime text": "com.sublimetext.3",
        "sublime text 3": "com.sublimetext.3",
        "notion": "notion.id",
        "slack": "com.tinyspeck.slackmacgap",
        "telegram desktop": "ru.keepcoder.Telegram",
        "spotify": "com.spotify.client",
        "vlc": "org.videolan.vlc",
        "anki": "net.ankisrs.anki",
        "anki2": "net.ankisrs.anki",
        "obsidian": "md.obsidian",
        "vmware fusion": "com.vmware.fusion"
    ]

    /// Scans for residual files of apps that are no longer installed on the system.
    public func scanLeftovers(installedApps: [AppInfo]) async -> [LeftoverAppGroup] {
        var installedIDs = Set<String>()
        var installedNames = Set<String>()
        var normalizedInstalledNames = Set<String>()

        for app in installedApps {
            if !app.bundleIdentifier.isEmpty {
                installedIDs.insert(app.bundleIdentifier.lowercased())
            }
            let nameLower = app.name.lowercased()
            installedNames.insert(nameLower)
            normalizedInstalledNames.insert(sanitizeToken(nameLower))

            if let exec = app.executableName {
                let execLower = exec.lowercased()
                installedNames.insert(execLower)
                normalizedInstalledNames.insert(sanitizeToken(execLower))
            }

            let bundleName = app.url.deletingPathExtension().lastPathComponent.lowercased()
            installedNames.insert(bundleName)
            normalizedInstalledNames.insert(sanitizeToken(bundleName))
        }

        // Running processes count as installed (e.g. apps launched from a disk image or build folder).
        for running in NSWorkspace.shared.runningApplications {
            if let id = running.bundleIdentifier { installedIDs.insert(id.lowercased()) }
        }

        var candidateGroups: [String: (name: String, items: [ResidualItem])] = [:]
        let userLib = PathUtils.userLibrary

        func registerOrphan(groupKey: String, displayName: String, url: URL, category: ResidualCategory) {
            guard PathUtils.isSafeToDelete(url: url) else { return }
            let size = PathUtils.fastSize(of: url)
            guard size > 0 else { return }

            let item = ResidualItem(
                url: url,
                name: url.lastPathComponent,
                size: size,
                category: category,
                isSelected: false
            )

            if var group = candidateGroups[groupKey] {
                group.items.append(item)
                candidateGroups[groupKey] = group
            } else {
                candidateGroups[groupKey] = (name: displayName, items: [item])
            }
        }

        // 1. Saved Application State (.savedState)
        let stateDir = userLib.appendingPathComponent("Saved Application State")
        if let stateItems = try? fileManager.contentsOfDirectory(at: stateDir, includingPropertiesForKeys: nil) {
            for url in stateItems where url.pathExtension == "savedState" {
                let bundleId = url.deletingPathExtension().lastPathComponent
                if isOrphan(
                    candidate: bundleId,
                    candidateURL: url,
                    installedIDs: installedIDs,
                    installedNames: installedNames,
                    normalizedNames: normalizedInstalledNames
                ) {
                    registerOrphan(groupKey: bundleId, displayName: inferDisplayName(from: bundleId), url: url, category: .savedState)
                }
            }
        }

        // 2. Application Support
        let appSupportDir = userLib.appendingPathComponent("Application Support")
        if let appSupportItems = try? fileManager.contentsOfDirectory(at: appSupportDir, includingPropertiesForKeys: nil) {
            for url in appSupportItems {
                let name = url.lastPathComponent
                let nameLower = name.lowercased()

                // If it is a vendor directory, inspect child directories
                if knownVendorDirectories.contains(nameLower) {
                    // Some "vendor" folders are really one app's own data (Electron apps): if that app
                    // is installed, leave the whole folder alone.
                    let vendorToken = sanitizeToken(nameLower)
                    if normalizedInstalledNames.contains(vendorToken) || installedNames.contains(nameLower) { continue }
                    if let subItems = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                        for subURL in subItems {
                            let subName = subURL.lastPathComponent
                            if isOrphan(
                                candidate: subName,
                                candidateURL: subURL,
                                installedIDs: installedIDs,
                                installedNames: installedNames,
                                normalizedNames: normalizedInstalledNames
                            ) {
                                registerOrphan(groupKey: "\(name)/\(subName)", displayName: "\(subName)（\(name)）", url: subURL, category: .applicationSupport)
                            }
                        }
                    }
                    continue
                }

                if isOrphan(
                    candidate: name,
                    candidateURL: url,
                    installedIDs: installedIDs,
                    installedNames: installedNames,
                    normalizedNames: normalizedInstalledNames
                ) {
                    registerOrphan(groupKey: name, displayName: inferDisplayName(from: name), url: url, category: .applicationSupport)
                }
            }
        }

        // 3. Caches
        let cachesDir = userLib.appendingPathComponent("Caches")
        if let cacheItems = try? fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil) {
            for url in cacheItems {
                let name = url.lastPathComponent
                if isReverseDNS(name) && isOrphan(
                    candidate: name,
                    candidateURL: url,
                    installedIDs: installedIDs,
                    installedNames: installedNames,
                    normalizedNames: normalizedInstalledNames
                ) {
                    registerOrphan(groupKey: name, displayName: inferDisplayName(from: name), url: url, category: .caches)
                }
            }
        }

        // 4. Containers
        let containersDir = userLib.appendingPathComponent("Containers")
        if let containerItems = try? fileManager.contentsOfDirectory(at: containersDir, includingPropertiesForKeys: nil) {
            for url in containerItems {
                let name = url.lastPathComponent
                if isReverseDNS(name) && isOrphan(
                    candidate: name,
                    candidateURL: url,
                    installedIDs: installedIDs,
                    installedNames: installedNames,
                    normalizedNames: normalizedInstalledNames
                ) {
                    registerOrphan(groupKey: name, displayName: inferDisplayName(from: name), url: url, category: .containers)
                }
            }
        }

        // 5. Preferences (.plist)
        let prefsDir = userLib.appendingPathComponent("Preferences")
        if let prefItems = try? fileManager.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: nil) {
            for url in prefItems where url.pathExtension == "plist" {
                let name = url.deletingPathExtension().lastPathComponent
                if isReverseDNS(name) && isOrphan(
                    candidate: name,
                    candidateURL: url,
                    installedIDs: installedIDs,
                    installedNames: installedNames,
                    normalizedNames: normalizedInstalledNames
                ) {
                    registerOrphan(groupKey: name, displayName: inferDisplayName(from: name), url: url, category: .preferences)
                }
            }
        }

        // 6. Virtual audio drivers whose app is gone (they linger in the Sound menu).
        for halDir in [URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL"), userLib.appendingPathComponent("Audio/Plug-Ins/HAL")] {
            guard let drivers = try? fileManager.contentsOfDirectory(at: halDir, includingPropertiesForKeys: nil) else { continue }
            for driver in drivers where driver.pathExtension == "driver" {
                let driverId = Bundle(url: driver)?.bundleIdentifier ?? ""
                let name = driver.deletingPathExtension().lastPathComponent
                guard !driverId.isEmpty, !driverId.lowercased().hasPrefix("com.apple.") else { continue }
                let owned = installedApps.contains {
                    ResidualScanner.audioDriverBelongs(driverId: driverId, driverName: name, bundleId: $0.bundleIdentifier, appName: $0.name)
                }
                if !owned {
                    registerOrphan(groupKey: driverId, displayName: name, url: driver, category: .audioPlugins)
                }
            }
        }

        return candidateGroups.map { key, val in
            LeftoverAppGroup(id: key, name: val.name, items: val.items.sorted { $0.size > $1.size })
        }.sorted { $0.totalSize > $1.totalSize }
    }

    private func sanitizeToken(_ str: String) -> String {
        str.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func isReverseDNS(_ str: String) -> Bool {
        let parts = str.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let first = parts[0].lowercased()
        return ["com", "org", "net", "io", "app", "dev", "ai", "co", "me", "chat"].contains(first)
    }

    private func isOrphan(
        candidate: String,
        candidateURL: URL,
        installedIDs: Set<String>,
        installedNames: Set<String>,
        normalizedNames: Set<String>
    ) -> Bool {
        let lower = candidate.lowercased()
        let token = sanitizeToken(lower)

        // 1. Apple and macOS system identifiers
        if lower.starts(with: "com.apple.") || lowercasedSystemIdentifiers.contains(lower) {
            return false
        }

        // Generic or very short folder names cannot be attributed to a specific app.
        if token.count < 4 || Self.genericNames.contains(token) {
            return false
        }

        // Something touched it recently, so an app (or tool) is probably still using it.
        if let modified = (try? candidateURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           Date().timeIntervalSince(modified) < Self.recentUseInterval {
            return false
        }

        // Credentials and keys are never offered for cleanup, even if their app looks gone.
        if Self.sensitiveKeywords.contains(where: token.contains) {
            return false
        }

        // 2. Direct bundle ID matches
        if installedIDs.contains(lower) {
            return false
        }

        // 3. Direct or normalized name matches
        if installedNames.contains(lower) || normalizedNames.contains(token) {
            return false
        }

        // 4. Check well-known aliases (e.g. "code" -> "com.microsoft.VSCode", "discord" -> "com.hnc.Discord")
        if let aliasedBundleID = wellKnownAliases[lower], installedIDs.contains(aliasedBundleID.lowercased()) {
            return false
        }
        if let aliasedBundleID = wellKnownAliases[lower] {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: aliasedBundleID),
               fileManager.fileExists(atPath: appURL.path) {
                return false
            }
        }

        // 5. Query macOS LaunchServices directly for reverse-DNS candidates
        if isReverseDNS(candidate) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate),
               fileManager.fileExists(atPath: appURL.path) {
                return false
            }

            let matchesPrefix = installedIDs.contains { id in
                id == lower || id.hasPrefix(lower + ".") || lower.hasPrefix(id + ".")
            }
            if matchesPrefix { return false }
        }

        // 6. Check if folder contains an embedded .app bundle (e.g. Discord in ~/Library/Application Support/discord)
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDir), isDir.boolValue {
            // Lazy, bounded walk: subpathsOfDirectory would enumerate multi-GB folders in full.
            if let enumerator = fileManager.enumerator(at: candidateURL, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants]) {
                var visited = 0
                for case let url as URL in enumerator {
                    if url.pathExtension == "app" { return false }
                    if enumerator.level >= 3 { enumerator.skipDescendants() }
                    visited += 1
                    if visited >= 200 { break }
                }
            }
        }

        // 7. Substring token safety check (e.g. "ciscopackettracer" matching "cisco packet tracer")
        for norm in normalizedNames where !norm.isEmpty {
            if token.contains(norm) || (norm.count >= 4 && norm.contains(token)) {
                return false
            }
        }

        return true
    }

    private func inferDisplayName(from identifier: String) -> String {
        if isReverseDNS(identifier) {
            let parts = identifier.split(separator: ".")
            if let last = parts.last {
                return String(last).capitalized
            }
        }
        return identifier
    }
}
