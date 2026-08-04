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
            "That looks like a seed phrase. SaneBooks only accepts viewing keys — never paste a seed."
        case .spendingKeyRejected:
            "That looks like a spending key. SaneBooks only accepts viewing keys and cannot move funds."
        case .garbageKey:
            "That does not look like a viewing key. Paste a viewing key from your wallet, not a seed."
        case let .networkMismatch(expected, detected):
            "This key is for \(detected.displayName). Switch network to \(detected.displayName) or paste a \(expected.displayName) key."
        case .unsupportedKey:
            "This key type is not supported yet."
        case let .keychain(detail), let .ledger(detail), let .sync(detail), let .pack(detail), let .persistFailed(detail):
            detail
        case let .syncBlocked(reason):
            reason
        case .expired, .packExpired:
            "This proof pack has expired."
        case .wrongPassphrase:
            "Wrong passphrase."
        case .tampered, .packTampered:
            "This file looks damaged or altered. Ask for a new pack."
        case let .unsupportedSchema(version), let .packUnsupportedVersion(version):
            "Update SaneBooks to open this pack (format \(version))."
        case .invalidPack:
            "That is not a SaneBooks proof pack."
        case .noVault:
            "No books are open yet."
        case .cancelled:
            "Cancelled."
        }
    }
}
