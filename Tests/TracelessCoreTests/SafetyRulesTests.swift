import XCTest
@testable import TracelessCore

final class SafetyRulesTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TracelessTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Privileged move script

    /// Runs the generated script without the admin clause to prove hostile file names are moved
    /// literally and never interpreted by the shell.
    func testPrivilegedScriptDoesNotInterpretHostileNames() throws {
        // File names cannot contain "/", so the payload reaches the canary through $TMPDIR.
        let canaryName = "traceless-canary-\(UUID().uuidString)"
        let canary = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(canaryName)
        defer { try? FileManager.default.removeItem(at: canary) }
        let names = [
            "$(touch ${TMPDIR}\(canaryName))",
            "`touch ${TMPDIR}\(canaryName)`",
            "quote\"and'single",
            "back\\slash; touch ${TMPDIR}\(canaryName)",
            "plain name"
        ]
        let trash = tempDir.appendingPathComponent("trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)

        var pairs: [(URL, URL)] = []
        for name in names {
            let src = tempDir.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.createFile(atPath: src.path, contents: Data("x".utf8)))
            pairs.append((src, trash.appendingPathComponent(name)))
        }

        let script = Uninstaller.privilegedMoveScript(pairs)
        XCTAssertTrue(script.hasSuffix(" with administrator privileges"))
        let unprivileged = String(script.dropLast(" with administrator privileges".count))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", unprivileged]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        XCTAssertFalse(FileManager.default.fileExists(atPath: canary.path), "shell injection executed")
        for (src, dst) in pairs {
            XCTAssertFalse(FileManager.default.fileExists(atPath: src.path), "not moved: \(src.lastPathComponent)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path), "missing in trash: \(dst.lastPathComponent)")
        }
    }

    func testUniqueTrashURLNeverClobbers() throws {
        let src = URL(fileURLWithPath: "/tmp/Example.app")
        XCTAssertEqual(Uninstaller.uniqueTrashURL(for: src, in: tempDir).lastPathComponent, "Example.app")

        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("Example.app").path, contents: nil)
        XCTAssertEqual(Uninstaller.uniqueTrashURL(for: src, in: tempDir).lastPathComponent, "Example 2.app")

        let reserved: Set<String> = [tempDir.appendingPathComponent("Example 2.app").path]
        XCTAssertEqual(Uninstaller.uniqueTrashURL(for: src, in: tempDir, reserved: reserved).lastPathComponent, "Example 3.app")

        let noExt = URL(fileURLWithPath: "/tmp/com.example.cache")
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("com.example.cache").path, contents: nil)
        // "cache" is treated as an extension by URL; the important part is no trailing dot and no overwrite.
        let result = Uninstaller.uniqueTrashURL(for: noExt, in: tempDir).lastPathComponent
        XCTAssertNotEqual(result, "com.example.cache")
        XCTAssertFalse(result.hasSuffix("."))
    }

    // MARK: - Matching rules

    func testLaunchAgentMatching() {
        XCTAssertTrue(ResidualScanner.launchAgentMatches("com.example.editor.plist", bundleId: "com.example.editor", appName: "Editor"))
        XCTAssertTrue(ResidualScanner.launchAgentMatches("com.example.editor.helper.plist", bundleId: "com.example.editor", appName: "Editor"))
        XCTAssertTrue(ResidualScanner.launchAgentMatches("com.vendor.sampleapp.agent.plist", bundleId: "", appName: "Sample App"))
        // Short or substring names must not match unrelated agents.
        XCTAssertFalse(ResidualScanner.launchAgentMatches("com.google.keystone.agent.plist", bundleId: "io.go.app", appName: "Go"))
        XCTAssertFalse(ResidualScanner.launchAgentMatches("com.example.notesync.plist", bundleId: "", appName: "Notes"))
        XCTAssertFalse(ResidualScanner.launchAgentMatches("com.example.editorpro.plist", bundleId: "com.example.editor", appName: ""))
    }

    func testReportFileMatching() {
        XCTAssertTrue(ResidualScanner.reportFileMatches("Code-2026-01-01-101010.ips", appName: "Code"))
        XCTAssertTrue(ResidualScanner.reportFileMatches("Code_2026-01-01.crash", appName: "Code"))
        XCTAssertFalse(ResidualScanner.reportFileMatches("CodeRunner-2026-01-01.ips", appName: "Code"))
        XCTAssertFalse(ResidualScanner.reportFileMatches("Code", appName: "Code"))
    }

    func testGroupContainerMatching() {
        XCTAssertTrue(ResidualScanner.groupContainerMatches("ABCDE12345.com.example.app", bundleId: "com.example.app"))
        XCTAssertTrue(ResidualScanner.groupContainerMatches("group.com.example.app.shared", bundleId: "com.example.app"))
        XCTAssertFalse(ResidualScanner.groupContainerMatches("group.com.example.application", bundleId: "com.example.app"))
        XCTAssertFalse(ResidualScanner.groupContainerMatches("group.com.example.app", bundleId: ""))
    }

    func testUnusedUsesInstallDateWhenNeverOpened() {
        let url = URL(fileURLWithPath: "/Applications/Example.app")
        let fresh = AppInfo(name: "Fresh", bundleIdentifier: "com.example.fresh", url: url, version: "1", installDate: Date())
        let old = AppInfo(name: "Old", bundleIdentifier: "com.example.old", url: url, version: "1", installDate: Date(timeIntervalSinceNow: -200 * 86400))
        let usedRecently = AppInfo(name: "Used", bundleIdentifier: "com.example.used", url: url, version: "1",
                                   installDate: Date(timeIntervalSinceNow: -400 * 86400), lastUsedDate: Date(timeIntervalSinceNow: -86400))
        XCTAssertFalse(fresh.isUnusedOver3Months)
        XCTAssertTrue(old.isUnusedOver3Months)
        XCTAssertFalse(usedRecently.isUnusedOver3Months)
    }

    func testSpotlightPathFilter() {
        XCTAssertFalse(AppScanner.shouldSkipSpotlightPath("/Applications/Example.app"))
        XCTAssertFalse(AppScanner.shouldSkipSpotlightPath("/Applications/Vendor/Example.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Applications/Example.app/Contents/Frameworks/Helper.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Volumes/Example Installer/Example.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Users/someone/.Trash/Old.app", home: "/Users/someone"))
        XCTAssertFalse(AppScanner.shouldSkipSpotlightPath("/Users/someone/Applications/Tool.app", home: "/Users/someone"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/System/Library/CoreServices/Internal.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Library/Application Support/Vendor/Helper.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Users/someone/code/build/Debug/My.app", home: "/Users/someone"))
    }
}

final class PathSafetyTests: XCTestCase {
    private let lib = PathUtils.userLibrary

    func testRejectsTraversalAndCaseAliases() {
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: lib.path + "/Caches/../../Documents")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/SYSTEM/Library/CoreServices")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: PathUtils.homeDirectory.path + "/DOCUMENTS/report.txt")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: lib.path + "/Caches/bad\u{0007}name")))
    }

    func testRejectsApprovedRootsThemselves() {
        for root in ["Caches", "Application Scripts", "Cookies", "LaunchAgents", "HTTPStorages"] {
            XCTAssertFalse(PathUtils.isSafeToDelete(url: lib.appendingPathComponent(root)), root)
        }
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/LaunchDaemons")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/PrivilegedHelperTools")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent(".Trash/Old.app")))
    }

    func testAllowsKnownResidualLocations() {
        XCTAssertTrue(PathUtils.isSafeToDelete(url: lib.appendingPathComponent("Application Scripts/com.example.app")))
        XCTAssertTrue(PathUtils.isSafeToDelete(url: lib.appendingPathComponent("Cookies/com.example.app.binarycookies")))
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.app.helper.plist")))
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/PrivilegedHelperTools/com.example.app.helper")))
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Applications/Example.app")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Users/Shared/Example.app")))
    }

    func testPathComponentValidation() {
        XCTAssertTrue(PathUtils.isSafePathComponent("com.example.app"))
        XCTAssertTrue(PathUtils.isSafePathComponent("Example App"))
        for bad in ["", ".", "..", "../Documents", "a/b", "a:b", "x\u{0000}y"] {
            XCTAssertFalse(PathUtils.isSafePathComponent(bad), bad)
        }
    }

    func testLaunchdOwnership() {
        let appPath = "/Applications/Example.app"
        XCTAssertTrue(ResidualScanner.launchdJobBelongs(plist: ["Label": "com.example.app.helper"], filename: "x.plist", bundleId: "com.example.app", appPath: appPath))
        XCTAssertTrue(ResidualScanner.launchdJobBelongs(plist: ["AssociatedBundleIdentifiers": ["com.example.app"]], filename: "com.vendor.daemon.plist", bundleId: "com.example.app", appPath: appPath))
        XCTAssertTrue(ResidualScanner.launchdJobBelongs(plist: ["ProgramArguments": [appPath + "/Contents/MacOS/agent"]], filename: "com.vendor.daemon.plist", bundleId: "", appPath: appPath))
        XCTAssertFalse(ResidualScanner.launchdJobBelongs(plist: ["Label": "com.example.application"], filename: "com.example.application.plist", bundleId: "com.example.app", appPath: appPath))
        XCTAssertFalse(ResidualScanner.launchdJobBelongs(plist: ["Program": "/Applications/Example.app.bak/x"], filename: "y.plist", bundleId: "", appPath: appPath))
    }
}

