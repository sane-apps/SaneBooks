import CryptoKit
import Foundation
import PDFKit
@testable import SaneBooksCore
@testable import SaneBooksExport
import Testing

@Suite("Pack round-trip and adversarial security")
struct PackExportTests {
    enum RandomFailure: Error, Equatable {
        case unavailable
    }

    func sampleDraft(expiresAt: Date) -> ProofPackDraft {
        let row = ProofPackRow(
            date: Date(timeIntervalSince1970: 1_770_000_000),
            kind: .income,
            party: "Client",
            amountZEC: Decimal(string: "1.5")!,
            memoText: "Invoice",
            pool: .ironwood,
            txidTruncated: "aabbccdd…11223344"
        )
        let attestation = SyncAttestation(
            syncedToHeight: 3_500_000,
            chainTipAtExport: 3_500_000,
            lwdEndpointFingerprint: "sha256:deadbeef",
            vaultMode: .bookkeeper,
            poolsPresent: [.ironwood],
            ironwoodCapable: true
        )
        return ProofPackDraft(
            vaultFingerprint: "uview:a1b2c3d4e5f60708",
            vaultDisplayName: "Freelancer",
            network: .mainnet,
            rangeStart: Date(timeIntervalSince1970: 1_700_000_000),
            rangeEnd: Date(timeIntervalSince1970: 1_800_000_000),
            rows: [row],
            rollups: ProofPackRollups(
                incomeZEC: Decimal(string: "1.5")!,
                byCategory: ["Client": Decimal(string: "1.5")!]
            ),
            syncAttestation: attestation,
            partialHistory: false,
            expiresAt: expiresAt,
            vaultMode: .bookkeeper
        )
    }

    @Test
    func roundTripSucceedsWithVersionedPasswordHardening() throws {
        let draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        let pack = try PackBuilder.build(
            draft: draft,
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        #expect(pack.starts(with: Data("SANEBOOK".utf8)))

        let opened = try PackReader.open(pack, passphrase: "correct horse battery")
        #expect(opened.header.vaultFingerprint == "uview:a1b2c3d4e5f60708")
        #expect(opened.payload.rows.count == 1)
        #expect(opened.payload.rows[0].kind == .income)
        #expect(opened.header.schemaVersion == 2)
        #expect(opened.header.kdf == "pbkdf2-hmac-sha256")
        #expect(opened.header.kdfIterations == 600_000)
        #expect(opened.header.aead == "chacha20poly1305")
    }

    @Test
    func publicHeaderDoesNotLeakBookkeepingMetadata() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        draft.recipientLabel = "Acme CPA"
        let encoded = try PackWriter.seal(
            draft: draft,
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        let container = try PackCrypto.decodeContainer(encoded.data)
        let visible = String(decoding: container.canonicalHeaderData, as: UTF8.self)

        #expect(!visible.contains("Freelancer"))
        #expect(!visible.contains("uview:a1b2c3d4e5f60708"))
        #expect(!visible.contains("Acme CPA"))
        #expect(!visible.contains("mainnet"))
        #expect(!visible.contains("partialHistory"))
        #expect(try PackReader.readHeader(encoded.data).kdfIterations == 600_000)
    }

    @Test
    func pbkdf2KnownAnswerMatchesIndependentVector() throws {
        let key = try PackCrypto.deriveKey(
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16)
        )
        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(
            keyData.map { String(format: "%02x", $0) }.joined()
                == "73a5b138dc2cd4bc632bd28ecc67dc407ba4616e2c2bcb624af2aa9eb25f29d2"
        )
    }

    @Test
    func unicodePassphraseNormalizationIsStable() throws {
        let salt = Data(repeating: 0x7A, count: 16)
        let composed = try PackCrypto.deriveKey(passphrase: "caf\u{00e9} password!", salt: salt)
        let decomposed = try PackCrypto.deriveKey(passphrase: "cafe\u{0301} password!", salt: salt)
        #expect(composed.withUnsafeBytes { Data($0) } == decomposed.withUnsafeBytes { Data($0) })
    }

