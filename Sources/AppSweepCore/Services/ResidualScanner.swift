import Foundation

public actor ResidualScanner {
    private let fileManager = FileManager.default

    public init() {}

    /// Scans for all residual files and directories associated with the given application.
    public func scanResiduals(for app: AppInfo) async -> [ResidualItem] {
        var items: [ResidualItem] = []
        var visitedURLs: Set<URL> = []
        // Apple apps keep user data (Notes, Mail, Photos…) in their containers: never pre-select it.
        let isAppleApp = app.isSystemApp || app.bundleIdentifier.lowercased().hasPrefix("com.apple.")

        // Helper to safely add an item
        func addItem(url: URL, category: ResidualCategory, isSelected: Bool = true, isProtected: Bool = false) {
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
                isSelected: isSelected && !isProtected && !isAppleApp,
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

        let bundleId = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = app.executableName?.trimmingCharacters(in: .whitespacesAndNewlines)

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
