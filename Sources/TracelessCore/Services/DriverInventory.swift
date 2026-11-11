import Foundation
import AppKit

/// Every third-party system component on the Mac, explained in plain words and tied to the app that
/// owns it (or flagged when that app is gone). Ordinary users never look in /Library/Extensions or
/// System Settings › Login Items & Extensions; this page does it for them.
public struct DriverItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case hardwareDriver, legacyDriver, audioDevice, networkExtension, cameraExtension, otherExtension
        case backgroundService, privilegedHelper, sharedComponent, runningProcess

        /// What the user would call it.
        public var title: String {
            switch self {
            case .hardwareDriver: return "硬體驅動"
            case .legacyDriver: return "硬體驅動（舊式）"
            case .audioDevice: return "虛擬音訊裝置"
            case .networkExtension: return "網路延伸（VPN、防火牆）"
            case .cameraExtension: return "虛擬鏡頭"
            case .otherExtension: return "系統延伸"
            case .backgroundService: return "開機自動執行的背景服務"
            case .privilegedHelper: return "系統權限輔助程式"
            case .sharedComponent: return "驅動附帶元件"
            case .runningProcess: return "仍在執行的程式"
            }
        }

        /// Where the user notices it.
        public var symptom: String {
            switch self {
            case .hardwareDriver, .legacyDriver: return "讓滑鼠、鍵盤等週邊運作"
            case .audioDevice: return "出現在聲音輸入／輸出選單"
            case .networkExtension: return "攔截或轉送網路連線"
            case .cameraExtension: return "出現在鏡頭清單"
            case .otherExtension: return "在系統層級執行"
            case .backgroundService: return "開機後在背景啟動，常會在狀態列放圖示"
            case .privilegedHelper: return "以管理者權限替 App 做事"
            case .sharedComponent: return "給驅動或 App 使用的程式庫"
            case .runningProcess: return "現在仍在執行"
            }
        }

        var trashCategory: ResidualCategory {
            switch self {
            case .legacyDriver: return .kernelExtensions
            case .audioDevice: return .audioPlugins
            case .sharedComponent: return .frameworks
            default: return .launchAgents
            }
        }
    }

    /// How it can be removed.
    public enum Removal: Hashable, Sendable {
        case trash(URL)           // move to Trash (may need an admin password)
        case settings(String)     // macOS only allows turning it off in System Settings; text says where
        case quit(pid_t)          // a running process
    }

    public let id: String
    public let kind: Kind
    public let name: String
    public let vendor: String
    public let detail: String     // bundle id or path, for the curious
    public let ownerApp: String?  // installed app it belongs to; nil = app removed
    public let size: Int64
    public let removal: Removal
    public var isSelected = false

    public var isOrphaned: Bool { ownerApp == nil }

    public var trashItem: ResidualItem? {
        guard case .trash(let url) = removal else { return nil }
        return ResidualItem(url: url, name: name, size: size, category: kind.trashCategory, isSelected: true)
    }
}

