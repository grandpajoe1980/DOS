// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DOS",
    platforms: [.iOS(.v17)],
    products: [.library(name: "DOSCore", targets: ["DOSCore"])],
    targets: [
        .target(
            name: "DOSCore",
            path: "DOS",
            exclude: ["DOSApp.swift", "Views", "Resources", "Models/README.md", "Services/README.md", "Utilities/README.md"]
        ),
        .testTarget(name: "DOSCoreTests", dependencies: ["DOSCore"], path: "DOSTests", exclude: ["README.md"])
    ]
)
