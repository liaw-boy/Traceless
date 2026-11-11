import XCTest
@testable import AppSweepCore

final class SafetyRulesTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppSweepTests-\(UUID().uuidString)")
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
        let canaryName = "appsweep-canary-\(UUID().uuidString)"
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

    func testSpotlightPathFilter() {
        XCTAssertFalse(AppScanner.shouldSkipSpotlightPath("/Applications/Example.app"))
        XCTAssertFalse(AppScanner.shouldSkipSpotlightPath("/Applications/Vendor/Example.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Applications/Example.app/Contents/Frameworks/Helper.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Volumes/Example Installer/Example.app"))
        XCTAssertTrue(AppScanner.shouldSkipSpotlightPath("/Users/someone/.Trash/Old.app"))
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