    @Test
    func insecureKDFParametersAreRejected() throws {
        #expect(throws: SaneBooksError.pack("Unsupported password-hardening parameters.")) {
            _ = try PackCrypto.deriveKey(
                passphrase: "correct horse battery",
                salt: Data(repeating: 0x42, count: 16),
                iterations: 1
            )
        }
        #expect(throws: SaneBooksError.pack("Passphrase must be at least 12 characters.")) {
            _ = try PackCrypto.deriveKey(passphrase: "short", salt: Data(repeating: 0x42, count: 16))
        }
        #expect(throws: SaneBooksError.pack("Passphrase is too long.")) {
            _ = try PackCrypto.deriveKey(
                passphrase: String(repeating: "x", count: PackCrypto.Limits.maximumPassphraseBytes + 1),
                salt: Data(repeating: 0x42, count: 16)
            )
        }
    }

    @Test
    func deterministicRandomSourceControlsSaltAndNonce() throws {
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery",
            randomBytes: { count in
                Data(repeating: count == PackCrypto.Limits.saltBytes ? 0xA5 : 0x5A, count: count)
            }
        )
        let container = try PackCrypto.decodeContainer(encoded.data)
        #expect(container.header.salt == Data(repeating: 0xA5, count: 16).base64EncodedString())
        #expect(container.ciphertext.prefix(12) == Data(repeating: 0x5A, count: 12))
    }

    @Test
    func randomFailureAndWrongLengthFailClosed() throws {
        #expect(throws: RandomFailure.unavailable) {
            _ = try PackWriter.seal(
                draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
                passphrase: "correct horse battery",
                randomBytes: { _ in throw RandomFailure.unavailable }
            )
        }
        #expect(throws: SaneBooksError.pack("Invalid password salt.")) {
            _ = try PackWriter.seal(
                draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
                passphrase: "correct horse battery",
                randomBytes: { count in Data(repeating: 0, count: count - 1) }
            )
        }
    }

    @Test
    func wrongPassphraseHasHonestNonOracleError() throws {
        let pack = try PackBuilder.build(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "right passphrase"
        )
        #expect(throws: SaneBooksError.pack("Wrong passphrase or altered file.")) {
            _ = try PackReader.open(pack, passphrase: "wrong passphrase")
        }
    }

    @Test
    func alteredAuthenticatedHeaderHasSameHonestError() throws {
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        var container = try PackCrypto.decodeContainer(encoded.data)
        container.header.salt = Data(repeating: 0x43, count: 16).base64EncodedString()
        let altered = try PackCrypto.encodeContainer(
            header: container.header,
            ciphertext: container.ciphertext
        )

        #expect(throws: SaneBooksError.pack("Wrong passphrase or altered file.")) {
            _ = try PackReader.open(altered, passphrase: "correct horse battery")
        }
    }

    @Test
    func downgradedHeaderWorkFactorIsRejectedWithoutDerivation() throws {
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery"
        )
        var container = try PackCrypto.decodeContainer(encoded.data)
        container.header.kdfIterations = 1
        let downgraded = try PackCrypto.encodeContainer(
            header: container.header,
            ciphertext: container.ciphertext
        )
        #expect(throws: SaneBooksError.pack("Unsupported pack encryption parameters.")) {
            _ = try PackReader.open(downgraded, passphrase: "correct horse battery")
        }
    }

    @Test
    func authenticatedPayloadWithFalseIntegrityHashIsRejected() throws {
        let passphrase = "correct horse battery"
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: passphrase,
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        let container = try PackCrypto.decodeContainer(encoded.data)
        let salt = try #require(Data(base64Encoded: container.header.salt))
        let key = try PackCrypto.deriveKey(passphrase: passphrase, salt: salt)
        let plaintext = try PackCrypto.open(
            combined: container.ciphertext,
            key: key,
            authenticating: container.canonicalHeaderData
        )
        var payload = try CanonicalJSON.decode(PackCrypto.PlaintextPayload.self, from: plaintext)
        payload.integrity.plaintextCanonicalHash = String(repeating: "0", count: 64)
        let alteredPlaintext = try CanonicalJSON.encode(payload)
        let nonce = try ChaChaPoly.Nonce(data: container.ciphertext.prefix(12))
        let alteredCiphertext = try PackCrypto.seal(
            plaintext: alteredPlaintext,
            key: key,
            nonce: nonce,
            authenticating: container.canonicalHeaderData
        )
        let alteredPack = try PackCrypto.encodeContainer(
            canonicalHeaderData: container.canonicalHeaderData,
            ciphertext: alteredCiphertext
        )

        #expect(throws: SaneBooksError.tampered) {
            _ = try PackReader.open(alteredPack, passphrase: passphrase)
        }
    }

    @Test
    func authenticatedPayloadWithFalseAccountingSemanticsIsRejected() throws {
        let draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))

        let falseTotal = try forgeAuthenticatedPack(draft: draft) { payload in
            payload.rollups.incomeZEC += 1
        }
        #expect(throws: SaneBooksError.pack("Pack accounting totals are inconsistent.")) {
            _ = try PackReader.open(falseTotal, passphrase: "correct horse battery")
        }

        let outOfRange = try forgeAuthenticatedPack(draft: draft) { payload in
            payload.rows[0].date = payload.metadata.rangeEnd.addingTimeInterval(1)
        }
        #expect(throws: SaneBooksError.pack("Pack contains a row outside its declared date range.")) {
            _ = try PackReader.open(outOfRange, passphrase: "correct horse battery")
        }

        let falsePools = try forgeAuthenticatedPack(draft: draft) { payload in
            payload.attestation.poolsPresent = [.sapling, .ironwood]
        }
        #expect(throws: SaneBooksError.pack("Pack pool attestation is inconsistent.")) {
            _ = try PackReader.open(falsePools, passphrase: "correct horse battery")
        }

        let impossibleHeight = try forgeAuthenticatedPack(draft: draft) { payload in
            payload.attestation.chainTipAtExport = payload.attestation.syncedToHeight - 1
        }
        #expect(throws: SaneBooksError.pack("Pack sync heights are inconsistent.")) {
            _ = try PackReader.open(impossibleHeight, passphrase: "correct horse battery")
        }
    }

    @Test
    func ciphertextNonceTagTruncationAndExtensionAreRejected() throws {
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        let container = try PackCrypto.decodeContainer(encoded.data)
        let expected = SaneBooksError.pack("Wrong passphrase or altered file.")

        for index in [0, 12, container.ciphertext.count - 1] {
            var bytes = [UInt8](container.ciphertext)
            bytes[index] ^= 0x01
            let altered = try PackCrypto.encodeContainer(
                canonicalHeaderData: container.canonicalHeaderData,
                ciphertext: Data(bytes)
            )
            #expect(throws: expected) {
                _ = try PackReader.open(altered, passphrase: "correct horse battery")
            }
        }

        let truncated = try PackCrypto.encodeContainer(
            canonicalHeaderData: container.canonicalHeaderData,
            ciphertext: container.ciphertext.dropLast()
        )
        #expect(throws: expected) {
            _ = try PackReader.open(truncated, passphrase: "correct horse battery")
        }

        var extendedCiphertext = container.ciphertext
        extendedCiphertext.append(0)
        let extended = try PackCrypto.encodeContainer(
            canonicalHeaderData: container.canonicalHeaderData,
            ciphertext: extendedCiphertext
        )
        #expect(throws: expected) {
            _ = try PackReader.open(extended, passphrase: "correct horse battery")
        }
    }

    @Test
    func nonCanonicalHeaderAndDowngradedVersionAreRejected() throws {
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery"
        )
        let container = try PackCrypto.decodeContainer(encoded.data)
        var nonCanonicalHeader = container.canonicalHeaderData
        nonCanonicalHeader.append(0x20)
        let nonCanonical = try PackCrypto.encodeContainer(
            canonicalHeaderData: nonCanonicalHeader,
            ciphertext: container.ciphertext
        )
        #expect(throws: SaneBooksError.pack("Pack header is not canonical.")) {
            _ = try PackReader.open(nonCanonical, passphrase: "correct horse battery")
        }

        var legacyBytes = [UInt8](encoded.data)
        legacyBytes[8] = 0
        legacyBytes[9] = 1
        #expect(throws: SaneBooksError.pack(
            "This proof pack uses retired format 1. Ask the sender to re-export it with the current SaneBooks."
        )) {
            _ = try PackReader.open(Data(legacyBytes), passphrase: "correct horse battery")
        }
    }

    @Test
    func malformedLengthsAndOversizedURLAreRejectedBeforeUnlock() throws {
        let encoded = try PackWriter.seal(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery"
        )
        #expect(throws: SaneBooksError.pack("Truncated pack.")) {
            _ = try PackReader.open(encoded.data.prefix(13), passphrase: "correct horse battery")
        }

        var badHeaderLength = [UInt8](encoded.data)
        badHeaderLength[10] = 0
        badHeaderLength[11] = 0
        badHeaderLength[12] = 0x10
        badHeaderLength[13] = 0x01
        #expect(throws: SaneBooksError.pack("Invalid pack header size.")) {
            _ = try PackReader.open(Data(badHeaderLength), passphrase: "correct horse battery")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("oversized-\(UUID().uuidString).sanebooks")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(PackReader.maximumContainerBytes + 1))
        try handle.close()
        #expect(throws: SaneBooksError.pack("Pack is too large.")) {
            _ = try PackReader.open(url, passphrase: "correct horse battery")
        }
    }

    @Test
    func rowAndStringLimitsAreEnforcedBeforeEncryption() throws {
        var oversizedString = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        oversizedString.vaultDisplayName = String(
            repeating: "x",
            count: PackCrypto.Limits.maximumStringBytes + 1
        )
        #expect(throws: SaneBooksError.pack("Pack contains an unsafe or oversized identity field.")) {
            _ = try PackWriter.seal(draft: oversizedString, passphrase: "correct horse battery")
        }

        var tooManyRows = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        tooManyRows.rows = Array(
            repeating: tooManyRows.rows[0],
            count: PackCrypto.Limits.maximumRows + 1
        )
        #expect(throws: SaneBooksError.pack("Pack contains too many rows.")) {
            _ = try PackWriter.seal(draft: tooManyRows, passphrase: "correct horse battery")
        }
    }

    @Test
    func expiredPackFails() throws {
        let pack = try PackBuilder.build(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: -3600)),
            passphrase: "correct horse battery"
        )
        #expect(throws: SaneBooksError.expired) {
            _ = try PackReader.open(pack, passphrase: "correct horse battery", now: Date())
        }
    }

    @Test
    func evidenceTextRejectsBidiSpoofingAndOversizedMemos() throws {
        var spoofed = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        spoofed.rows[0].party = "Acme\u{202E}gpj"
        #expect(throws: SaneBooksError.pack("Pack contains an unsafe or oversized identity field.")) {
            _ = try PackWriter.seal(draft: spoofed, passphrase: "correct horse battery")
        }

        var oversized = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        oversized.rows[0].memoText = String(repeating: "x", count: EvidenceTextPolicy.maximumMemoBytes + 1)
        #expect(throws: SaneBooksError.pack("Pack contains an unsafe or oversized memo field.")) {
            _ = try PackWriter.seal(draft: oversized, passphrase: "correct horse battery")
        }
    }

    @Test
    func noUviewKeyStringInPackBytes() throws {
        let fullUVK =
            "uview1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
        let pack = try PackBuilder.build(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "correct horse battery"
        )
        #expect(!pack.containsSubsequence(Data(fullUVK.utf8)))
        let publicHeader = try PackCrypto.decodeContainer(pack).canonicalHeaderData
        #expect(!String(decoding: publicHeader, as: UTF8.self).contains("uview"))
    }

    private func forgeAuthenticatedPack(
        draft: ProofPackDraft,
        mutate: (inout PackCrypto.PlaintextPayload) -> Void
    ) throws -> Data {
        let passphrase = "correct horse battery"
        let encoded = try PackWriter.seal(
            draft: draft,
            passphrase: passphrase,
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        let container = try PackCrypto.decodeContainer(encoded.data)
        let salt = try #require(Data(base64Encoded: container.header.salt))
        let key = try PackCrypto.deriveKey(passphrase: passphrase, salt: salt)
        let plaintext = try PackCrypto.open(
            combined: container.ciphertext,
            key: key,
            authenticating: container.canonicalHeaderData
        )
        var payload = try CanonicalJSON.decode(PackCrypto.PlaintextPayload.self, from: plaintext)
        mutate(&payload)
        payload.integrity.plaintextCanonicalHash = try CanonicalJSON.hashPayload(payload)
        let forgedPlaintext = try CanonicalJSON.encode(payload)
        let nonce = try ChaChaPoly.Nonce(data: container.ciphertext.prefix(12))
        let forgedCiphertext = try PackCrypto.seal(
            plaintext: forgedPlaintext,
            key: key,
            nonce: nonce,
            authenticating: container.canonicalHeaderData
        )
        return try PackCrypto.encodeContainer(
            canonicalHeaderData: container.canonicalHeaderData,
            ciphertext: forgedCiphertext
        )
    }
}

private extension Data {
    func containsSubsequence(_ candidate: Data) -> Bool {
        guard !candidate.isEmpty, candidate.count <= count else { return false }
        return indices.dropLast(candidate.count - 1).contains { start in
            self[start ..< start + candidate.count].elementsEqual(candidate)
        }
    }
}
