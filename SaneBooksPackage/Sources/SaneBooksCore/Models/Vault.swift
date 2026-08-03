import Foundation

public struct VaultID: Hashable, Codable, Sendable {
    public let uuid: UUID

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }
}

public enum ViewingKeyKind: String, Codable, Sendable {
    case ufvk
    case uivk
    case legacySaplingFVK
    case legacySaplingIVK
}

public enum VaultMode: String, Codable, Sendable {
    case bookkeeper
    case receivables
}

public enum ZcashNetwork: String, Codable, Sendable, CaseIterable {
    case mainnet
    case testnet

    public var displayName: String {
        switch self {
        case .mainnet: "Mainnet"
        case .testnet: "Testnet"
        }
    }
}

public struct Vault: Identifiable, Codable, Sendable, Equatable {
    public var id: VaultID
    public var displayName: String
    public var network: ZcashNetwork
    public var keyKind: ViewingKeyKind
    public var keyFingerprint: String
    public var birthdayHeight: UInt32?
    public var createdAt: Date
    public var mode: VaultMode
    public var capabilitiesBanner: String?
    /// Memo auto-tag rules stored with this vault.
    public var tagRules: [TagRule]

    public init(
        id: VaultID = VaultID(),
        displayName: String,
        network: ZcashNetwork,
        keyKind: ViewingKeyKind,
        keyFingerprint: String,
        birthdayHeight: UInt32? = nil,
        createdAt: Date = Date(),
        mode: VaultMode,
        capabilitiesBanner: String? = nil,
        tagRules: [TagRule] = [TagRule.defaultInvoiceSeed]
    ) {
        self.id = id
        self.displayName = displayName
        self.network = network
        self.keyKind = keyKind
        self.keyFingerprint = keyFingerprint
        self.birthdayHeight = birthdayHeight
        self.createdAt = createdAt
        self.mode = mode
        self.capabilitiesBanner = capabilitiesBanner
        self.tagRules = tagRules
    }

    public static func mode(for kind: ViewingKeyKind) -> VaultMode {
        switch kind {
        case .ufvk, .legacySaplingFVK: .bookkeeper
        case .uivk, .legacySaplingIVK: .receivables
        }
    }
}
