// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacMechKB",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "mac-mech-kb", targets: ["MacMechKB"])],
    targets: [
        .executableTarget(
            name: "MacMechKB",
            path: "Sources/MacMechKB",
            exclude: ["Resources/Info.plist"],
            resources: [.copy("Resources/Sounds")]
        )
    ]
)
