// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VTS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VTS", targets: ["VTS"])
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "VTS",
            dependencies: [
                "KeychainAccess",
                "KeyboardShortcuts"
            ],
            path: "Sources/VTS"
        ),
        .testTarget(
            name: "VTSTests",
            dependencies: ["VTS"],
            path: "Tests"
        )
    ]
)