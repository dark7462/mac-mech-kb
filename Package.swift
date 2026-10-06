// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MechanicalKeyboard",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MechanicalKeyboard", targets: ["MechanicalKeyboard"])],
    targets: [
        .executableTarget(
            name: "MechanicalKeyboard",
            path: "Sources/MechanicalKeyboard",
            exclude: ["Resources/Info.plist"],
            resources: [.copy("Resources/Sounds")]
        )
    ]
)
