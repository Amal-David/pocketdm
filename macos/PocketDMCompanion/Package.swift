// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PocketDMCompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PocketDMCompanion", targets: ["PocketDMCompanion"])
    ],
    targets: [
        .executableTarget(
            name: "PocketDMCompanion",
            path: "Sources/PocketDMCompanion"
        )
    ]
)
