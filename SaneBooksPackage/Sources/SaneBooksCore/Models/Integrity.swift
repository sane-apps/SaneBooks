import Foundation

public struct IntegrityManifest: Codable, Sendable, Equatable {
    public var alg: String
    public var plaintextCanonicalHash: String
    public var packSchemaVersion: Int
    public var createdAt: Date
    public var expiresAt: Date
    public var network: ZcashNetwork
    public var rowCount: Int
    public var vaultFingerprint: String

    public init(
        alg: String = "sha256",
        plaintextCanonicalHash: String,
        packSchemaVersion: Int = 1,
        createdAt: Date = Date(),
        expiresAt: Date,
        network: ZcashNetwork,
        rowCount: Int,
        vaultFingerprint: String
    ) {
        self.alg = alg
        self.plaintextCanonicalHash = plaintextCanonicalHash
        self.packSchemaVersion = packSchemaVersion
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.network = network
        self.rowCount = rowCount
        self.vaultFingerprint = vaultFingerprint
    }
}

public struct AEADHeader: Codable, Sendable, Equatable {
    public var salt: Data
    public var nonce: Data
    public var kdf: String
    public var aead: String
    public var kdfInfo: String

    public init(
        salt: Data,
        nonce: Data,
        kdf: String = "hkdf-sha256",
        aead: String = "chacha20poly1305",
        kdfInfo: String = "sanebooks-pack-v1"
    ) {
        self.salt = salt
        self.nonce = nonce
        self.kdf = kdf
        self.aead = aead
        self.kdfInfo = kdfInfo
    }
}

public struct PackSeal: Codable, Sendable, Equatable {
    public var manifest: IntegrityManifest
    public var aead: AEADHeader

    public init(manifest: IntegrityManifest, aead: AEADHeader) {
        self.manifest = manifest
        self.aead = aead
    }
}
