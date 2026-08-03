// swift-tools-version: 6.1
import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
let localSaneUIPath = packageDirectory
    .appendingPathComponent("../../../infra/SaneUI")
    .standardizedFileURL.path

let useLocal =
    ProcessInfo.processInfo.environment["SANEBOOKS_USE_LOCAL_SANEUI"] == "1"
        || FileManager.default.fileExists(atPath: localSaneUIPath)

let saneUIDependency: Package.Dependency = {
    if useLocal, FileManager.default.fileExists(atPath: localSaneUIPath) {
        return .package(path: localSaneUIPath)
    }
    return .package(
        url: "https://github.com/sane-apps/SaneUI.git",
        revision: "7f87b04bd74c6903a34e715ff46adf583d854f87"
    )
}()

let package = Package(
    name: "SaneBooksFeature",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SaneBooksCore", targets: ["SaneBooksCore"]),
        .library(name: "SaneBooksSync", targets: ["SaneBooksSync"]),
        .library(name: "SaneBooksExport", targets: ["SaneBooksExport"]),
        .library(name: "SaneBooksFeature", targets: ["SaneBooksFeature"])
    ],
    dependencies: [saneUIDependency],
    targets: [
        .target(name: "SaneBooksCore", dependencies: [], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "SaneBooksSync", dependencies: ["SaneBooksCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "SaneBooksExport", dependencies: ["SaneBooksCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "SaneBooksFeature",
            dependencies: ["SaneBooksCore", "SaneBooksSync", "SaneBooksExport", "SaneUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "SaneBooksCoreTests", dependencies: ["SaneBooksCore"]),
        .testTarget(name: "SaneBooksSyncTests", dependencies: ["SaneBooksSync"]),
        .testTarget(name: "SaneBooksExportTests", dependencies: ["SaneBooksExport", "SaneBooksCore"])
    ]
)
