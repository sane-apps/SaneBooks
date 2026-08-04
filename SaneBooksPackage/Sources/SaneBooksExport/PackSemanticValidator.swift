import Foundation
import SaneBooksCore

enum PackSemanticValidator {
    static func validate(_ payload: PackCrypto.PlaintextPayload) throws {
        let metadata = payload.metadata
        guard metadata.rangeStart <= metadata.rangeEnd else {
            throw SaneBooksError.pack("Pack date range is inconsistent.")
        }
        guard payload.rows.allSatisfy({
            $0.date >= metadata.rangeStart && $0.date <= metadata.rangeEnd
        }) else {
            throw SaneBooksError.pack("Pack contains a row outside its declared date range.")
        }
        guard payload.rows.allSatisfy({
            $0.amountZEC >= 0 && ($0.amountFiat == nil || $0.amountFiat! >= 0)
        }) else {
            throw SaneBooksError.pack("Pack contains an invalid negative amount.")
        }

        let expected = rollups(for: payload.rows, fiatCurrency: payload.rollups.fiatCurrency)
        guard payload.rollups == expected else {
            throw SaneBooksError.pack("Pack accounting totals are inconsistent.")
        }

        let listedPools = payload.attestation.poolsPresent
        let listedPoolSet = Set(listedPools)
        let rowPoolSet = Set(payload.rows.map(\.pool))
        guard listedPoolSet.count == listedPools.count, listedPoolSet == rowPoolSet else {
            throw SaneBooksError.pack("Pack pool attestation is inconsistent.")
        }
        if rowPoolSet.contains(.ironwood), !payload.attestation.ironwoodCapable {
            throw SaneBooksError.pack("Pack Ironwood attestation is inconsistent.")
        }
        if let tip = payload.attestation.chainTipAtExport,
           payload.attestation.syncedToHeight > tip
        {
            throw SaneBooksError.pack("Pack sync heights are inconsistent.")
        }
    }

    static func rollups(
        for rows: [ProofPackRow],
        fiatCurrency: String
    ) -> ProofPackRollups {
        var byCategory: [String: Decimal] = [:]
        for row in rows where row.kind == .income || row.kind == .expense {
            let key = row.subtag ?? row.party ?? row.kind.displayName
            byCategory[key, default: 0] += row.amountZEC
        }
        return ProofPackRollups(
            incomeZEC: sumZEC(rows, kind: .income),
            expenseZEC: sumZEC(rows, kind: .expense),
            feeZEC: sumZEC(rows, kind: .fee),
            incomeFiat: sumFiat(rows, kind: .income),
            expenseFiat: sumFiat(rows, kind: .expense),
            fiatCurrency: fiatCurrency,
            byCategory: byCategory
        )
    }

    private static func sumZEC(_ rows: [ProofPackRow], kind: ClassificationKind) -> Decimal {
        rows.lazy.filter { $0.kind == kind }.reduce(0) { $0 + $1.amountZEC }
    }

    private static func sumFiat(_ rows: [ProofPackRow], kind: ClassificationKind) -> Decimal? {
        let values = rows.lazy.filter { $0.kind == kind }.compactMap(\.amountFiat)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }
}
