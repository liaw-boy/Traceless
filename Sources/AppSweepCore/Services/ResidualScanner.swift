import Foundation

public actor ResidualScanner {
    private let fileManager = FileManager.default

    public init() {}

    /// Scans for all residual files and directories associated with the given application.
    public func scanResiduals(for app: AppInfo) async -> [ResidualItem] {
        var items: [ResidualItem] = []
        var visitedURLs: Set<URL> = []

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
                isSelected: isSelected && !isProtected,
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
                filename.hasSuffix(".\(bundleId)") || filename.contains(bundleId)
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
                filename.hasPrefix(appName)
            }.forEach { addItem(url: $0, category: .logs) }
        }

        let diagnosticDir = logsDir.appendingPathComponent("DiagnosticReports")
        if !appName.isEmpty {
            scanMatchingFiles(in: diagnosticDir, category: .logs) { filename in
                filename.hasPrefix(appName)
            }.forEach { addItem(url: $0, category: .logs) }
        }

        // 10. LaunchAgents
        let userLaunchAgents = userLib.appendingPathComponent("LaunchAgents")
        if !bundleId.isEmpty || !appName.isEmpty {
            scanMatchingFiles(in: userLaunchAgents, category: .launchAgents) { filename in
                (!bundleId.isEmpty && filename.hasPrefix(bundleId)) ||
                (!appName.isEmpty && filename.localizedCaseInsensitiveContains(appName))
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