final class AuditFixTests: XCTestCase {
    func testBundleIdTrust() {
        XCTAssertTrue(ResidualScanner.isTrustworthyBundleId("com.example.app"))
        XCTAssertTrue(ResidualScanner.isTrustworthyBundleId("md.obsidian"))
        for bad in ["", "com", "com.", ".com", "a.b", "com..x"] {
            XCTAssertFalse(ResidualScanner.isTrustworthyBundleId(bad), bad)
        }
    }

    func testNestedOrDeepAppBundlesRejected() {
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Applications/Vendor/Example.app")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Applications/Example.app/Contents/Helper.app")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Applications/A/B/Example.app")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Applications/Vendor/notes.txt")))
    }

    func testAdminFallbackRequiresRootOwnedAncestors() throws {
        // /Library and / are root-owned and not world-writable on every Mac.
        XCTAssertTrue(Uninstaller.hasRootOnlyAncestors(URL(fileURLWithPath: "/Library/LaunchDaemons/x.plist")))
        // A user-owned temp folder could be swapped for a symlink, so root must not act inside it.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("TracelessAnc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertFalse(Uninstaller.hasRootOnlyAncestors(tmp.appendingPathComponent("x")))
        XCTAssertTrue(Uninstaller.isRealUserDirectory(tmp))
        let link = tmp.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tmp)
        XCTAssertFalse(Uninstaller.isRealUserDirectory(link))
    }
}

