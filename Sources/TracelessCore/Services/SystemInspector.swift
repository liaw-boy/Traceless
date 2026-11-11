import Foundation
import AppKit

/// A system extension (driver, network, endpoint security) registered with macOS.
public struct SystemExtensionInfo: Identifiable, Hashable, Sendable {
    public let id: String          // bundle id
    public let teamID: String
    public let name: String
    public let state: String       // e.g. "activated waiting for user"
    public let isEnabled: Bool
}

/// A process still running from an app that is no longer installed (often a menu bar helper).
public struct GhostProcess: Identifiable, Hashable, Sendable {
    public let id: pid_t
    public let name: String
    public let bundleIdentifier: String
    public let path: String

    public init(id: pid_t, name: String, bundleIdentifier: String, path: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
}

public struct InspectionReport: Sendable {
    public var orphanedExtensions: [SystemExtensionInfo] = []
    public var ghostProcesses: [GhostProcess] = []
    public init() {}
    public var isEmpty: Bool { orphanedExtensions.isEmpty && ghostProcesses.isEmpty }
}

/// Finds things macOS will not let us simply trash but that keep a removed app alive:
/// system extensions and still-running helpers.
public actor SystemInspector {
    public init() {}

    public func inspect(installedApps: [AppInfo]) async -> InspectionReport {
        let teams = CodeSignature.installedTeamIDs(installedApps.filter { !$0.isSystemApp })
        let ids = installedApps.map(\.bundleIdentifier)
        var report = InspectionReport()

        report.orphanedExtensions = Self.parseSystemExtensions(runSystemExtensionsCtl()).filter {
            !teams.contains($0.teamID) && CodeSignature.isOrphanedVendorBundle(bundleId: $0.id, teamID: $0.teamID,
                                                                             installedBundleIds: ids, installedTeams: teams)
        }

        let installedPaths = Set(installedApps.map(\.url.standardizedFileURL.path))
        let me = Bundle.main.bundleIdentifier
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, id != me, !id.lowercased().hasPrefix("com.apple."),
                  let url = app.bundleURL?.standardizedFileURL else { continue }
            let path = url.path
            if path.hasPrefix("/System/") || path.hasPrefix("/Volumes/") || installedPaths.contains(path) { continue }
            let bundleGone = !FileManager.default.fileExists(atPath: path)
            let ownerGone = CodeSignature.isOrphanedVendorBundle(bundleId: id, teamID: CodeSignature.teamID(of: url),
                                                                 installedBundleIds: ids, installedTeams: teams)
            if Self.isGhost(path: path, bundleGone: bundleGone, ownerGone: ownerGone) {
                report.ghostProcesses.append(GhostProcess(id: app.processIdentifier, name: app.localizedName ?? id,
                                                          bundleIdentifier: id, path: path))
            }
        }
        return report
    }

    /// A running process is a ghost when its bundle was deleted, or when it is a helper living in a
    /// Library support folder whose vendor has no installed app. Apps run from other folders
    /// (Downloads, a build directory) are deliberate and left alone.
    static func isGhost(path: String, bundleGone: Bool, ownerGone: Bool, home: String = PathUtils.homeDirectory.path) -> Bool {
        if bundleGone { return true }
        let inSupportFolder = path.hasPrefix("/Library/") || path.hasPrefix(home + "/Library/")
        return inSupportFolder && ownerGone
    }

    private func runSystemExtensionsCtl() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/systemextensionsctl")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// Parses `systemextensionsctl list`: tab-separated `enabled  active  teamID  bundleID (version)  name  [state]`.
    public static func parseSystemExtensions(_ output: String) -> [SystemExtensionInfo] {
        output.split(separator: "\n").compactMap { line in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 6, cols[2] != "teamID" else { return nil }
            let bundle = cols[3].split(separator: " ").first.map(String.init) ?? ""
            guard !bundle.isEmpty else { return nil }
            let state = cols[5].trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            return SystemExtensionInfo(id: bundle, teamID: cols[2], name: cols[4], state: state, isEnabled: cols[0] == "*")
        }
    }
}
