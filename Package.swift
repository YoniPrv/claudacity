// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Claudacity",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Claudacity", path: "Sources/Claudacity")
    ]
)
