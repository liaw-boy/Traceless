import XCTest
@testable import UprootCore

final class ResidualScannerTests: XCTestCase {
    func testFileSizeFormatter() {
        XCTAssertEqual(FileSizeFormatter.format(0), "0 B")
        XCTAssertTrue(FileSizeFormatter.format(1024).contains("KB") || FileSizeFormatter.format(1024).contains("kB"))
        XCTAssertTrue(FileSizeFormatter.format(1024 * 1024 * 5).contains("MB"))
        XCTAssertTrue(FileSizeFormatter.format(1024 * 1024 * 1024 * 2).contains("GB"))
    }

    func testPathUtilsSafety() {
        // Disallow root and system dirs
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Applications")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/System")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/usr")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/bin")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Extensions")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: URL(fileURLWithPath: "/Library/Preferences")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.userLibrary))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.userLibrary.appendingPathComponent("Application Support")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.userLibrary.appendingPathComponent("Caches")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.userLibrary.appendingPathComponent("Preferences")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.userLibrary.appendingPathComponent("Containers")))

        // Strict protection for user personal folders (Desktop, Documents, Downloads, etc.)
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent("Desktop")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent("Desktop/MyDoc.pdf")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent("Documents")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent("Downloads")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent(".ssh")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent(".ssh/id_rsa")))
        XCTAssertFalse(PathUtils.isSafeToDelete(url: PathUtils.homeDirectory.appendingPathComponent("Developer")))

        // Disallow macOS protected user library subdirectories
        let safariFolder = PathUtils.userLibrary.appendingPathComponent("Application Support").appendingPathComponent("Safari")
        XCTAssertFalse(PathUtils.isSafeToDelete(url: safariFolder))

        let messagesFolder = PathUtils.userLibrary.appendingPathComponent("Application Support").appendingPathComponent("Messages")
        XCTAssertFalse(PathUtils.isSafeToDelete(url: messagesFolder))

        // Allow legitimate user third-party app folder
        let sampleSubfolder = PathUtils.userLibrary
            .appendingPathComponent("Application Support")
            .appendingPathComponent("TestCleanAppSample")
        XCTAssertTrue(PathUtils.isSafeToDelete(url: sampleSubfolder))

        let sampleContainer = PathUtils.userLibrary
            .appendingPathComponent("Containers")
            .appendingPathComponent("com.sample.testapp")
        XCTAssertTrue(PathUtils.isSafeToDelete(url: sampleContainer))
    }

    func testResidualCategorySortOrder() {
        XCTAssertEqual(ResidualCategory.appBundle.sortOrder, 0)
        XCTAssertTrue(ResidualCategory.appBundle.sortOrder < ResidualCategory.preferences.sortOrder)
        XCTAssertTrue(ResidualCategory.preferences.sortOrder < ResidualCategory.other.sortOrder)
    }

    func testAppScanner() async {
        let scanner = AppScanner()
        let apps = await scanner.scanInstalledApplications()
        XCTAssertFalse(apps.isEmpty, "Should find installed applications on macOS")

        // Must find standard apps
        let names = Set(apps.map { $0.name.lowercased() })
        XCTAssertTrue(names.contains("safari") || names.contains("finder") || names.contains("google chrome") || names.contains("xcode"))
    }

    func testResidualScannerForSystemAppProtection() async {
        let scanner = AppScanner()
        let apps = await scanner.scanInstalledApplications()

        let residualScanner = ResidualScanner()
        if let systemApp = apps.first(where: { $0.isSystemApp }) {
            let residuals = await residualScanner.scanResiduals(for: systemApp)
            if let bundleItem = residuals.first(where: { $0.category == .appBundle }) {
                XCTAssertTrue(bundleItem.isProtected, "System app bundle must be marked as protected")
                XCTAssertFalse(bundleItem.isSelected, "System app bundle must not be selected by default")
            }
        }
    }

    func testLeftoverScannerDoesNotFlagInstalledApps() async {
        let scanner = AppScanner()
        let apps = await scanner.scanInstalledApplications()
        let leftoverScanner = LeftoverScanner()
        let leftovers = await leftoverScanner.scanLeftovers(installedApps: apps)

        let installedBundleIDs = Set(apps.map { $0.bundleIdentifier.lowercased() })
        let installedNames = Set(apps.map { $0.name.lowercased() })

        for group in leftovers {
            // Group ID must never be an actively installed bundle ID
            XCTAssertFalse(
                installedBundleIDs.contains(group.id.lowercased()),
                "Leftover group \(group.id) matches an installed application bundle ID!"
            )
            // Group name must never be an actively installed app name
            XCTAssertFalse(
                installedNames.contains(group.name.lowercased()),
                "Leftover group name \(group.name) matches an installed application name!"
            )
            // Top-level vendor folders must not be flagged
            XCTAssertNotEqual(group.id.lowercased(), "google")
            XCTAssertNotEqual(group.id.lowercased(), "microsoft")
            XCTAssertNotEqual(group.id.lowercased(), "adobe")
        }
    }
}
