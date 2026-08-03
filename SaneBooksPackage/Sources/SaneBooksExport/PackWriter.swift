import CryptoKit
import Foundation
import SaneBooksCore
import Security

public enum PackWriter {
    public struct EncodedPack: Sendable {
        public var data: Data
        public var integrityHash: String
    }

    public static func seal(
        draft: ProofPackDraft,
        passphrase: String,
        salt: Data? = nil,
        nonceData: Data? = nil
    ) throws -> EncodedPack {
        if draft.partialHistory, !draft.acknowledgePartialHistory {
            throw SaneBooksError.pack(
                "Partial history not acknowledged. Sync is incomplete or history may be missing — acknowledge before sealing."
            )
        }
        var payload = PackCrypto.PlaintextPayload(
            expiresAt: draft.expiresAt,
            attestation: draft.syncAttestation,
            rows: draft.rows,
            rollups: draft.rollups,
            integrity: PackCrypto.IntegrityBox(plaintextCanonicalHash: "")
        )
        let hash = try CanonicalJSON.hashPayload(payload)
        payload.integrity.plaintextCanonicalHash = hash
        let plaintext = try CanonicalJSON.encode(payload)

        let saltBytes: Data
        if let salt {
            saltBytes = salt
        } else {
            var buf = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, buf.count, &buf)
            saltBytes = Data(buf)
        }

        let nonceBytes: Data
        if let nonceData {
            guard nonceData.count == 12 else { throw SaneBooksError.pack("Nonce must be 12 bytes") }
            nonceBytes = nonceData
        } else {
            var buf = [UInt8](repeating: 0, count: 12)
            _ = SecRandomCopyBytes(kSecRandomDefault, buf.count, &buf)
            nonceBytes = Data(buf)
        }

        let nonce = try ChaChaPoly.Nonce(data: nonceBytes)
        let key = PackCrypto.deriveKey(passphrase: passphrase, salt: saltBytes)
        let ciphertext = try PackCrypto.seal(plaintext: plaintext, key: key, nonce: nonce)

        let header = PackCrypto.PublicHeader(
            network: draft.network,
            vaultFingerprint: draft.vaultFingerprint,
            vaultDisplayName: draft.vaultDisplayName,
            rangeStart: draft.rangeStart,
            rangeEnd: draft.rangeEnd,
            expiresAt: draft.expiresAt,
            recipientLabel: draft.recipientLabel,
            salt: saltBytes.base64EncodedString(),
            nonce: nonceBytes.base64EncodedString(),
            partialHistory: draft.partialHistory,
            vaultMode: draft.vaultMode,
            ironwoodCapable: draft.syncAttestation.ironwoodCapable
        )
        let data = try PackCrypto.encodeContainer(header: header, ciphertext: ciphertext)
        try PackBuilder.assertNoUVKMaterial(in: data)
        return EncodedPack(data: data, integrityHash: hash)
    }
}

public typealias PackAEAD = PackWriter
