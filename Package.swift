// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-ownership-primitives",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [

        .library(
            name: "Ownership Primitive",
            targets: ["Ownership Primitive"]
        ),

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
            name: "Ownership Immutable Primitives",
            targets: ["Ownership Immutable Primitives"]
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
            name: "Ownership Latch Primitives",
            targets: ["Ownership Latch Primitives"]
        ),
        .library(
            name: "Ownership Box Primitives",
            targets: ["Ownership Box Primitives"]
        ),
        .library(
            name: "Ownership Transfer Primitives",
            targets: ["Ownership Transfer Primitives"]
        ),
        .library(
            name: "Ownership Transfer Erased Primitives",
            targets: ["Ownership Transfer Erased Primitives"]
        ),

        .library(
            name: "Ownership Primitives Standard Library Integration",
            targets: ["Ownership Primitives Standard Library Integration"]
        ),

        .library(
            name: "Ownership Primitives",
            targets: ["Ownership Primitives"]
        ),

        .library(
            name: "Ownership Primitives Test Support",
            targets: ["Ownership Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-primitives/swift-tagged-primitives.git",
            branch: "main"
        )
    ],
    targets: [

        .target(
            name: "Ownership Primitive",
            dependencies: []
        ),

        .target(
            name: "Ownership Borrow Primitives",
            dependencies: [
                "Ownership Primitive",
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
            ]
        ),
        .target(
            name: "Ownership Inout Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Unique Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Immutable Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Mutable Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Slot Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Latch Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Box Primitives",
            dependencies: [
                "Ownership Primitive"
            ]
        ),
        .target(
            name: "Ownership Transfer Primitives",
            dependencies: [
                "Ownership Primitive",
                "Ownership Latch Primitives",
            ]
        ),
        .target(
            name: "Ownership Transfer Erased Primitives",
            dependencies: [
                "Ownership Transfer Primitives",
                "Ownership Latch Primitives",
            ]
        ),

        .target(
            name: "Ownership Primitives Standard Library Integration",
            dependencies: [
                "Ownership Primitive"
            ]
        ),

        .target(
            name: "Ownership Primitives",
            dependencies: [
                "Ownership Primitive",
                "Ownership Borrow Primitives",
                "Ownership Inout Primitives",
                "Ownership Unique Primitives",
                "Ownership Immutable Primitives",
                "Ownership Mutable Primitives",
                "Ownership Slot Primitives",
                "Ownership Latch Primitives",
                "Ownership Box Primitives",
                "Ownership Transfer Primitives",
                "Ownership Transfer Erased Primitives",
                "Ownership Primitives Standard Library Integration",
            ]
        ),

        .target(
            name: "Ownership Primitives Test Support",
            dependencies: [
                "Ownership Primitives",
                .product(
                    name: "Tagged Primitives Test Support",
                    package: "swift-tagged-primitives"
                ),
            ],
            path: "Tests/Support"
        ),

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
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
