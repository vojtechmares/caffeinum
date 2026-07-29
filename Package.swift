// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Caffeinum",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Caffeinum",
            path: "Sources/Caffeinum",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CaffeinumTests",
            dependencies: ["Caffeinum"],
            path: "Tests/CaffeinumTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
