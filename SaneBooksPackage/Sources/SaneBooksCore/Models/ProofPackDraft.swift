import Foundation

public struct ProofPackRow: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var kind: ClassificationKind
    public var party: String?
    public var subtag: String?
    public var amountZEC: Decimal
    public var amountFiat: Decimal?
    public var fiatMark: FiatMark?
    public var memoText: String?
    public var pool: ShieldedPool
    public var txidTruncated: String

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: ClassificationKind,
        party: String? = nil,
        subtag: String? = nil,
        amountZEC: Decimal,
        amountFiat: Decimal? = nil,
        fiatMark: FiatMark? = nil,
        memoText: String? = nil,
        pool: ShieldedPool,
        txidTruncated: String
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.party = party
        self.subtag = subtag
        self.amountZEC = amountZEC
        self.amountFiat = amountFiat
        self.fiatMark = fiatMark
        self.memoText = memoText
        self.pool = pool
        self.txidTruncated = txidTruncated
    }
}

public struct ProofPackRollups: Codable, Sendable, Equatable {
    public var incomeZEC: Decimal
    public var expenseZEC: Decimal
    public var feeZEC: Decimal
    public var incomeFiat: Decimal?
    public var expenseFiat: Decimal?
    public var fiatCurrency: String
    public var byCategory: [String: Decimal]

    public init(
        incomeZEC: Decimal = 0,
        expenseZEC: Decimal = 0,
        feeZEC: Decimal = 0,
        incomeFiat: Decimal? = nil,
        expenseFiat: Decimal? = nil,
        fiatCurrency: String = "USD",
        byCategory: [String: Decimal] = [:]
    ) {
        self.incomeZEC = incomeZEC
        self.expenseZEC = expenseZEC
        self.feeZEC = feeZEC
        self.incomeFiat = incomeFiat
        self.expenseFiat = expenseFiat
        self.fiatCurrency = fiatCurrency
        self.byCategory = byCategory
    }
}

public struct ProofPackDraft: Codable, Sendable, Equatable {
    public var id: UUID
    public var vaultFingerprint: String
    public var vaultDisplayName: String
    public var network: ZcashNetwork
    public var rangeStart: Date
    public var rangeEnd: Date
    public var includedKinds: Set<ClassificationKind>
    public var excludeTags: [String]
    public var includeMemos: Bool
    public var includeChange: Bool
    public var rows: [ProofPackRow]
    public var rollups: ProofPackRollups
    public var fiatCurrency: String
    public var syncAttestation: SyncAttestation
    public var partialHistory: Bool
    /// Owner must acknowledge before sealing a partial-history pack.
    public var acknowledgePartialHistory: Bool
    public var recipientLabel: String?
    public var expiresAt: Date
    public var schemaVersion: Int
    public var vaultMode: VaultMode

    public init(
        id: UUID = UUID(),
        vaultFingerprint: String,
        vaultDisplayName: String,
        network: ZcashNetwork,
        rangeStart: Date,
        rangeEnd: Date,
        includedKinds: Set<ClassificationKind> = [.income, .expense, .fee],
        excludeTags: [String] = [],
        includeMemos: Bool = false,
        includeChange: Bool = false,
        rows: [ProofPackRow],
        rollups: ProofPackRollups = ProofPackRollups(),
        fiatCurrency: String = "USD",
        syncAttestation: SyncAttestation,
        partialHistory: Bool,
        acknowledgePartialHistory: Bool = false,
        recipientLabel: String? = nil,
        expiresAt: Date,
        schemaVersion: Int = 1,
        vaultMode: VaultMode
    ) {
        self.id = id
        self.vaultFingerprint = vaultFingerprint
        self.vaultDisplayName = vaultDisplayName
        self.network = network
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.includedKinds = includedKinds
        self.excludeTags = excludeTags
        self.includeMemos = includeMemos
        self.includeChange = includeChange
        self.rows = rows
        self.rollups = rollups
        self.fiatCurrency = fiatCurrency
        self.syncAttestation = syncAttestation
        self.partialHistory = partialHistory
        self.acknowledgePartialHistory = acknowledgePartialHistory
        self.recipientLabel = recipientLabel
        self.expiresAt = expiresAt
        self.schemaVersion = schemaVersion
        self.vaultMode = vaultMode
    }

    public var incomeZEC: Decimal {
        rollups.incomeZEC
    }

    public var expenseZEC: Decimal {
        rollups.expenseZEC
    }

    public var feeZEC: Decimal {
        rollups.feeZEC
    }
}
