import Foundation
import Security

public enum CodeSignature {
    /// Team IDs of every installed app; anything signed by one of these still has a living owner.
    public static func installedTeamIDs(_ apps: [AppInfo]) -> Set<String> {
        Set(apps.compactMap { teamID(of: $0.url) })
    }

    /// "com.razer.appengine.driver" → "com.razer". Nil for ids without a vendor part.
    public static func vendorPrefix(_ bundleId: String) -> String? {
        let parts = bundleId.lowercased().split(separator: ".")
        guard parts.count >= 3 else { return nil }
        return parts[0] + "." + parts[1]
    }

    /// A third-party bundle is orphaned when no installed app shares its vendor prefix and, if it is
    /// signed, no installed app shares its Team ID. Apple's own bundles never are.
    public static func isOrphanedVendorBundle(bundleId: String, teamID: String?, installedBundleIds: [String], installedTeams: Set<String>) -> Bool {
        let id = bundleId.lowercased()
        guard !id.isEmpty, !id.hasPrefix("com.apple."), let vendor = vendorPrefix(id) else { return false }
        if let teamID, installedTeams.contains(teamID) { return false }
        return !installedBundleIds.contains { vendorPrefix($0) == vendor }
    }

    /// Apple Developer Team ID that signed the bundle or binary at `url`, if any.
    /// Two items signed by the same team are, for our purposes, from the same vendor.
    public static func teamID(of url: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
        return (team?.isEmpty == false) ? team : nil
    }
}
