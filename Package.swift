// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Peekey",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Peekey", targets: ["Peekey"]),
    ],
    targets: [
        .target(name: "PeekeyCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "Peekey",
            dependencies: ["PeekeyCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PeekeyCoreTests",
            dependencies: ["PeekeyCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
