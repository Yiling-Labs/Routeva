// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RoutevaCoreFoundation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SharedKit", targets: ["SharedKit"]),
        .library(name: "CoreBridge", targets: ["CoreBridge"]),
        .library(name: "DataKit", targets: ["DataKit"]),
        .library(name: "CoreConfigKit", targets: ["CoreConfigKit"]),
        .library(name: "PacketTunnelBridgeKit", targets: ["PacketTunnelBridgeKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.10.0"),
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2"),
    ],
    targets: [
        .target(
            name: "SharedKit",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/SharedKit"
        ),
        .target(
            name: "CoreBridge",
            dependencies: ["SharedKit"],
            path: "Sources/CoreBridge"
        ),
        .target(
            name: "DataKit",
            dependencies: [
                "SharedKit",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/DataKit"
        ),
        .target(
            name: "CoreConfigKit",
            dependencies: ["SharedKit", "DataKit"],
            path: "Sources/CoreConfigKit"
        ),
        .target(
            name: "PacketTunnelBridgeKit",
            path: "Sources/PacketTunnelBridgeKit"
        ),
        .testTarget(
            name: "SharedKitTests",
            dependencies: [
                "SharedKit", "CoreBridge", "DataKit", "CoreConfigKit",
                "PacketTunnelBridgeKit",
            ],
            path: "Tests/SharedKitTests"
        ),
    ]
)
