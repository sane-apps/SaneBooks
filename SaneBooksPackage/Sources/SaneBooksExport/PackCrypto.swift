import CryptoKit
import Foundation
import SaneBooksCore

public enum PackCrypto {
    public static let magic = Data("SANEBOOK".utf8)
    public static let schemaVersion: UInt16 = 1
    public static let kdfInfo = "sanebooks-pack-v1"
    public static let kdfName = "hkdf-sha256"
    public static let aeadName = "chacha20poly1305"

    public struct PublicHeader: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        public var app: String
        public var network: ZcashNetwork
        public var vaultFingerprint: String
        public var vaultDisplayName: String
        public var rangeStart: Date
        public var rangeEnd: Date
        public var expiresAt: Date
        public var createdAt: Date
        public var recipientLabel: String?
        public var kdf: String
        public var aead: String
        public var salt: String
        public var nonce: String
        public var kdfInfo: String
        public var partialHistory: Bool
        public var vaultMode: VaultMode
        public var ironwoodCapable: Bool

        public init(
            schemaVersion: Int = 1,
            app: String = "SaneBooks",
            network: ZcashNetwork,
            vaultFingerprint: String,
            vaultDisplayName: String,
            rangeStart: Date,
            rangeEnd: Date,
            expiresAt: Date,
            createdAt: Date = Date(),
            recipientLabel: String? = nil,
            kdf: String = PackCrypto.kdfName,
            aead: String = PackCrypto.aeadName,
            salt: String,
            nonce: String,
            kdfInfo: String = PackCrypto.kdfInfo,
            partialHistory: Bool,
            vaultMode: VaultMode,
            ironwoodCapable: Bool
        ) {
            self.schemaVersion = schemaVersion
            self.app = app
            self.network = network
            self.vaultFingerprint = vaultFingerprint
            self.vaultDisplayName = vaultDisplayName
            self.rangeStart = rangeStart
            self.rangeEnd = rangeEnd
            self.expiresAt = expiresAt
            self.createdAt = createdAt
            self.recipientLabel = recipientLabel
            self.kdf = kdf
            self.aead = aead
            self.salt = salt
            self.nonce = nonce
            self.kdfInfo = kdfInfo
            self.partialHistory = partialHistory
            self.vaultMode = vaultMode
            self.ironwoodCapable = ironwoodCapable
        }
    }

    public struct PlaintextPayload: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        public var expiresAt: Date
        public var attestation: SyncAttestation
        public var rows: [ProofPackRow]
        public var rollups: ProofPackRollups
        public var integrity: IntegrityBox

        public init(
            schemaVersion: Int = 1,
            expiresAt: Date,
            attestation: SyncAttestation,
            rows: [ProofPackRow],
            rollups: ProofPackRollups,
            integrity: IntegrityBox
        ) {
            self.schemaVersion = schemaVersion
            self.expiresAt = expiresAt
            self.attestation = attestation
            self.rows = rows
            self.rollups = rollups
            self.integrity = integrity
        }
    }

    public struct IntegrityBox: Codable, Sendable, Equatable {
        public var alg: String
        public var plaintextCanonicalHash: String

        public init(alg: String = "sha256", plaintextCanonicalHash: String) {
            self.alg = alg
            self.plaintextCanonicalHash = plaintextCanonicalHash
        }
    }

    public static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        let normalized = passphrase.precomposedStringWithCompatibilityMapping
        let ikm = SymmetricKey(data: Data(normalized.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: salt,
            info: Data(kdfInfo.utf8),
            outputByteCount: 32
        )
    }

    public static func seal(plaintext: Data, key: SymmetricKey, nonce: ChaChaPoly.Nonce) throws -> Data {
        let sealed = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce)
        return sealed.combined
    }

    public static func open(combined: Data, key: SymmetricKey) throws -> Data {
        let box = try ChaChaPoly.SealedBox(combined: combined)
        return try ChaChaPoly.open(box, using: key)
    }

    public static func encodeContainer(header: PublicHeader, ciphertext: Data) throws -> Data {
        let headerData = try CanonicalJSON.encode(header)
        guard headerData.count <= Int(UInt32.max) else {
            throw SaneBooksError.pack("Header too large")
        }
        var out = Data()
        out.append(magic)
        out.append(UInt16(schemaVersion).bigEndianData)
        out.append(UInt32(headerData.count).bigEndianData)
        out.append(headerData)
        out.append(ciphertext)
        return out
    }

    public static func decodeContainer(_ data: Data) throws -> (header: PublicHeader, ciphertext: Data) {
        guard data.count >= 8 + 2 + 4 else {
            throw SaneBooksError.pack("Truncated pack")
        }
        let magicSlice = data.prefix(8)
        guard magicSlice == magic else {
            throw SaneBooksError.pack("Bad magic")
        }
        let version = UInt16(bigEndianData: data.subdata(in: 8 ..< 10))
        guard version == schemaVersion else {
            throw SaneBooksError.unsupportedSchema(Int(version))
        }
        let headerLen = Int(UInt32(bigEndianData: data.subdata(in: 10 ..< 14)))
        let headerStart = 14
        let headerEnd = headerStart + headerLen
        guard data.count >= headerEnd else {
            throw SaneBooksError.pack("Truncated header")
        }
        let headerData = data.subdata(in: headerStart ..< headerEnd)
        let header = try CanonicalJSON.decode(PublicHeader.self, from: headerData)
        let ciphertext = data.subdata(in: headerEnd ..< data.count)
        return (header, ciphertext)
    }
}

private extension UInt16 {
    var bigEndianData: Data {
        var be = bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt16>.size)
    }

    init(bigEndianData data: Data) {
        self = data.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        var be = bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt32>.size)
    }

    init(bigEndianData data: Data) {
        self = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
}
