import Foundation

/// Pure helpers for receivables (IVK) upgrade UX.
public enum VaultModeBanner {
    /// Permanent ledger banner when vault is receivables-only.
    public static func shouldShowUpgradeBanner(mode: VaultMode) -> Bool {
        mode == .receivables
    }

    public static let upgradeCTA = "Upgrade to full viewing key"

    public static let upgradeBannerCopy =
        "Incoming-only key. Expenses and change detection are limited; income may be overstated if change exists."

    /// Replacing a receivables UVK with a UFVK creates a new vault key fingerprint.
    /// Same network required; notes stay — fingerprint change is expected and documented.
    public static func canUpgrade(
        current: Vault,
        newMode: VaultMode,
        newNetwork: ZcashNetwork
    ) -> Bool {
        current.mode == .receivables
            && newMode == .bookkeeper
            && newNetwork == current.network
    }
}
