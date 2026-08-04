import CommonCrypto
import CryptoKit
import Foundation
import SaneBooksCore
import Security

public enum PackCrypto {
    public static let magic = Data("SANEBOOK".utf8)
    public static let schemaVersion: UInt16 = 2
    public static let kdfName = "pbkdf2-hmac-sha256"
    public static let kdfIterations = 600_000
    public static let aeadName = "chacha20poly1305"
    public static let formatContext = "sanebooks-pack-v2"

    public enum Limits {
        public static let saltBytes = 16
        public static let nonceBytes = 12
        public static let keyBytes = 32
        public static let minimumPassphraseCharacters = 12
        public static let maximumPassphraseBytes = 1024
        public static let maximumHeaderBytes = 4 * 1024
        public static let maximumPlaintextBytes = 64 * 1024 * 1024
        public static let maximumCiphertextBytes = maximumPlaintextBytes + nonceBytes + 16
        public static let maxContainerBytes = 14 + maximumHeaderBytes + maximumCiphertextBytes
        public static let maximumRows = 100_000
        public static let maximumCategories = 10000
        public static let maximumStringBytes = 64 * 1024
    }

    /// The only metadata visible before unlock. Its exact canonical bytes are AEAD associated data.
    public struct ContainerHeader: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        public var kdf: String
        public var kdfIterations: Int
        public var aead: String
        public var salt: String

