import Foundation
import SaneBooksSync
import SaneUI

extension SaneDiagnosticsService {
    /// Shared ZecBooks diagnostics for Settings → About → Report Public Issue.
    /// Settings summary never includes viewing keys, seeds, memos, or proof-pack contents.
    static let shared = SaneDiagnosticsService(
        appName: "ZecBooks",
        subsystem: "com.saneapps.SaneBooks",
        githubRepo: "SaneBooks",
        settingsCollector: { await collectZecBooksSettings() }
    )
}

@MainActor
private func collectZecBooksSettings() -> String {
    let defaults = UserDefaults.standard
    let keys = AppModel.SettingsKey.self

    let expiry = defaults.object(forKey: keys.defaultPackExpiryDays) as? Int ?? 90
    let includeMemos = defaults.object(forKey: keys.includeMemosByDefault) as? Bool ?? false
    let truncateTxids = defaults.object(forKey: keys.truncateTxidsInUI) as? Bool ?? true
    let discreet = defaults.object(forKey: keys.discreetMode) as? Bool ?? false
    let textSize = defaults.string(forKey: keys.textSize) ?? SaneBooksTextSize.standard.rawValue
    let onboardingDone = defaults.object(forKey: keys.hasCompletedOnboarding) as? Bool ?? false
    let lwdRaw = defaults.string(forKey: keys.lwdURL) ?? "https://zec.rocks:443"
    let hasRecipient = !(defaults.string(forKey: keys.defaultRecipientLabel) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty

    return """
    product: ZecBooks
    vaultCount: (omitted — not read from Keychain for public diagnostics)
    ironwoodSDK: \(LinkedZcashSDK.revision)

    settings:
      defaultPackExpiryDays: \(expiry)
      includeMemosByDefault: \(includeMemos)
      truncateTxidsInUI: \(truncateTxids)
      discreetMode: \(discreet)
      textSize: \(textSize)
      hasCompletedOnboarding: \(onboardingDone)
      defaultRecipientConfigured: \(hasRecipient)
      lwdEndpoint: \(sanitizedPublicLWDEndpoint(lwdRaw))
    """
}

/// Public diagnostics must never include URL userinfo (user:password@host).
func sanitizedPublicLWDEndpoint(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else {
        return "[unparseable-endpoint]"
    }
    let scheme = (url.scheme?.isEmpty == false) ? url.scheme! : "https"
    if let port = url.port {
        return "\(scheme)://\(host):\(port)"
    }
    return "\(scheme)://\(host)"
}
