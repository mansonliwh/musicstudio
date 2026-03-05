// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIMusicStudio",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AIMusicStudio",
            targets: ["AIMusicStudio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "AIMusicStudio",
            dependencies: ["KeychainAccess"]),
        .testTarget(
            name: "AIMusicStudioTests",
            dependencies: ["AIMusicStudio"]),
    ]
)
