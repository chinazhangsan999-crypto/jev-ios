// swift-tools-version: 6.0
import PackageDescription

/// Linux/macOS-testable core. iOS framework integrations remain in the Xcode targets.
let package = Package(
    name: "ChatPilotCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "ChatPilotCore", targets: ["ChatPilotCore"])],
    targets: [
        .target(name: "ChatPilotCore", path: "Shared",
                exclude: ["KeychainStore.swift", "ModelClient.swift", "SharedStore.swift"],
                sources: ["Models.swift"]),
        .testTarget(name: "ChatPilotCoreTests", dependencies: ["ChatPilotCore"], path: "PortableTests")
    ]
)