public actor DriverInventory {
    private let fm = FileManager.default
    public init() {}

    public func scan(installedApps: [AppInfo]) async -> [DriverItem] {
        let thirdParty = installedApps.filter { !$0.isSystemApp }
        var teamOwner: [String: String] = [:]
        var vendorOwner: [String: String] = [:]
        for app in thirdParty {
            if let team = CodeSignature.teamID(of: app.url) { teamOwner[team] = teamOwner[team] ?? app.name }
            if let vendor = CodeSignature.vendorPrefix(app.bundleIdentifier) { vendorOwner[vendor] = vendorOwner[vendor] ?? app.name }
        }
        func owner(_ id: String, _ team: String?) -> String? {
            Self.resolveOwner(bundleId: id, teamID: team, teamOwner: teamOwner, vendorOwner: vendorOwner)
        }

        var items: [DriverItem] = []

        // Bundles in system folders.
        let bundleDirs: [(String, String, DriverItem.Kind)] = [
            ("/Library/Extensions", "kext", .legacyDriver),
            ("/Library/Audio/Plug-Ins/HAL", "driver", .audioDevice),
            (PathUtils.userLibrary.path + "/Audio/Plug-Ins/HAL", "driver", .audioDevice),
            ("/Library/Frameworks", "framework", .sharedComponent),
        ]
        for (dir, ext, kind) in bundleDirs {
            for url in contents(dir) where url.pathExtension == ext {
                guard let id = Bundle(url: url)?.bundleIdentifier, !id.lowercased().hasPrefix("com.apple.") else { continue }
                items.append(DriverItem(id: url.path, kind: kind, name: url.deletingPathExtension().lastPathComponent,
                                        vendor: Self.vendorName(id), detail: id,
                                        ownerApp: owner(id, CodeSignature.teamID(of: url)),
                                        size: PathUtils.calculateSize(of: url), removal: .trash(url)))
            }
        }

        // launchd jobs and their privileged helpers.
        for dir in ["/Library/LaunchDaemons", "/Library/LaunchAgents", PathUtils.userLibrary.path + "/LaunchAgents"] {
            for plistURL in contents(dir) where plistURL.pathExtension == "plist" {
                let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] ?? [:]
                let label = (plist["Label"] as? String) ?? plistURL.deletingPathExtension().lastPathComponent
                guard !label.lowercased().hasPrefix("com.apple.") else { continue }
                let program = ResidualScanner.launchdProgram(plist)
                let team = program.flatMap { CodeSignature.teamID(of: URL(fileURLWithPath: $0)) }
                let missingProgram = program.map { !fm.fileExists(atPath: $0) } ?? false
                let ownerName = missingProgram ? nil : owner(label, team)
                items.append(DriverItem(id: plistURL.path, kind: .backgroundService, name: label,
                                        vendor: Self.vendorName(label), detail: program ?? plistURL.path,
                                        ownerApp: ownerName, size: PathUtils.calculateSize(of: plistURL),
                                        removal: .trash(plistURL)))
            }
        }
        for url in contents("/Library/PrivilegedHelperTools") {
            let id = url.lastPathComponent
            guard !id.lowercased().hasPrefix("com.apple.") else { continue }
            items.append(DriverItem(id: url.path, kind: .privilegedHelper, name: id, vendor: Self.vendorName(id),
                                    detail: url.path, ownerApp: owner(id, CodeSignature.teamID(of: url)),
                                    size: PathUtils.calculateSize(of: url), removal: .trash(url)))
        }

        // System extensions: macOS manages these; only System Settings can turn them off.
        for ext in Self.parseSystemExtensionsWithKind(runSystemExtensionsCtl()) {
            items.append(DriverItem(id: "sysext:" + ext.info.id, kind: ext.kind, name: ext.info.name,
                                    vendor: Self.vendorName(ext.info.id), detail: ext.info.id,
                                    ownerApp: owner(ext.info.id, ext.info.teamID), size: 0,
                                    removal: .settings(Self.settingsPath(for: ext.kind))))
        }

        // Processes still running from removed apps (common source of a lingering menu bar icon).
        let ghosts = await SystemInspector().inspect(installedApps: installedApps).ghostProcesses
        for ghost in ghosts {
            items.append(DriverItem(id: "pid:\(ghost.id)", kind: .runningProcess, name: ghost.name,
                                    vendor: Self.vendorName(ghost.bundleIdentifier), detail: ghost.path,
                                    ownerApp: nil, size: 0, removal: .quit(ghost.id)))
        }

        return items.sorted { ($0.isOrphaned ? 0 : 1, $0.vendor.lowercased(), $0.name) < ($1.isOrphaned ? 0 : 1, $1.vendor.lowercased(), $1.name) }
    }

    private func contents(_ dir: String) -> [URL] {
        (try? fm.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
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

    // MARK: Pure helpers (unit-tested)

    /// The installed app that owns a component: same signing team first, then same vendor prefix.
    public static func resolveOwner(bundleId: String, teamID: String?, teamOwner: [String: String], vendorOwner: [String: String]) -> String? {
        if let teamID, let app = teamOwner[teamID] { return app }
        if let vendor = CodeSignature.vendorPrefix(bundleId) { return vendorOwner[vendor] }
        return nil
    }

    /// "com.razer.appengine.driver" → "Razer"; anything else → the id itself.
    public static func vendorName(_ id: String) -> String {
        let parts = id.split(separator: ".")
        guard parts.count >= 2, ["com", "org", "net", "io", "de", "eu", "co", "app", "me", "us", "ru"].contains(parts[0].lowercased()) else {
            return id
        }
        return String(parts[1]).capitalized
    }

    /// `systemextensionsctl list` groups extensions under "--- com.apple.system_extension.<type>" headers.
    public static func parseSystemExtensionsWithKind(_ output: String) -> [(info: SystemExtensionInfo, kind: DriverItem.Kind)] {
        var kind = DriverItem.Kind.otherExtension
        var out: [(SystemExtensionInfo, DriverItem.Kind)] = []
        for line in output.split(separator: "\n").map(String.init) {
            if line.hasPrefix("---") {
                if line.contains("driver_extension") { kind = .hardwareDriver }
                else if line.contains("network_extension") { kind = .networkExtension }
                else if line.contains("camera") { kind = .cameraExtension }
                else { kind = .otherExtension }
                continue
            }
            if let info = SystemInspector.parseSystemExtensions(line).first {
                // OBS and similar ship camera extensions under the generic header; the name tells.
                let k = info.name.localizedCaseInsensitiveContains("camera") ? DriverItem.Kind.cameraExtension : kind
                out.append((info, k))
            }
        }
        return out
    }

    public static func settingsPath(for kind: DriverItem.Kind) -> String {
        switch kind {
        case .hardwareDriver: return "系統設定 › 一般 › 登入項目與延伸功能 › 驅動程式延伸功能"
        case .networkExtension: return "系統設定 › 一般 › 登入項目與延伸功能 › 網路延伸功能"
        case .cameraExtension: return "系統設定 › 一般 › 登入項目與延伸功能 › 相機延伸功能"
        default: return "系統設定 › 一般 › 登入項目與延伸功能"
        }
    }
}
