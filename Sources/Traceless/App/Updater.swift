import AppKit
import Sparkle

/// Sparkle auto-update. Feed URL and public key come from the bundle's Info.plist (written by bundle.sh);
/// every update and the appcast itself must carry a valid EdDSA signature from the matching private key.
@MainActor
final class AppUpdater {
    private let controller: SPUStandardUpdaterController?

    init() {
        // `swift run` has no bundle Info.plist, so there is nothing to update; Sparkle would only show an error.
        let configured = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        controller = configured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }
}
