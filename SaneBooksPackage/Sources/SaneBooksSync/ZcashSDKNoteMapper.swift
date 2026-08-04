import Foundation
import SaneBooksCore
@preconcurrency import ZcashLightClientKit

enum ZcashSDKNoteMapper {
    struct MappingResult: Sendable {
        var rows: [NoteRow]
        var encounteredUnknownPool: Bool
    }

    static func pool(from outputPool: ZcashTransaction.Output.Pool) -> ShieldedPool? {
        switch outputPool {
        case .sapling:
            return .sapling
        case .orchard:
            return .orchard
        case .transaparent:
            return .transparent
        case let .other(raw):
            // SDK maps Ironwood pool id 4 to `.other(4)` until a named case ships.
            if raw == 4 {
                return .ironwood
            }
            return nil
        }
    }

    static func memoPayload(from memo: Memo?) -> MemoPayload {
        guard let memo else { return .empty }
        switch memo {
        case .empty:
            return .empty
        case let .text(text):
            return .text(text.string)
        case let .arbitrary(bytes):
            return .opaque(Data(bytes))
        case let .future(memoBytes):
            return ZIP302MemoDecoder.decode(Data(memoBytes.bytes))
        }
    }

    static func direction(isChange: Bool) -> NoteDirection {
        isChange ? .changeCandidate : .inbound
    }

    static func stableID(
        vaultID: VaultID,
        txid: Data,
        pool: ShieldedPool,
        outputIndex: Int
    ) -> NoteRowID {
        NoteRowID.stableOutput(
            vaultID: vaultID,
            txid: txid,
            pool: pool,
            outputIndex: UInt32(clamping: outputIndex)
        )
    }

    static func noteRows(
        vaultID: VaultID,
        synchronizer: Synchronizer
    ) async -> MappingResult {
        let transactions = await synchronizer.receivedTransactions
        var rows: [NoteRow] = []
        var encounteredUnknownPool = false
        rows.reserveCapacity(transactions.count)

        for transaction in transactions {
            let height = UInt32(transaction.minedHeight ?? 0)
            guard height > 0 else { continue }
            let outputs = await synchronizer.getTransactionOutputs(for: transaction)
            for output in outputs {
                // Skip transparent outputs for v1 shielded books.
                if case .transaparent = output.pool {
                    continue
                }
                let txid = transaction.rawID
                guard let shieldedPool = pool(from: output.pool) else {
                    encounteredUnknownPool = true
                    continue
                }
                rows.append(
                    NoteRow(
                        id: stableID(
                            vaultID: vaultID,
                            txid: txid,
                            pool: shieldedPool,
                            outputIndex: output.index
                        ),
                        vaultID: vaultID,
                        txid: txid,
                        blockHeight: height,
                        blockTime: nil,
                        pool: shieldedPool,
                        direction: direction(isChange: output.isChange),
                        valueZatoshis: output.value.amount,
                        memo: memoPayload(from: output.memo)
                    )
                )
            }
        }

        let sorted = rows.sorted { lhs, rhs in
            if lhs.blockHeight != rhs.blockHeight {
                return lhs.blockHeight > rhs.blockHeight
            }
            return lhs.txidHex > rhs.txidHex
        }
        return MappingResult(rows: sorted, encounteredUnknownPool: encounteredUnknownPool)
    }
}
