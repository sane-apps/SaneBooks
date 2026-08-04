import Foundation
import Security

struct KeychainOperations: @unchecked Sendable {
    var update: (CFDictionary, CFDictionary) -> OSStatus
    var add: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    var copyMatching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    var delete: (CFDictionary) -> OSStatus

    static let system = KeychainOperations(
        update: { SecItemUpdate($0, $1) },
        add: { SecItemAdd($0, $1) },
        copyMatching: { SecItemCopyMatching($0, $1) },
        delete: { SecItemDelete($0) }
    )
}

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
    private let operations: KeychainOperations

    public init() {
        operations = .system
    }

    init(operations: KeychainOperations) {
        self.operations = operations
    }

    public func save(_ key: String, for vaultID: VaultID) throws {
        let account = vaultID.uuid.uuidString
        let service = "\(Self.servicePrefix).\(account)"
        let data = Data(key.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let updateStatus = operations.update(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw SaneBooksError.keychain("SecItemUpdate \(updateStatus)")
        }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = operations.add(add as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        if addStatus == errSecDuplicateItem {
            // Another writer may have inserted the item after the first update.
            let retryStatus = operations.update(query as CFDictionary, update as CFDictionary)
            guard retryStatus == errSecSuccess else {
                throw SaneBooksError.keychain("SecItemUpdate retry \(retryStatus)")
            }
            return
        }
        throw SaneBooksError.keychain("SecItemAdd \(addStatus)")
    }

    public func load(for vaultID: VaultID) throws -> String? {
        let account = vaultID.uuid.uuidString
        let service = "\(Self.servicePrefix).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = operations.copyMatching(query as CFDictionary, &item)
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
            kSecAttrAccount as String: account,
        ]
        let status = operations.delete(query as CFDictionary)
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
