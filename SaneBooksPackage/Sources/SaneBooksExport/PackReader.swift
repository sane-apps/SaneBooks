import CryptoKit
import Foundation
import SaneBooksCore

public struct PackOpenResult: Sendable {
    public var header: PackCrypto.PublicHeader
    public var payload: PackCrypto.PlaintextPayload
}

public enum PackReader {
    public static let maximumContainerBytes = PackCrypto.Limits.maxContainerBytes

    /// Returns only the intentionally minimal metadata visible before unlock.
    public static func readHeader(_ data: Data) throws -> PackCrypto.ContainerHeader {
        try PackCrypto.decodeContainer(data).header
    }

    /// Reads at most one byte beyond the supported limit so a hostile file is rejected before allocation.
    public static func open(
        _ url: URL,
        passphrase: String,
        now: Date = Date()
    ) throws -> PackOpenResult {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else {
            throw SaneBooksError.invalidPack
        }
        if let fileSize = values.fileSize, fileSize > maximumContainerBytes {
            throw SaneBooksError.pack("Pack is too large.")
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumContainerBytes + 1) ?? Data()
        guard data.count <= maximumContainerBytes else {
            throw SaneBooksError.pack("Pack is too large.")
        }
        return try open(data, passphrase: passphrase, now: now)
    }

    public static func open(
        _ data: Data,
        passphrase: String,
        now: Date = Date()
    ) throws -> PackOpenResult {
        let container = try PackCrypto.decodeContainer(data)
        guard let salt = Data(base64Encoded: container.header.salt) else {
            throw SaneBooksError.pack("Invalid password salt.")
        }
        let key: SymmetricKey
        do {
            key = try PackCrypto.deriveKey(
                passphrase: passphrase,
                salt: salt,
                iterations: container.header.kdfIterations
            )
        } catch {
            throw SaneBooksError.pack("Wrong passphrase or altered file.")
        }

        let plaintext: Data
        do {
            plaintext = try PackCrypto.open(
                combined: container.ciphertext,
                key: key,
                authenticating: container.canonicalHeaderData
            )
        } catch {
            throw SaneBooksError.pack("Wrong passphrase or altered file.")
        }

        let payload: PackCrypto.PlaintextPayload
        do {
            payload = try CanonicalJSON.decode(PackCrypto.PlaintextPayload.self, from: plaintext)
            guard try CanonicalJSON.encode(payload) == plaintext else {
                throw SaneBooksError.tampered
            }
            try PackCrypto.validate(payload: payload)
        } catch let error as SaneBooksError {
            throw error
        } catch {
            throw SaneBooksError.tampered
        }

        let expectedHash = try CanonicalJSON.hashPayload(payload)
        guard payload.integrity.plaintextCanonicalHash == expectedHash else {
            throw SaneBooksError.tampered
        }
        if now > payload.expiresAt {
            throw SaneBooksError.expired
        }

        let metadata = payload.metadata
        let header = PackCrypto.PublicHeader(
            network: metadata.network,
            vaultFingerprint: metadata.vaultFingerprint,
            vaultDisplayName: metadata.vaultDisplayName,
            rangeStart: metadata.rangeStart,
            rangeEnd: metadata.rangeEnd,
            expiresAt: payload.expiresAt,
            createdAt: metadata.createdAt,
            recipientLabel: metadata.recipientLabel,
            kdf: container.header.kdf,
            kdfIterations: container.header.kdfIterations,
            aead: container.header.aead,
            salt: container.header.salt,
            nonce: Data(container.ciphertext.prefix(PackCrypto.Limits.nonceBytes)).base64EncodedString(),
            partialHistory: metadata.partialHistory,
            vaultMode: metadata.vaultMode,
            ironwoodCapable: metadata.ironwoodCapable
        )
        return PackOpenResult(header: header, payload: payload)
    }
}
