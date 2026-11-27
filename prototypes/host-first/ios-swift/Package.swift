// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HostFirstRemote",
    platforms: [.iOS(.v17)],
    products: [.library(name: "HostFirstRemote", targets: ["HostFirstRemote"])],
    targets: [.target(name: "HostFirstRemote")]
)
