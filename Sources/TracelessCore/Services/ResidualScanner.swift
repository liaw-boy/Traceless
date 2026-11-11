import Foundation

public actor ResidualScanner {
    private let fileManager = FileManager.default

    public init() {}

    /// Scans for all residual files and directories associated with the given application.
    public func scanResiduals(for app: AppInfo) async -> [ResidualItem] {
        var items: [ResidualItem] = []
        var visitedURLs: Set<URL> = []
        let appTeamID = CodeSignature.teamID(of: app.url)
        // Apple apps keep user data (Notes, Mail, Photos…) in their containers: never pre-select it.
        let isAppleApp = app.isSystemApp || app.bundleIdentifier.lowercased().hasPrefix("com.apple.")

        // Helper to safely add an item
        func addItem(url: URL, category: ResidualCategory, isSelected: Bool = true, isProtected: Bool = false) {
            // An Apple app's own bundle holds no user data, so it may be pre-selected; its data may not.
            // System-wide (/Library) items are never pre-selected: their match rests on names from an
            // untrusted Info.plist, and moving them needs root.
            // Exception: a bundle signed by the same developer team as the app is proven to be its own.
            let isSystemWide = !url.path.hasPrefix(PathUtils.homeDirectory.path + "/") && category != .appBundle
            let provenSameVendor = isSystemWide && appTeamID != nil && CodeSignature.teamID(of: url) == appTeamID
            let preselect = isSelected && !isProtected && (!isSystemWide || provenSameVendor) && (!isAppleApp || category == .appBundle)
            let standardized = url.standardizedFileURL
            guard !visitedURLs.contains(standardized) else { return }
            guard fileManager.fileExists(atPath: standardized.path) else { return }
            guard PathUtils.isSafeToDelete(url: standardized) else { return }

            visitedURLs.insert(standardized)
            let size = PathUtils.calculateSize(of: standardized)
            let item = ResidualItem(
                url: standardized,
                name: standardized.lastPathComponent,
                size: size,
                category: category,
                isSelected: preselect,
                isProtected: isProtected
            )
            items.append(item)
        }

        // 1. App Bundle itself
        addItem(
            url: app.url,
            category: .appBundle,
            isSelected: !app.isSystemApp,
            isProtected: app.isSystemApp
        )

        // Names come from the app's Info.plist (untrusted): drop any that could escape a folder.
        func component(_ value: String?) -> String {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return PathUtils.isSafePathComponent(trimmed) ? trimmed : ""
        }
        // A bundle id is only trusted for prefix matching if it looks like a real reverse-DNS id;
        // a bare "com" would otherwise match every vendor's com.* files.
        let bundleId = Self.isTrustworthyBundleId(component(app.bundleIdentifier)) ? component(app.bundleIdentifier) : ""
        let appName = component(app.name)
        let executable: String? = component(app.executableName)

        let userLib = PathUtils.userLibrary

        // 2. Preferences
        let prefsDir = userLib.appendingPathComponent("Preferences")
        if !bundleId.isEmpty {
            addItem(url: prefsDir.appendingPathComponent("\(bundleId).plist"), category: .preferences)

            // Scan for ByHost or sub-plists
            scanMatchingFiles(in: prefsDir, category: .preferences) { filename in
                filename.hasPrefix("\(bundleId).") && filename.hasSuffix(".plist")
            }.forEach { addItem(url: $0, category: .preferences) }

            let byHostDir = prefsDir.appendingPathComponent("ByHost")
            scanMatchingFiles(in: byHostDir, category: .preferences) { filename in
                filename.hasPrefix("\(bundleId).")
            }.forEach { addItem(url: $0, category: .preferences) }
        }
        if !appName.isEmpty {
            addItem(url: prefsDir.appendingPathComponent("\(appName).plist"), category: .preferences)
        }

        // 3. Application Support (User Library)
        let appSupportDir = userLib.appendingPathComponent("Application Support")
        if !bundleId.isEmpty {
            addItem(url: appSupportDir.appendingPathComponent(bundleId), category: .applicationSupport)
        }
        if !appName.isEmpty {
            addItem(url: appSupportDir.appendingPathComponent(appName), category: .applicationSupport)
        }
        if let executable = executable, !executable.isEmpty, executable != appName {
            addItem(url: appSupportDir.appendingPathComponent(executable), category: .applicationSupport)
        }

        // 4. Caches
        let cachesDir = userLib.appendingPathComponent("Caches")
        if !bundleId.isEmpty {
            addItem(url: cachesDir.appendingPathComponent(bundleId), category: .caches)
            scanMatchingFiles(in: cachesDir, category: .caches) { filename in
                filename.hasPrefix("\(bundleId).")
            }.forEach { addItem(url: $0, category: .caches) }
        }
        if !appName.isEmpty {
            addItem(url: cachesDir.appendingPathComponent(appName), category: .caches)
        }

        // 5. Containers (App Sandbox)
        let containersDir = userLib.appendingPathComponent("Containers")
        if !bundleId.isEmpty {
            addItem(url: containersDir.appendingPathComponent(bundleId), category: .containers)
        }
        if !appName.isEmpty {
            addItem(url: containersDir.appendingPathComponent(appName), category: .containers)
        }

        // 6. Group Containers
        let groupContainersDir = userLib.appendingPathComponent("Group Containers")
        if !bundleId.isEmpty {
            scanMatchingFiles(in: groupContainersDir, category: .groupContainers) { filename in
                Self.groupContainerMatches(filename, bundleId: bundleId)
            }.forEach { addItem(url: $0, category: .groupContainers) }
        }

        // 7. Saved Application State
        let stateDir = userLib.appendingPathComponent("Saved Application State")
        if !bundleId.isEmpty {
            addItem(url: stateDir.appendingPathComponent("\(bundleId).savedState"), category: .savedState)
        }
        if !appName.isEmpty {
            addItem(url: stateDir.appendingPathComponent("\(appName).savedState"), category: .savedState)
        }

        // 8. WebKit & HTTPStorages & Cookies
        if !bundleId.isEmpty {
            addItem(url: userLib.appendingPathComponent("WebKit").appendingPathComponent(bundleId), category: .webData)
            addItem(url: userLib.appendingPathComponent("HTTPStorages").appendingPathComponent(bundleId), category: .webData)
            addItem(url: userLib.appendingPathComponent("HTTPStorages").appendingPathComponent("\(bundleId).binarycookies"), category: .webData)
            addItem(url: userLib.appendingPathComponent("Cookies").appendingPathComponent("\(bundleId).binarycookies"), category: .webData)
        }

        // 9. Logs & Crash Reports
        let logsDir = userLib.appendingPathComponent("Logs")
        if !appName.isEmpty {
            addItem(url: logsDir.appendingPathComponent(appName), category: .logs)
        }
        if !bundleId.isEmpty {
            addItem(url: logsDir.appendingPathComponent(bundleId), category: .logs)
        }

        let crashReporterDir = appSupportDir.appendingPathComponent("CrashReporter")
        if !appName.isEmpty {
            scanMatchingFiles(in: crashReporterDir, category: .logs) { filename in
                Self.reportFileMatches(filename, appName: appName)
            }.forEach { addItem(url: $0, category: .logs) }
        }

        let diagnosticDir = logsDir.appendingPathComponent("DiagnosticReports")
        if !appName.isEmpty {
            scanMatchingFiles(in: diagnosticDir, category: .logs) { filename in
                Self.reportFileMatches(filename, appName: appName)
            }.forEach { addItem(url: $0, category: .logs) }
        }

        // 10. LaunchAgents
        let userLaunchAgents = userLib.appendingPathComponent("LaunchAgents")
        if !bundleId.isEmpty || !appName.isEmpty {
            scanMatchingFiles(in: userLaunchAgents, category: .launchAgents) { filename in
                Self.launchAgentMatches(filename, bundleId: bundleId, appName: appName)
            }.forEach { addItem(url: $0, category: .launchAgents) }
        }

        // 11. Application Scripts (sandboxed apps and their app groups)
        let scriptsDir = userLib.appendingPathComponent("Application Scripts")
        if !bundleId.isEmpty {
            addItem(url: scriptsDir.appendingPathComponent(bundleId), category: .applicationSupport)
            scanMatchingFiles(in: scriptsDir, category: .groupContainers) { filename in
                filename.lowercased() != bundleId.lowercased() && Self.groupContainerMatches(filename, bundleId: bundleId)
            }.forEach { addItem(url: $0, category: .groupContainers) }
        }

        // 12. System-wide locations (moving these asks for an administrator password once).
        let sharedLib = URL(fileURLWithPath: "/Library")
        if !bundleId.isEmpty {
            addItem(url: sharedLib.appendingPathComponent("Application Support").appendingPathComponent(bundleId), category: .applicationSupport)
            addItem(url: sharedLib.appendingPathComponent("Caches").appendingPathComponent(bundleId), category: .caches)
        }
        if !appName.isEmpty {
            addItem(url: sharedLib.appendingPathComponent("Application Support").appendingPathComponent(appName), category: .applicationSupport)
            addItem(url: sharedLib.appendingPathComponent("Logs").appendingPathComponent(appName), category: .logs)
        }

        // 13. launchd jobs and privileged helpers, matched by ownership rather than by name.
        let launchdDirs = [userLaunchAgents,
                           sharedLib.appendingPathComponent("LaunchAgents"),
                           sharedLib.appendingPathComponent("LaunchDaemons")]
        for dir in launchdDirs {
            for plistURL in scanMatchingFiles(in: dir, category: .launchAgents, predicate: { $0.hasSuffix(".plist") }) {
                let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] ?? [:]
                guard Self.launchdJobBelongs(plist: plist, filename: plistURL.lastPathComponent,
                                             bundleId: bundleId, appPath: app.url.path) else { continue }
                addItem(url: plistURL, category: .launchAgents)
                // Only root-owned job definitions may point us at a privileged helper; a user-writable
                // ~/Library/LaunchAgents plist could otherwise name any vendor's root helper.
                if dir != userLaunchAgents, Self.isRootOwned(plistURL),
                   let program = Self.launchdProgram(plist), program.hasPrefix("/Library/PrivilegedHelperTools/") {
                    addItem(url: URL(fileURLWithPath: program), category: .launchAgents)
                }
            }
        }
        if !bundleId.isEmpty {
            scanMatchingFiles(in: sharedLib.appendingPathComponent("PrivilegedHelperTools"), category: .launchAgents) { filename in
                let lower = filename.lowercased(), id = bundleId.lowercased()
                return lower == id || lower.hasPrefix(id + ".")
            }.forEach { addItem(url: $0, category: .launchAgents) }
        }

        // 14. Virtual audio devices (HAL drivers) — these keep showing up in the Sound menu after the app is gone.
        for halDir in [sharedLib.appendingPathComponent("Audio/Plug-Ins/HAL"), userLib.appendingPathComponent("Audio/Plug-Ins/HAL")] {
            for driver in scanMatchingFiles(in: halDir, category: .audioPlugins, predicate: { $0.hasSuffix(".driver") }) {
                let driverId = Bundle(url: driver)?.bundleIdentifier ?? ""
                if Self.audioDriverBelongs(driverId: driverId, driverName: driver.deletingPathExtension().lastPathComponent,
                                           bundleId: bundleId, appName: appName) {
                    addItem(url: driver, category: .audioPlugins)
                }
            }
        }

        // 15. Shared frameworks and kernel extensions: only with proof (same vendor prefix AND same Team ID).
        if let vendor = CodeSignature.vendorPrefix(bundleId), let appTeamID {
            for (dir, ext, category) in [("/Library/Frameworks", "framework", ResidualCategory.frameworks),
                                         ("/Library/Extensions", "kext", ResidualCategory.kernelExtensions)] {
                for url in scanMatchingFiles(in: URL(fileURLWithPath: dir), category: category, predicate: { $0.hasSuffix("." + ext) }) {
                    guard let id = Bundle(url: url)?.bundleIdentifier, CodeSignature.vendorPrefix(id) == vendor,
                          CodeSignature.teamID(of: url) == appTeamID else { continue }
                    addItem(url: url, category: category)
                }
            }
        }

        // Sort: by category order first, then by size descending
        return items.sorted { lhs, rhs in
            if lhs.category.sortOrder != rhs.category.sortOrder {
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
            return lhs.size > rhs.size
        }
    }

    /// Group containers look like "TEAMID.com.vendor.app" or "group.com.vendor.app.shared".
    /// The bundle id must sit on dot boundaries so "com.foo.app" does not match "com.foo.application".
    static func groupContainerMatches(_ filename: String, bundleId: String) -> Bool {
        let name = "." + filename.lowercased() + "."
        let id = bundleId.lowercased()
        return !id.isEmpty && name.contains("." + id + ".")
    }

    /// At least two non-empty dot-separated parts with a reasonably long overall id ("com.vendor", "md.obsidian").
    static func isTrustworthyBundleId(_ id: String) -> Bool {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 2 && !parts.contains(where: \.isEmpty) && id.count >= 6
    }

    static func isRootOwned(_ url: URL) -> Bool {
        var st = stat()
        return lstat(url.path, &st) == 0 && st.st_uid == 0
    }

    /// A HAL driver belongs to the app when its id extends the app's id, or when it comes from the same
    /// vendor ("com.microsoft") and names the same product ("teams" in MSTeamsAudioDevice).
    public static func audioDriverBelongs(driverId: String, driverName: String, bundleId: String, appName: String) -> Bool {
        let driver = driverId.lowercased()
        let id = bundleId.lowercased()
        guard !driver.hasPrefix("com.apple.") else { return false }
        if !id.isEmpty && driver.hasPrefix(id + ".") { return true }
        let appParts = id.split(separator: ".").map(String.init)
        let driverParts = driver.split(separator: ".").map(String.init)
        guard appParts.count >= 3, driverParts.count >= 3, appParts[0] == driverParts[0], appParts[1] == driverParts[1] else {
            return false
        }
        func letters(_ s: String) -> String { s.lowercased().filter { $0.isLetter } }
        var products = Set([letters(appParts[2])])
        let vendor = letters(appParts[1])
        for word in appName.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let w = letters(String(word))
            if w != vendor { products.insert(w) }
        }
        let haystack = letters(driverParts.dropFirst(2).joined()) + letters(driverName)
        return products.contains { $0.count >= 3 && haystack.contains($0) }
    }

    static func launchdProgram(_ plist: [String: Any]) -> String? {
        (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
    }

    /// A launchd job belongs to the app when its label/file is the bundle id (or a dotted child of it),
    /// it declares the app in AssociatedBundleIdentifiers, or its executable lives inside the app bundle.
    static func launchdJobBelongs(plist: [String: Any], filename: String, bundleId: String, appPath: String) -> Bool {
        let id = bundleId.lowercased()
        if !id.isEmpty {
            let label = ((plist["Label"] as? String) ?? filename.replacingOccurrences(of: ".plist", with: "")).lowercased()
            let file = filename.lowercased().replacingOccurrences(of: ".plist", with: "")
            if [label, file].contains(where: { $0 == id || $0.hasPrefix(id + ".") }) { return true }
            let associated = (plist["AssociatedBundleIdentifiers"] as? [String]) ?? [(plist["AssociatedBundleIdentifiers"] as? String)].compactMap { $0 }
            if associated.contains(where: { $0.lowercased() == id }) { return true }
        }
        if !appPath.isEmpty, let program = launchdProgram(plist), program.hasPrefix(appPath + "/") {
            return true
        }
        return false
    }

    /// Crash/diagnostic reports are named "<App>-<date>.ips" or "<App>_<date>…".
    /// Requiring a separator stops "Code" from matching "CodeRunner-….ips".
    static func reportFileMatches(_ filename: String, appName: String) -> Bool {
        guard !appName.isEmpty, filename.hasPrefix(appName) else { return false }
        guard let next = filename.dropFirst(appName.count).first else { return false }
        return next == "-" || next == "_" || next == "." || next == " "
    }

    /// LaunchAgent plists are usually "<bundle id>[.suffix].plist". A name match must equal a whole
    /// dot-separated component, so an app named "Go" no longer matches "com.google.keystone.agent.plist".
    static func launchAgentMatches(_ filename: String, bundleId: String, appName: String) -> Bool {
        let lower = filename.lowercased()
        let id = bundleId.lowercased()
        if !id.isEmpty && (lower == id + ".plist" || lower.hasPrefix(id + ".")) {
            return true
        }
        let token = appName.lowercased().filter { $0.isLetter || $0.isNumber }
        guard token.count >= 3 else { return false }
        let components = lower.replacingOccurrences(of: ".plist", with: "").split(separator: ".")
        return components.contains { $0.filter { $0.isLetter || $0.isNumber } == token }
    }

    private func scanMatchingFiles(
        in directory: URL,
        category: ResidualCategory,
        predicate: (String) -> Bool
    ) -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.filter { predicate($0.lastPathComponent) }
    }
}
