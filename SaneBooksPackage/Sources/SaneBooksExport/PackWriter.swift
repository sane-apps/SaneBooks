import CryptoKit
import Foundation
import SaneBooksCore

typealias PackRandomBytes = @Sendable (_ count: Int) throws -> Data

public enum PackWriter {
    public struct EncodedPack: Sendable {
        public var data: Data
        public var integrityHash: String
    }

    public static func seal(
        draft: ProofPackDraft,
        passphrase: String
    ) throws -> EncodedPack {
        try seal(
            draft: draft,
            passphrase: passphrase,
            salt: nil,
            nonceData: nil,
            randomBytes: { try PackCrypto.secureRandomBytes(count: $0) }
        )
    }

    /// Deterministic crypto inputs are intentionally module-internal for tests.
    /// Production callers cannot supply or accidentally reuse a salt/nonce pair.
    static func seal(
        draft: ProofPackDraft,
        passphrase: String,
        salt: Data,
        nonceData: Data
    ) throws -> EncodedPack {
        try seal(
            draft: draft,
            passphrase: passphrase,
            salt: salt,
            nonceData: nonceData,
            randomBytes: { try PackCrypto.secureRandomBytes(count: $0) }
        )
    }

    static func seal(
        draft: ProofPackDraft,
        passphrase: String,
        salt: Data? = nil,
        nonceData: Data? = nil,
        randomBytes: PackRandomBytes
    ) throws -> EncodedPack {
        if draft.partialHistory, !draft.acknowledgePartialHistory {
            throw SaneBooksError.pack(
                "Partial history not acknowledged. Sync is incomplete or history may be missing — "
                    + "acknowledge before sealing."
            )
        }

        let metadata = PackCrypto.PrivateMetadata(
            network: draft.network,
            vaultFingerprint: draft.vaultFingerprint,
            vaultDisplayName: draft.vaultDisplayName,
            rangeStart: draft.rangeStart,
            rangeEnd: draft.rangeEnd,
            recipientLabel: draft.recipientLabel,
            partialHistory: draft.partialHistory,
            vaultMode: draft.vaultMode,
            ironwoodCapable: draft.syncAttestation.ironwoodCapable
        )
        var payload = PackCrypto.PlaintextPayload(
            metadata: metadata,
            expiresAt: draft.expiresAt,
            attestation: draft.syncAttestation,
            rows: draft.rows,
            rollups: draft.rollups,
            integrity: PackCrypto.IntegrityBox(plaintextCanonicalHash: "")
        )
        try PackCrypto.validate(payload: payload, allowBlankIntegrity: true)
        let hash = try CanonicalJSON.hashPayload(payload)
        payload.integrity.plaintextCanonicalHash = hash
        try PackCrypto.validate(payload: payload)
        let plaintext = try CanonicalJSON.encode(payload)
        guard plaintext.count <= PackCrypto.Limits.maximumPlaintextBytes else {
            throw SaneBooksError.pack("Pack payload is too large.")
        }

        let saltBytes = try validatedRandomBytes(
            supplied: salt,
            count: PackCrypto.Limits.saltBytes,
            name: "password salt",
            randomBytes: randomBytes
        )
        let nonceBytes = try validatedRandomBytes(
            supplied: nonceData,
            count: PackCrypto.Limits.nonceBytes,
            name: "encryption nonce",
            randomBytes: randomBytes
        )

        let containerHeader = PackCrypto.ContainerHeader(salt: saltBytes.base64EncodedString())
        let canonicalHeaderData = try CanonicalJSON.encode(containerHeader)
        guard canonicalHeaderData.count <= PackCrypto.Limits.maximumHeaderBytes else {
            throw SaneBooksError.pack("Pack header is too large.")
        }

        let key = try PackCrypto.deriveKey(passphrase: passphrase, salt: saltBytes)
        let nonce = try ChaChaPoly.Nonce(data: nonceBytes)
        let ciphertext = try PackCrypto.seal(
            plaintext: plaintext,
            key: key,
            nonce: nonce,
            authenticating: canonicalHeaderData
        )
        let data = try PackCrypto.encodeContainer(
            canonicalHeaderData: canonicalHeaderData,
            ciphertext: ciphertext
        )
        try PackBuilder.assertNoUVKMaterial(in: data)
        return EncodedPack(data: data, integrityHash: hash)
    }

    private static func validatedRandomBytes(
        supplied: Data?,
        count: Int,
        name: String,
        randomBytes: PackRandomBytes
    ) throws -> Data {
        let bytes = try supplied ?? randomBytes(count)
        guard bytes.count == count else {
            throw SaneBooksError.pack("Invalid \(name).")
        }
        return bytes
    }
}

public typealias PackAEAD = PackWriter
