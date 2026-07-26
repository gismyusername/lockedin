// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LockedIn",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LockedIn",
            path: "Sources/LockedIn"
        )
    ],
    swiftLanguageModes: [.v5]
)
