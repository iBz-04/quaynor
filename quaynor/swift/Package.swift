// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Quaynor",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Quaynor",
            targets: ["Quaynor"]
        ),
    ],
    targets: [
        .systemLibrary(
            name: "CQuaynorFFI",
            path: "Sources/CQuaynorFFI"
        ),
        .target(
            name: "QuaynorFFI",
            dependencies: ["CQuaynorFFI"],
            path: "Sources/QuaynorFFI"
        ),
        .target(
            name: "Quaynor",
            dependencies: ["QuaynorFFI"],
            path: "Sources/Quaynor"
        ),
    ]
)
