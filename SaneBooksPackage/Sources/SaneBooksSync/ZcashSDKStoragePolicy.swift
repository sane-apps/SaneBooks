import Foundation
import SaneBooksCore

enum ZcashSDKStoragePolicy {
    private static let directoryPermissions = 0o700
    private static let filePermissions = 0o600

    static func prepareRoot(at root: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try setPermissions(directoryPermissions, at: root)

        var protectedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedRoot.setResourceValues(values)
    }

    static func hardenExistingTree(at root: URL) throws {
        try prepareRoot(at: root)

        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants]
        ) else {
            throw SaneBooksError.persistFailed("Unable to inspect private sync storage")
        }

        for case let item as URL in enumerator {
            let values = try item.resourceValues(forKeys: Set(resourceKeys))
            if values.isSymbolicLink == true {
                throw SaneBooksError.persistFailed(
                    "Private sync storage contains an unexpected symbolic link"
                )
            }
            if values.isDirectory == true {
                try setPermissions(directoryPermissions, at: item)
            } else if values.isRegularFile == true {
                try setPermissions(filePermissions, at: item)
            }
        }
    }

    private static func setPermissions(_ permissions: Int, at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions)],
            ofItemAtPath: url.path
        )
    }
}
