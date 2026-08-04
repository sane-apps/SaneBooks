import Foundation
import SaneBooksCore
import SaneBooksExport

#if DEBUG
    @MainActor
    public extension AppModel {
        /// Launch-arg driven routes for Mini visual / E2E captures (`--e2e-scene=`).
        /// Optional `--e2e-import-db=/path/to/data.db` imports a Zashi/Zodl SDK database first.
        func applyE2ESceneIfNeeded(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
            let scene = arguments
                .first { $0.hasPrefix("--e2e-scene=") }
                .map { String($0.dropFirst("--e2e-scene=".count)) }
            if let dbArg = arguments.first(where: { $0.hasPrefix("--e2e-import-db=") }) {
                let path = String(dbArg.dropFirst("--e2e-import-db=".count))
                if !path.isEmpty {
                    if let scene, scene.hasPrefix("zashi-") {
                        importZashiSDKDatabase(at: URL(fileURLWithPath: path)) { [weak self] in
                            self?.bootstrapZashiImportForE2E(then: scene)
                        }
                        return
                    }
                    importZashiSDKDatabase(at: URL(fileURLWithPath: path))
                }
            }

            switch scene {
            case "onboarding":
                restartOnboarding()
            case "welcome":
                route = .welcome
            case "import":
                route = .importKey
            case "import-demo":
                useDemoKey()
                route = .importKey
            case "sync", "ledger", "detail", "pack", "share":
                bootstrapDemoVaultForE2E(then: scene ?? "ledger")
            case "zashi-ledger", "zashi-detail", "zashi-pack", "zashi-share":
                bootstrapZashiImportForE2E(then: scene ?? "zashi-ledger")
            case "reader":
                route = .reader
            default:
                break
            }
        }

        /// After `--e2e-import-db=`, tag a few rows and jump to ledger/pack/share for Mini captures.
        private func bootstrapZashiImportForE2E(then scene: String) {
            guard vault != nil, !notes.isEmpty else {
                importError = importError ?? "E2E Zashi import produced no notes — check --e2e-import-db= path."
                route = .importKey
                return
            }
            tagSampleNotesForE2E(limit: 5)
            switch scene {
            case "zashi-detail", "detail":
                if let first = notes.first {
                    openNote(first.id)
                } else {
                    route = .ledger
                }
            case "zashi-pack", "pack":
                prepareImportedHistoryPackDraft()
                route = .proofPackBuilder
            case "zashi-share", "share":
                prepareImportedHistoryPackDraft()
                acknowledgePartialHistory = true
                if var draft = packDraft {
                    draft.acknowledgePartialHistory = true
                    packDraft = draft
                }
                route = .sharePack
            default:
                route = .ledger
            }
        }

        /// Tag a handful of inbound notes as Income so proof packs are non-empty.
        private func tagSampleNotesForE2E(limit: Int) {
            guard let vault else { return }
            var updated = notes
            var tagged = 0
            for i in updated.indices where tagged < limit {
                guard updated[i].direction == .inbound || updated[i].direction == .changeCandidate else { continue }
                if updated[i].effectiveKind != .untagged, updated[i].classification?.source == .user {
                    continue
                }
                updated[i].classification = Classification(
                    kind: .income,
                    party: "Client",
                    subtag: "E2E",
                    notes: "Mini visual audit sample tag",
                    source: .user
                )
                tagged += 1
            }
            do {
                try store.replaceNotes(vaultID: vault.id, with: updated)
                notes = updated
            } catch {
                importError = error.localizedDescription
            }
        }

        /// Pack range spans all dated notes (Zashi history is not limited to calendar YTD).
        func prepareImportedHistoryPackDraft() {
            guard let vault else { return }
            let dated = notes.compactMap(\.blockTime)
            let start = dated.min() ?? Date(timeIntervalSince1970: 1_700_000_000)
            let end = dated.max() ?? Date()
            let expires = Calendar.current.date(byAdding: .day, value: defaultPackExpiryDays, to: Date()) ?? Date()
            var draft = PackBuilder.buildDraft(
                vault: vault,
                notes: notes,
                options: PackDraftOptions(
                    rangeStart: start,
                    rangeEnd: end,
                    includedKinds: [.income, .expense, .fee],
                    includeMemos: includeMemosByDefault,
                    includeChange: false,
                    excludeTags: [],
                    recipientLabel: defaultRecipientLabel.isEmpty ? nil : defaultRecipientLabel,
                    expiresAt: expires
                ),
                cursor: cursor
            )
            draft.acknowledgePartialHistory = acknowledgePartialHistory
            packDraft = draft
        }

        private func bootstrapDemoVaultForE2E(then scene: String) {
            useDemoKey()
            // Reuse the existing demo vault when present — never stack duplicates per launch.
            let demoFP = ViewingKeyValidator().validate(
                ViewingKeyValidator.fixtureMainnetUFVK,
                selectedNetwork: .mainnet
            )
            if case let .accept(_, _, _, fingerprint, _) = demoFP,
               let existing = (try? store.allVaults())?.first(where: { $0.keyFingerprint == fingerprint })
            {
                switchVault(existing.id)
            } else {
                finishImport()
            }
            Task {
                for _ in 0 ..< 80 {
                    if cursor?.status == .caughtUp
                        || cursor?.status == .capabilityBlocked
                        || cursor?.status == .idle
                    {
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                await refreshFromSync()
                switch scene {
                case "sync":
                    route = .syncing
                case "detail":
                    route = .ledger
                    if let first = notes.first {
                        route = .noteDetail(first.id)
                    }
                case "pack":
                    beginProofPack()
                case "share":
                    prepareDefaultPackDraft()
                    acknowledgePartialHistory = true
                    if var draft = packDraft {
                        draft.acknowledgePartialHistory = true
                        packDraft = draft
                    }
                    route = .sharePack
                default:
                    route = .ledger
                }
            }
        }

        func prepareDefaultPackDraft() {
            guard let vault else { return }
            let cal = Calendar.current
            let year = cal.component(.year, from: Date())
            let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
            let end = cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
            let expires = cal.date(byAdding: .day, value: defaultPackExpiryDays, to: Date()) ?? Date()
            var draft = PackBuilder.buildDraft(
                vault: vault,
                notes: notes,
                options: PackDraftOptions(
                    rangeStart: start,
                    rangeEnd: end,
                    includedKinds: [.income, .expense, .fee],
                    includeMemos: includeMemosByDefault,
                    includeChange: false,
                    excludeTags: [],
                    recipientLabel: defaultRecipientLabel.isEmpty ? nil : defaultRecipientLabel,
                    expiresAt: expires
                ),
                cursor: cursor
            )
            draft.acknowledgePartialHistory = acknowledgePartialHistory
            packDraft = draft
        }
    }
#endif
