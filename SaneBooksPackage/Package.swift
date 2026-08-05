// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SaneBooksFeature",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SaneBooksCore", targets: ["SaneBooksCore"]),
        .library(name: "SaneBooksSync", targets: ["SaneBooksSync"]),
        .library(name: "SaneBooksExport", targets: ["SaneBooksExport"]),
        .library(name: "SaneBooksFeature", targets: ["SaneBooksFeature"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/sane-apps/SaneUI.git",
            revision: "0894c053345a86b549ea1ee329a4ff3b20826061"
        ),
        // Ironwood receive/sync: zcash-swift-wallet-sdk#1806 closed; pin non-prerelease 2.7.0-rc.4.
        .package(
            url: "https://github.com/zcash/zcash-swift-wallet-sdk.git",
            revision: "fb9f6cf46fa725efa6cb9e646e13a94f05a293bf"
        ),
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.8.0"
        )
    ],
    targets: [
        .target(name: "SaneBooksCore", dependencies: [], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "SaneBooksSync",
            dependencies: [
                "SaneBooksCore",
                .product(name: "ZcashLightClientKit", package: "zcash-swift-wallet-sdk")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(name: "SaneBooksExport", dependencies: ["SaneBooksCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "SaneBooksFeature",
            dependencies: [
                "SaneBooksCore",
                "SaneBooksSync",
                "SaneBooksExport",
                "SaneUI",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "SaneBooksCoreTests", dependencies: ["SaneBooksCore"]),
        .testTarget(name: "SaneBooksSyncTests", dependencies: ["SaneBooksSync"]),
        .testTarget(name: "SaneBooksExportTests", dependencies: ["SaneBooksExport", "SaneBooksCore"]),
        .testTarget(
            name: "SaneBooksFeatureTests",
            dependencies: ["SaneBooksFeature", "SaneBooksCore", "SaneBooksExport"]
        )
    ]
)
