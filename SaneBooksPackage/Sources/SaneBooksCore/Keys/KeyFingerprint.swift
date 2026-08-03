import CryptoKit
import Foundation

public enum KeyFingerprint {
    public static func make(normalizedKey: String, hrp: String) -> String {
        let digest = SHA256.hash(data: Data(normalizedKey.utf8))
        let truncated = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(hrp):\(truncated)"
    }

    public static func derive(from normalizedKey: String, hrp: String) -> String {
        make(normalizedKey: normalizedKey, hrp: hrp)
    }
}
