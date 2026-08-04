import Foundation

/// A cooperative cancellation signal for blocking SQLite work running outside
/// the main actor. It is deliberately shared with the detached worker rather
/// than relying on unstructured-task cancellation propagation.
public final class ImportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false

    public init() {}

    public func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    public func throwIfCancelled() throws {
        lock.lock()
        let cancelled = isCancelled
        lock.unlock()
        if cancelled {
            throw CancellationError()
        }
    }
}

public extension ZashiSDKDatabaseImporter {
    /// Runs the bounded metadata read on a detached worker. The caller must
    /// retain any security-scoped URL access until this operation returns.
    static func inspectDatabaseAsync(
        at url: URL,
        limits: Limits = .standard,
        cancellation: ImportCancellation
    ) async throws -> AccountMetadata {
        try await runOffMain(cancellation: cancellation) {
            try inspectDatabase(at: url, limits: limits, cancellation: cancellation)
        }
    }

    /// Runs SQLite scanning off the main actor and checks the same cancellation
    /// signal while rows are read, so cancellation never yields a partial
    /// result to the caller.
    static func importDatabaseAsync(
        at url: URL,
        vaultID: VaultID,
        limits: Limits = .standard,
        cancellation: ImportCancellation
    ) async throws -> Result {
        try await runOffMain(cancellation: cancellation) {
            try importDatabase(
                at: url,
                vaultID: vaultID,
                limits: limits,
                cancellation: cancellation
            )
        }
    }

    private static func runOffMain<Value: Sendable>(
        cancellation: ImportCancellation,
        operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        if Task.isCancelled {
            cancellation.cancel()
        }
        return try await withTaskCancellationHandler(operation: {
            try await Task.detached(priority: .userInitiated, operation: operation).value
        }, onCancel: {
            cancellation.cancel()
        })
    }
}
