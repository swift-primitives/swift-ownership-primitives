// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-ownership-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Ownership Primitives",
            targets: ["Ownership Primitives"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Ownership Primitives",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "Ownership Primitives Tests",
            dependencies: [
                .target(name: "Ownership Primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