final class AudioDriverTests: XCTestCase {
    func testDriverOwnership() {
        // Same vendor and product token.
        XCTAssertTrue(ResidualScanner.audioDriverBelongs(driverId: "com.example.chat.ChatAudioDevice", driverName: "ExChatAudioDevice",
                                                          bundleId: "com.example.chat2", appName: "Example Chat"))
        // Driver id extends the app id.
        XCTAssertTrue(ResidualScanner.audioDriverBelongs(driverId: "com.example.recorder.driver", driverName: "Recorder",
                                                          bundleId: "com.example.recorder", appName: "Recorder"))
        // Short product token is fine when the vendor matches.
        XCTAssertTrue(ResidualScanner.audioDriverBelongs(driverId: "com.vendor.ABC.Driver", driverName: "ABC Device",
                                                          bundleId: "com.vendor.ABC.App", appName: "ABC"))
        // Same vendor, different product.
        XCTAssertFalse(ResidualScanner.audioDriverBelongs(driverId: "com.example.meeting.Audio", driverName: "MeetingAudio",
                                                           bundleId: "com.example.chat2", appName: "Example Chat"))
        // Different vendor with a matching word.
        XCTAssertFalse(ResidualScanner.audioDriverBelongs(driverId: "com.other.chat.Audio", driverName: "ChatAudio",
                                                           bundleId: "com.example.chat", appName: "Chat"))
        // Apple drivers are never claimed.
        XCTAssertFalse(ResidualScanner.audioDriverBelongs(driverId: "com.apple.audio.Plugin", driverName: "Plugin",
                                                           bundleId: "com.apple.audio", appName: "Audio"))
    }

