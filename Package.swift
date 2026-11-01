// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tunaa",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Tunaa",
            path: "Sources/Tunaa",
            exclude: ["Icons"]
        )
    ]
)