        public init(
            schemaVersion: Int = Int(PackCrypto.schemaVersion),
            kdf: String = PackCrypto.kdfName,
            kdfIterations: Int = PackCrypto.kdfIterations,
            aead: String = PackCrypto.aeadName,
            salt: String
        ) {
            self.schemaVersion = schemaVersion
            self.kdf = kdf
            self.kdfIterations = kdfIterations
            self.aead = aead
            self.salt = salt
        }
    }

    /// Bookkeeping metadata is encrypted in v2. This public result type is populated only after unlock.
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
        public var kdfIterations: Int
        public var aead: String
        public var salt: String
        public var nonce: String
        public var kdfInfo: String
        public var partialHistory: Bool
        public var vaultMode: VaultMode
        public var ironwoodCapable: Bool

        public init(
            schemaVersion: Int = Int(PackCrypto.schemaVersion),
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
            kdfIterations: Int = PackCrypto.kdfIterations,
            aead: String = PackCrypto.aeadName,
            salt: String,
            nonce: String,
            kdfInfo: String = PackCrypto.formatContext,
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
            self.kdfIterations = kdfIterations
            self.aead = aead
            self.salt = salt
            self.nonce = nonce
            self.kdfInfo = kdfInfo
            self.partialHistory = partialHistory
            self.vaultMode = vaultMode
            self.ironwoodCapable = ironwoodCapable
        }
    }

    public struct PrivateMetadata: Codable, Sendable, Equatable {
        public var network: ZcashNetwork
        public var vaultFingerprint: String
        public var vaultDisplayName: String
        public var rangeStart: Date
        public var rangeEnd: Date
        public var createdAt: Date
        public var recipientLabel: String?
        public var partialHistory: Bool
        public var vaultMode: VaultMode
        public var ironwoodCapable: Bool

        public init(
            network: ZcashNetwork,
            vaultFingerprint: String,
            vaultDisplayName: String,
            rangeStart: Date,
            rangeEnd: Date,
            createdAt: Date = Date(),
            recipientLabel: String? = nil,
            partialHistory: Bool,
            vaultMode: VaultMode,
            ironwoodCapable: Bool
        ) {
            self.network = network
            self.vaultFingerprint = vaultFingerprint
            self.vaultDisplayName = vaultDisplayName
            self.rangeStart = rangeStart
            self.rangeEnd = rangeEnd
            self.createdAt = createdAt
            self.recipientLabel = recipientLabel
            self.partialHistory = partialHistory
            self.vaultMode = vaultMode
            self.ironwoodCapable = ironwoodCapable
        }
    }

    public struct PlaintextPayload: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        public var metadata: PrivateMetadata
        public var expiresAt: Date
        public var attestation: SyncAttestation
        public var rows: [ProofPackRow]
        public var rollups: ProofPackRollups
        public var integrity: IntegrityBox

        public init(
            schemaVersion: Int = Int(PackCrypto.schemaVersion),
            metadata: PrivateMetadata,
            expiresAt: Date,
            attestation: SyncAttestation,
            rows: [ProofPackRow],
            rollups: ProofPackRollups,
            integrity: IntegrityBox
        ) {
            self.schemaVersion = schemaVersion
            self.metadata = metadata
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

    public struct DecodedContainer: Sendable {
        public var header: ContainerHeader
        public var canonicalHeaderData: Data
        public var ciphertext: Data
    }

    public static func deriveKey(
        passphrase: String,
        salt: Data,
        iterations: Int = kdfIterations
    ) throws -> SymmetricKey {
        guard passphrase.utf8.count <= Limits.maximumPassphraseBytes else {
            throw SaneBooksError.pack("Passphrase is too long.")
        }
        let normalized = passphrase.precomposedStringWithCompatibilityMapping
        let password = Data(normalized.utf8)
        guard normalized.count >= Limits.minimumPassphraseCharacters else {
            throw SaneBooksError.pack("Passphrase must be at least 12 characters.")
        }
        guard password.count <= Limits.maximumPassphraseBytes else {
            throw SaneBooksError.pack("Passphrase is too long.")
        }
        guard salt.count == Limits.saltBytes else {
            throw SaneBooksError.pack("Invalid password salt.")
        }
        guard iterations == kdfIterations else {
            throw SaneBooksError.pack("Unsupported password-hardening parameters.")
        }

        var derived = [UInt8](repeating: 0, count: Limits.keyBytes)
        let derivedCount = derived.count
        let status = password.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                derived.withUnsafeMutableBytes { outputBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        outputBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        derivedCount
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw SaneBooksError.pack("Password hardening failed.")
        }
        return SymmetricKey(data: derived)
    }

    static func secureRandomBytes(count: Int) throws -> Data {
        guard count > 0 else { throw SaneBooksError.pack("Invalid random byte request.") }
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw SaneBooksError.pack("Secure randomness is unavailable.")
        }
        return Data(bytes)
    }

    public static func seal(
        plaintext: Data,
        key: SymmetricKey,
        nonce: ChaChaPoly.Nonce,
        authenticating associatedData: Data
    ) throws -> Data {
        guard plaintext.count <= Limits.maximumPlaintextBytes else {
            throw SaneBooksError.pack("Pack payload is too large.")
        }
        let sealed = try ChaChaPoly.seal(
            plaintext,
            using: key,
            nonce: nonce,
            authenticating: associatedData
        )
        return sealed.combined
    }

    public static func open(
        combined: Data,
        key: SymmetricKey,
        authenticating associatedData: Data
    ) throws -> Data {
        guard combined.count >= Limits.nonceBytes + 16,
              combined.count <= Limits.maximumCiphertextBytes
        else {
            throw SaneBooksError.pack("Invalid encrypted payload size.")
        }
        let box = try ChaChaPoly.SealedBox(combined: combined)
        let plaintext = try ChaChaPoly.open(box, using: key, authenticating: associatedData)
        guard plaintext.count <= Limits.maximumPlaintextBytes else {
            throw SaneBooksError.pack("Pack payload is too large.")
        }
        return plaintext
    }

    public static func encodeContainer(header: ContainerHeader, ciphertext: Data) throws -> Data {
        let headerData = try CanonicalJSON.encode(header)
        return try encodeContainer(canonicalHeaderData: headerData, ciphertext: ciphertext)
    }

    public static func encodeContainer(canonicalHeaderData headerData: Data, ciphertext: Data) throws -> Data {
        guard !headerData.isEmpty, headerData.count <= Limits.maximumHeaderBytes else {
            throw SaneBooksError.pack("Invalid pack header size.")
        }
        guard ciphertext.count >= Limits.nonceBytes + 16,
              ciphertext.count <= Limits.maximumCiphertextBytes
        else {
            throw SaneBooksError.pack("Invalid encrypted payload size.")
        }
        let totalCount = 14 + headerData.count + ciphertext.count
        guard totalCount <= Limits.maxContainerBytes else {
            throw SaneBooksError.pack("Pack is too large.")
        }

        var out = Data()
        out.reserveCapacity(totalCount)
        out.append(magic)
        out.append(contentsOf: uint16Bytes(schemaVersion))
        out.append(contentsOf: uint32Bytes(UInt32(headerData.count)))
        out.append(headerData)
        out.append(ciphertext)
        return out
    }

    public static func decodeContainer(_ data: Data) throws -> DecodedContainer {
        guard data.count <= Limits.maxContainerBytes else {
            throw SaneBooksError.pack("Pack is too large.")
        }
        guard data.count >= 14 else { throw SaneBooksError.pack("Truncated pack.") }
        guard data.prefix(magic.count) == magic else { throw SaneBooksError.invalidPack }

        let version = readUInt16(data, at: 8)
        if version == 1 {
            throw SaneBooksError.pack(
                "This proof pack uses retired format 1. Ask the sender to re-export it with the current SaneBooks."
            )
        }
        guard version == schemaVersion else {
            throw SaneBooksError.unsupportedSchema(Int(version))
        }

        let headerLength = Int(readUInt32(data, at: 10))
        guard headerLength > 0, headerLength <= Limits.maximumHeaderBytes else {
            throw SaneBooksError.pack("Invalid pack header size.")
        }
        let headerStart = 14
        guard headerLength <= data.count - headerStart else {
            throw SaneBooksError.pack("Truncated pack header.")
        }
        let headerEnd = headerStart + headerLength
        let ciphertextLength = data.count - headerEnd
        guard ciphertextLength >= Limits.nonceBytes + 16,
              ciphertextLength <= Limits.maximumCiphertextBytes
        else {
            throw SaneBooksError.pack("Invalid encrypted payload size.")
        }

        let headerData = data.subdata(in: headerStart ..< headerEnd)
        let header = try CanonicalJSON.decode(ContainerHeader.self, from: headerData)
        guard try CanonicalJSON.encode(header) == headerData else {
            throw SaneBooksError.pack("Pack header is not canonical.")
        }
        try validate(header: header)

        return DecodedContainer(
            header: header,
            canonicalHeaderData: headerData,
            ciphertext: data.subdata(in: headerEnd ..< data.count)
        )
    }

    public static func validate(header: ContainerHeader) throws {
        guard header.schemaVersion == Int(schemaVersion) else {
            throw SaneBooksError.unsupportedSchema(header.schemaVersion)
        }
        guard header.kdf == kdfName,
              header.kdfIterations == kdfIterations,
              header.aead == aeadName
        else {
            throw SaneBooksError.pack("Unsupported pack encryption parameters.")
        }
        guard let salt = Data(base64Encoded: header.salt),
              salt.count == Limits.saltBytes,
              salt.base64EncodedString() == header.salt
        else {
            throw SaneBooksError.pack("Invalid password salt.")
        }
    }

    public static func validate(payload: PlaintextPayload, allowBlankIntegrity: Bool = false) throws {
        guard payload.schemaVersion == Int(schemaVersion) else {
            throw SaneBooksError.unsupportedSchema(payload.schemaVersion)
        }
        guard payload.rows.count <= Limits.maximumRows else {
            throw SaneBooksError.pack("Pack contains too many rows.")
        }
        guard payload.rollups.byCategory.count <= Limits.maximumCategories else {
            throw SaneBooksError.pack("Pack contains too many categories.")
        }
        guard payload.attestation.poolsPresent.count <= ShieldedPool.allCases.count else {
            throw SaneBooksError.pack("Pack contains an invalid pool list.")
        }
        guard payload.metadata.vaultMode == payload.attestation.vaultMode,
              payload.metadata.ironwoodCapable == payload.attestation.ironwoodCapable
        else {
            throw SaneBooksError.pack("Pack metadata is inconsistent.")
        }
        guard payload.integrity.alg == "sha256" else {
            throw SaneBooksError.pack("Unsupported integrity algorithm.")
        }
        if !allowBlankIntegrity {
            let hash = payload.integrity.plaintextCanonicalHash
            let isLowercaseHex = hash.utf8.allSatisfy { byte in
                (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
            }
            guard hash.utf8.count == 64, isLowercaseHex else {
                throw SaneBooksError.pack("Invalid integrity value.")
            }
        }

        try validateIdentityString(payload.metadata.vaultFingerprint)
        try validateIdentityString(payload.metadata.vaultDisplayName)
        try validateOptionalIdentityString(payload.metadata.recipientLabel)
        try validateIdentityString(payload.attestation.lwdEndpointFingerprint)
        try validateMemoString(payload.attestation.disclaimer)
        try validateIdentityString(payload.rollups.fiatCurrency)
        for category in payload.rollups.byCategory.keys {
            try validateIdentityString(category)
        }
        for row in payload.rows {
            try validateOptionalIdentityString(row.party)
            try validateOptionalIdentityString(row.subtag)
            if let memo = row.memoText {
                try validateMemoString(memo)
            }
            try validateIdentityString(row.txidTruncated)
            if let fiatMark = row.fiatMark {
                try validateIdentityString(fiatMark.currency)
            }
        }
        try PackSemanticValidator.validate(payload)
    }

    private static func validateOptionalIdentityString(_ value: String?) throws {
        if let value {
            try validateIdentityString(value)
        }
    }

    private static func validateIdentityString(_ value: String) throws {
        guard EvidenceTextPolicy.isValidIdentity(value) else {
            throw SaneBooksError.pack("Pack contains an unsafe or oversized identity field.")
        }
    }

    private static func validateMemoString(_ value: String) throws {
        guard EvidenceTextPolicy.isValidMemo(value) else {
            throw SaneBooksError.pack("Pack contains an unsafe or oversized memo field.")
        }
    }

    private static func uint16Bytes(_ value: UInt16) -> [UInt8] {
        [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    private static func uint32Bytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF),
        ]
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }
}
