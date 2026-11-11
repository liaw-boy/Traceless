import Foundation
import Security

public enum CodeSignature {
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