    func testDriverPathsAreDeletableOnlyInsideHAL() {
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL/Example.driver")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Audio/Plug-Ins/Components/Example.component")))
    }

    func testPrivilegedScriptRestartsAudioOnlyWhenAsked() {
        let pair = (URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL/Example.driver"), URL(fileURLWithPath: "/tmp/Example.driver"))
        XCTAssertTrue(Uninstaller.privilegedMoveScript([pair], restartAudio: true).contains("killall coreaudiod"))
        XCTAssertFalse(Uninstaller.privilegedMoveScript([pair]).contains("killall"))
    }
}

final class SystemInspectionTests: XCTestCase {
    func testParseSystemExtensions() {
        let sample = """
        2 extension(s)
        --- com.apple.system_extension.driver_extension (Go to 'System Settings')
        enabled\tactive\tteamID\tbundleID (version)\tname\t[state]
        \t*\tABCDE12345\tcom.example.driver (1.0/1)\tExample Driver\t[activated waiting for user]
        *\t*\tFGHIJ67890\tcom.other.net-ext (2.0/2)\tOther Net\t[activated enabled]
        """
        let parsed = SystemInspector.parseSystemExtensions(sample)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].id, "com.example.driver")
        XCTAssertEqual(parsed[0].teamID, "ABCDE12345")
        XCTAssertEqual(parsed[0].state, "activated waiting for user")
        XCTAssertFalse(parsed[0].isEnabled)
        XCTAssertTrue(parsed[1].isEnabled)
    }

    func testVendorOrphanRules() {
        XCTAssertEqual(CodeSignature.vendorPrefix("com.example.mouse.driver"), "com.example")
        XCTAssertNil(CodeSignature.vendorPrefix("com.example"))
        // No installed app from the vendor and no matching team → orphan.
        XCTAssertTrue(CodeSignature.isOrphanedVendorBundle(bundleId: "com.example.hid", teamID: "T1",
                                                           installedBundleIds: ["com.other.app"], installedTeams: ["T2"]))
        // Same team still installed → kept.
        XCTAssertFalse(CodeSignature.isOrphanedVendorBundle(bundleId: "com.example.hid", teamID: "T2",
                                                            installedBundleIds: ["com.other.app"], installedTeams: ["T2"]))
        // Same vendor prefix still installed → kept.
        XCTAssertFalse(CodeSignature.isOrphanedVendorBundle(bundleId: "com.example.hid", teamID: nil,
                                                            installedBundleIds: ["com.example.app"], installedTeams: []))
        // Apple is never orphaned.
        XCTAssertFalse(CodeSignature.isOrphanedVendorBundle(bundleId: "com.apple.driver.x", teamID: nil,
                                                            installedBundleIds: [], installedTeams: []))
    }

    func testGhostRule() {
        let home = "/Users/someone"
        XCTAssertTrue(SystemInspector.isGhost(path: "/Applications/Gone.app", bundleGone: true, ownerGone: false, home: home))
        XCTAssertTrue(SystemInspector.isGhost(path: "/Library/Application Support/Vendor/Helper.app", bundleGone: false, ownerGone: true, home: home))
        XCTAssertTrue(SystemInspector.isGhost(path: home + "/Library/Application Support/Vendor/Menu.app", bundleGone: false, ownerGone: true, home: home))
        // Apps run from a project or Downloads folder are deliberate.
        XCTAssertFalse(SystemInspector.isGhost(path: home + "/code/build/My.app", bundleGone: false, ownerGone: true, home: home))
        // Helper whose vendor still has an installed app.
        XCTAssertFalse(SystemInspector.isGhost(path: "/Library/Application Support/Vendor/Helper.app", bundleGone: false, ownerGone: false, home: home))
    }

    func testKextAndFrameworkPaths() {
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Extensions/ExampleHid.kext")))
        XCTAssertTrue(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Frameworks/ExampleSDK.framework")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Extensions")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Extensions/A.kext/Contents/Info.plist")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Frameworks/notes.txt")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/SystemExtensions/X/com.example.dext")))
    }
}
