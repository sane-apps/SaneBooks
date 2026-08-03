import Foundation

public enum SaneBooksError: Error, Sendable, Equatable, LocalizedError {
    case seedRejected
    case spendingKeyRejected
    case garbageKey
    case networkMismatch(expected: ZcashNetwork, detected: ZcashNetwork)
    case unsupportedKey
    case keychain(String)
    case ledger(String)
    case sync(String)
    case syncBlocked(String)
    case pack(String)
    case expired
    case packExpired(Date)
    case wrongPassphrase
    case tampered
    case packTampered
    case unsupportedSchema(Int)
    case packUnsupportedVersion(Int)
    case invalidPack
    case persistFailed(String)
    case noVault
    case cancelled

    public var errorDescription: String? {
        userFacingMessage
    }

    public var userFacingMessage: String {
        switch self {
        case .seedRejected:
            "This looks like a seed phrase. SaneBooks only accepts viewing keys (uview…). Never paste a seed."
        case .spendingKeyRejected:
            "This looks like a spending key. SaneBooks only accepts viewing keys (uview…). It cannot spend funds."
        case .garbageKey:
            "That does not look like a valid viewing key (uview… / uviewtest…)."
        case let .networkMismatch(expected, detected):
            "This key is for \(detected.displayName). Switch network to \(detected.displayName) or paste a \(expected.displayName) key."
        case .unsupportedKey:
            "This key type is not supported in v1."
        case let .keychain(detail), let .ledger(detail), let .sync(detail), let .pack(detail), let .persistFailed(detail):
            detail
        case let .syncBlocked(reason):
            reason
        case .expired, .packExpired:
            "This proof pack has expired."
        case .wrongPassphrase:
            "Wrong passphrase."
        case .tampered, .packTampered:
            "Pack integrity check failed."
        case let .unsupportedSchema(version), let .packUnsupportedVersion(version):
            "Update SaneBooks to open schema version \(version)."
        case .invalidPack:
            "Not a valid .sanebooks file."
        case .noVault:
            "No vault is open."
        case .cancelled:
            "Cancelled."
        }
    }
}
