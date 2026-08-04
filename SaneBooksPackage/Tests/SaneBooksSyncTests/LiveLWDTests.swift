import Foundation
@testable import SaneBooksCore
@testable import SaneBooksSync
import Testing

/// Opt-in live lightwalletd smoke. Run on Mini:
/// `SANEBOOKS_LIVE_LWD=1 SANEBOOKS_USE_LOCAL_SANEUI=1 swift test --filter LiveLWD`
@Suite("Live LWD", .disabled(if: ProcessInfo.processInfo.environment["SANEBOOKS_LIVE_LWD"] != "1"))
struct LiveLWDTests {
    @Test
    func liveProbeKeyImportsAndSyncs() async throws {
        let sync = LightClientSyncFacade(forceMock: false)
        let vaultID = VaultID()
        let birthday = LiveProbeKey.defaultBirthday
        let requiresFundedReceipt =
            ProcessInfo.processInfo.environment["SANEBOOKS_FUNDED_LIVE_RECEIPT"] == "1"

        let validated = ViewingKeyValidator().validate(
            LiveProbeKey.mainnetUFVK,
            selectedNetwork: .mainnet
        )
        guard case let .accept(kind, _, _, _, _) = validated else {
            Issue.record("LiveProbeKey failed validation: \(validated)")
            return
        }
        #expect(kind == .ufvk)

        await sync.bindCredentials(
            SyncAccountCredentials(
                vaultID: vaultID,
                viewingKey: LiveProbeKey.mainnetUFVK,
                keyKind: .ufvk,
                network: .mainnet,
                birthdayHeight: birthday
            )
        )

        try await sync.start(vaultID: vaultID)

        var last: SyncCursor?
        var reachedWorking = false
        let attempts = requiresFundedReceipt ? 600 : 120
        for _ in 0 ..< attempts {
            let cursor = await sync.currentCursor(vaultID: vaultID)
            last = cursor

            if requiresFundedReceipt {
                let currentNotes = await sync.latestNotes(vaultID: vaultID)
                if currentNotes.contains(where: { $0.pool == .ironwood }) {
                    reachedWorking = true
                    break
                }
            } else if let tip = cursor?.chainTipHeight, tip >= 3_428_143,
                      (cursor?.progressFraction ?? 0) >= 0.05 || cursor?.status == .caughtUp
            {
                reachedWorking = true
                break
            }

            if cursor?.status == .stalled || cursor?.status == .capabilityBlocked {
                Issue.record("Sync failed: \(String(describing: cursor))")
                break
            }
            try await Task.sleep(for: .seconds(2))
        }

        let notes = await sync.latestNotes(vaultID: vaultID)
        await sync.cancel(vaultID: vaultID)

        #expect(reachedWorking, "cursor=\(String(describing: last))")
        #expect((last?.chainTipHeight ?? 0) >= 3_428_143)
        let report = await sync.capabilityReport()
        #expect(report.supportsIronwood == true)
        #expect(report.mainnetSafe == true)

        if requiresFundedReceipt {
            #expect(!notes.isEmpty, "Funded receipt mode requires at least one live note.")
            #expect(
                notes.contains(where: { $0.pool == .ironwood }),
                "Funded receipt mode requires a live Ironwood receive."
            )
            if let highestNote = notes.map(\.blockHeight).max() {
                #expect((last?.chainTipHeight ?? 0) >= highestNote)
            }
        }
    }
}
