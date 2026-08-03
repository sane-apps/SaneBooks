import Foundation
import Security

public protocol KeychainVaultStore: Sendable {
    func saveViewingKey(_ key: String, vaultID: VaultID) throws
    func loadViewingKey(vaultID: VaultID) throws -> String?
    func deleteViewingKey(vaultID: VaultID) throws
}

public protocol ViewingKeyStore: Sendable {
    func save(_ key: String, for vaultID: VaultID) throws
    func load(for vaultID: VaultID) throws -> String?
    func delete(for vaultID: VaultID) throws
}

/// In-memory store for unit tests.
public final class InMemoryViewingKeyStore: ViewingKeyStore, KeychainVaultStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: String] = [:]

    public init() {}

    public func save(_ key: String, for vaultID: VaultID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[vaultID.uuid] = key
    }

    public func load(for vaultID: VaultID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[vaultID.uuid]
    }

    public func delete(for vaultID: VaultID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: vaultID.uuid)
    }

    public func saveViewingKey(_ key: String, vaultID: VaultID) throws {
        try save(key, for: vaultID)
    }

    public func loadViewingKey(vaultID: VaultID) throws -> String? {
        try load(for: vaultID)
    }

    public func deleteViewingKey(vaultID: VaultID) throws {
        try delete(for: vaultID)
    }
}

/// Keychain-backed viewing key store (`WhenUnlockedThisDeviceOnly`, no iCloud).
public final class KeychainViewingKeyStore: ViewingKeyStore, KeychainVaultStore, @unchecked Sendable {
    public static let servicePrefix = "com.saneapps.SaneBooks.vault"

    public init() {}

    public func save(_ key: String, for vaultID: VaultID) throws {
        let account = vaultID.uuid.uuidString
        let service = "\(Self.servicePrefix).\(account)"
        let data = Data(key.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SaneBooksError.keychain("SecItemAdd \(status)")
        }
    }

    public func load(for vaultID: VaultID) throws -> String? {
        let account = vaultID.uuid.uuidString
        let service = "\(Self.servicePrefix).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw SaneBooksError.keychain("SecItemCopyMatching \(status)")
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete(for vaultID: VaultID) throws {
        let account = vaultID.uuid.uuidString
        let service = "\(Self.servicePrefix).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SaneBooksError.keychain("SecItemDelete \(status)")
        }
    }

    public func saveViewingKey(_ key: String, vaultID: VaultID) throws {
        try save(key, for: vaultID)
    }

    public func loadViewingKey(vaultID: VaultID) throws -> String? {
        try load(for: vaultID)
    }

    public func deleteViewingKey(vaultID: VaultID) throws {
        try delete(for: vaultID)
    }
}
