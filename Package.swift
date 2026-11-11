// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "TOSS",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(name: "TossSchema", targets: ["TossSchema"]),
        .library(name: "TossProtocol", targets: ["TossProtocol"]),
        .executable(name: "toss-receiver", targets: ["TossReceiver"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TossSchema",
            path: "packages/handoff-schema/Sources"
        ),
        .target(
            name: "TossProtocol",
            dependencies: ["TossSchema"],
            path: "packages/transfer-protocol/Sources"
        ),
        .executableTarget(
            name: "TossReceiver",
            dependencies: ["TossSchema", "TossProtocol"],
            path: "apps/macos-receiver/Sources"
        ),
        .testTarget(
            name: "TossTests",
            dependencies: ["TossSchema", "TossProtocol"],
            path: "tests"
        )
    ]
)
