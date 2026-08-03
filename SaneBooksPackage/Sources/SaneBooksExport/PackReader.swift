import Foundation
import SaneBooksCore

public struct PackOpenResult: Sendable {
    public var header: PackCrypto.PublicHeader
    public var payload: PackCrypto.PlaintextPayload
}

public enum PackReader {
    public static func readHeader(_ data: Data) throws -> PackCrypto.PublicHeader {
        try PackCrypto.decodeContainer(data).header
    }

    public static func open(
        _ data: Data,
        passphrase: String,
        now: Date = Date()
    ) throws -> PackOpenResult {
        let (header, ciphertext) = try PackCrypto.decodeContainer(data)
        guard let salt = Data(base64Encoded: header.salt) else {
            throw SaneBooksError.pack("Bad salt")
        }
        let key = PackCrypto.deriveKey(passphrase: passphrase, salt: salt)

        let plaintext: Data
        do {
            plaintext = try PackCrypto.open(combined: ciphertext, key: key)
        } catch {
            throw SaneBooksError.wrongPassphrase
        }

        let payload = try CanonicalJSON.decode(PackCrypto.PlaintextPayload.self, from: plaintext)
        let expectedHash = try CanonicalJSON.hashPayload(payload)
        guard payload.integrity.plaintextCanonicalHash == expectedHash else {
            throw SaneBooksError.tampered
        }
        guard abs(payload.expiresAt.timeIntervalSince(header.expiresAt)) < 1.0 else {
            throw SaneBooksError.tampered
        }
        if now > header.expiresAt || now > payload.expiresAt {
            throw SaneBooksError.expired
        }
        return PackOpenResult(header: header, payload: payload)
    }
}
