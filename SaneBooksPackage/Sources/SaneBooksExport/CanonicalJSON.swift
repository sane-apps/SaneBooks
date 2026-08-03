import CryptoKit
import Foundation
import SaneBooksCore

public enum CanonicalJSON {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encode(_ value: some Encodable) throws -> Data {
        try makeEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Hash of payload with integrity.plaintextCanonicalHash blanked.
    public static func hashPayload(_ payload: PackCrypto.PlaintextPayload) throws -> String {
        var copy = payload
        copy.integrity.plaintextCanonicalHash = ""
        let data = try encode(copy)
        return sha256Hex(data)
    }
}
