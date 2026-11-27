// swift-tools-version: 6.1
import PackageDescription
let package = Package(
    name: "Phase2BTLS",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-ssl.git", exact: "2.37.8"),
        .package(url: "https://github.com/apple/swift-nio.git", exact: "2.105.2"),
    ],
    targets: [.executableTarget(name: "Experiment", dependencies: [
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "NIOEmbedded", package: "swift-nio"),
    ])]
)
