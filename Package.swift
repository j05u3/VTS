// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VTS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VTSApp", targets: ["VTSApp"]),
        .library(name: "VTS", targets: ["VTS"])
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "VTSApp",
            dependencies: [
                "VTS",
                "KeychainAccess",
                "KeyboardShortcuts"
            ],
            path: "Sources/VTSApp",
            resources: [
                .process("Info.plist")
            ]
        ),
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