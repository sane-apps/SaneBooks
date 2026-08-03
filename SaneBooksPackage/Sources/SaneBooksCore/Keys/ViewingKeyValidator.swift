import Foundation

public enum ViewingKeyValidationOutcome: Sendable, Equatable {
    case empty
    case rejectSeed
    case rejectSpendingKey
    case rejectGarbage
    case networkMismatch(detected: ZcashNetwork)
    case rejectUnsupported
    case accept(kind: ViewingKeyKind, network: ZcashNetwork, hrp: String, fingerprint: String, mode: VaultMode)
}

public struct ViewingKeyValidator: Sendable {
    public static let fixtureMainnetUFVK = DemoLedgerFixtures.fixtureMainnetUFVK
    public static let fixtureTestnetUFVK = DemoLedgerFixtures.fixtureTestnetUFVK

    public init() {}

    public func validate(_ raw: String, selectedNetwork: ZcashNetwork) -> ViewingKeyValidationOutcome {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let lower = trimmed.lowercased()
        if looksLikeSeedPhrase(trimmed) {
            return .rejectSeed
        }
        if looksLikeSpendingKey(lower) {
            return .rejectSpendingKey
        }

        guard let (hrp, payload) = splitBech32(lower) else { return .rejectGarbage }
        guard isValidBech32Charset(payload), payload.count >= 8 else { return .rejectGarbage }
        guard let classified = classifyHRP(hrp) else { return .rejectUnsupported }

        if classified.network != selectedNetwork {
            return .networkMismatch(detected: classified.network)
        }

        let fingerprint = KeyFingerprint.make(normalizedKey: lower, hrp: hrp)
        return .accept(
            kind: classified.kind,
            network: classified.network,
            hrp: hrp,
            fingerprint: fingerprint,
            mode: Vault.mode(for: classified.kind)
        )
    }

    /// Convenience static entry matching alternate call sites.
    public static func validate(_ raw: String, selectedNetwork: ZcashNetwork) -> ViewingKeyValidationOutcome {
        ViewingKeyValidator().validate(raw, selectedNetwork: selectedNetwork)
    }

    private func looksLikeSeedPhrase(_ input: String) -> Bool {
        let words = input.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard [12, 15, 18, 21, 24].contains(words.count) else { return false }
        return words.allSatisfy { word in
            let w = word.lowercased()
            return w.count >= 3 && w.count <= 8 && w.allSatisfy(\.isLetter)
        }
    }

    private func looksLikeSpendingKey(_ lower: String) -> Bool {
        lower.contains("secret-extended-key")
            || lower.contains("secret-sharing-key")
            || lower.contains("secret-spending-key")
            || lower.hasPrefix("zsk")
    }

    private func splitBech32(_ lower: String) -> (hrp: String, payload: String)? {
        guard let idx = lower.lastIndex(of: "1"), idx > lower.startIndex else { return nil }
        let hrp = String(lower[..<idx])
        let payload = String(lower[lower.index(after: idx)...])
        guard !hrp.isEmpty, !payload.isEmpty else { return nil }
        return (hrp, payload)
    }

    private static let bech32Charset = Set("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    private func isValidBech32Charset(_ payload: String) -> Bool {
        payload.allSatisfy { Self.bech32Charset.contains($0) }
    }

    private struct ClassifiedHRP {
        var kind: ViewingKeyKind
        var network: ZcashNetwork
    }

    private func classifyHRP(_ hrp: String) -> ClassifiedHRP? {
        switch hrp {
        case "uview", "uview1":
            ClassifiedHRP(kind: .ufvk, network: .mainnet)
        case "uviewtest", "uviewtest1":
            ClassifiedHRP(kind: .ufvk, network: .testnet)
        case "uivk", "uivk1", "uvi":
            ClassifiedHRP(kind: .uivk, network: .mainnet)
        case "uivktest", "uivktest1", "uvitest":
            ClassifiedHRP(kind: .uivk, network: .testnet)
        case "zxviews":
            ClassifiedHRP(kind: .legacySaplingFVK, network: .mainnet)
        case "zxviewtests":
            ClassifiedHRP(kind: .legacySaplingFVK, network: .testnet)
        case "zxivks":
            ClassifiedHRP(kind: .legacySaplingIVK, network: .mainnet)
        case "zxivktests":
            ClassifiedHRP(kind: .legacySaplingIVK, network: .testnet)
        default:
            nil
        }
    }
}
