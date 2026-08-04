import Foundation
import SaneBooksCore
@preconcurrency import ZcashLightClientKit

extension ZcashSDKEngine {
    nonisolated static func endpoint(from url: URL) throws -> LightWalletEndpoint {
        guard url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty
        else {
            throw SaneBooksError.sync("Invalid lightwalletd URL: \(url.absoluteString)")
        }
        let port = url.port ?? 443
        guard (1 ... 65535).contains(port) else {
            throw SaneBooksError.sync("Invalid lightwalletd port")
        }
        return LightWalletEndpoint(address: host, port: port, secure: true)
    }
}
