import Foundation

public enum ShareExportFormat: String, Codable, Sendable, CaseIterable {
    case sanebooks
    case csv
    case pdf

    public var displayName: String {
        switch self {
        case .sanebooks: "Encrypted pack (.sanebooks)"
        case .csv: "CSV"
        case .pdf: "PDF summary"
        }
    }
}

public struct ShareHistoryEntry: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var expiresAt: Date?
    public var recipientLabel: String?
    public var rangeStart: Date
    public var rangeEnd: Date
    public var integrityHash: String?
    public var format: ShareExportFormat
    public var rowCount: Int
    public var vaultFingerprint: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        recipientLabel: String? = nil,
        rangeStart: Date,
        rangeEnd: Date,
        integrityHash: String? = nil,
        format: ShareExportFormat,
        rowCount: Int,
        vaultFingerprint: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.recipientLabel = recipientLabel
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.integrityHash = integrityHash
        self.format = format
        self.rowCount = rowCount
        self.vaultFingerprint = vaultFingerprint
    }
}
