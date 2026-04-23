// swift-tools-version: 6.3.1

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
        // MARK: - Namespace
        .library(
            name: "Ownership Namespace",
            targets: ["Ownership Namespace"]
        ),

        // MARK: - Variants (primary decomposition per [MOD-015])
        .library(
            name: "Ownership Borrow Primitives",
            targets: ["Ownership Borrow Primitives"]
        ),
        .library(
            name: "Ownership Inout Primitives",
            targets: ["Ownership Inout Primitives"]
        ),
        .library(
            name: "Ownership Unique Primitives",
            targets: ["Ownership Unique Primitives"]
        ),
        .library(
            name: "Ownership Shared Primitives",
            targets: ["Ownership Shared Primitives"]
        ),
        .library(
            name: "Ownership Mutable Primitives",
            targets: ["Ownership Mutable Primitives"]
        ),
        .library(
            name: "Ownership Slot Primitives",
            targets: ["Ownership Slot Primitives"]
        ),
        .library(
            name: "Ownership Transfer Primitives",
            targets: ["Ownership Transfer Primitives"]
        ),
        .library(
            name: "Ownership Transfer Box Primitives",
            targets: ["Ownership Transfer Box Primitives"]
        ),

        // MARK: - StdLib Integration
        .library(
            name: "Ownership Primitives Standard Library Integration",
            targets: ["Ownership Primitives Standard Library Integration"]
        ),

        // MARK: - Umbrella
        .library(
            name: "Ownership Primitives",
            targets: ["Ownership Primitives"]
        ),

        // MARK: - Test Support
        .library(
            name: "Ownership Primitives Test Support",
            targets: ["Ownership Primitives Test Support"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        // MARK: - Namespace
        .target(
            name: "Ownership Namespace",
            dependencies: []
        ),

        // MARK: - Core
        .target(
            name: "Ownership Primitives Core",
            dependencies: [
                "Ownership Namespace",
            ]
        ),

        // MARK: - Variants
        .target(
            name: "Ownership Borrow Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Inout Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Unique Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Shared Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Mutable Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Slot Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Transfer Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),
        .target(
            name: "Ownership Transfer Box Primitives",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),

        // MARK: - StdLib Integration
        .target(
            name: "Ownership Primitives Standard Library Integration",
            dependencies: [
                "Ownership Primitives Core",
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Ownership Primitives",
            dependencies: [
                "Ownership Namespace",
                "Ownership Primitives Core",
                "Ownership Borrow Primitives",
                "Ownership Inout Primitives",
                "Ownership Unique Primitives",
                "Ownership Shared Primitives",
                "Ownership Mutable Primitives",
                "Ownership Slot Primitives",
                "Ownership Transfer Primitives",
                "Ownership Transfer Box Primitives",
                "Ownership Primitives Standard Library Integration",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Ownership Primitives Test Support",
            dependencies: [
                "Ownership Primitives",
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Ownership Primitives Tests",
            dependencies: [
                "Ownership Primitives",
                "Ownership Primitives Test Support",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
