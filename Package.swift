// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Quaynor",
    platforms: [
        .iOS(.v13),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Quaynor",
            targets: ["Quaynor"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "CQuaynorFFI",
            url: "https://github.com/iBz-04/quaynor/releases/download/quaynor-swift-0.1.2/QuaynorFFI.xcframework.zip",
            checksum: "0b70cc398cefac513e42ec96a3cb1083ad5112a4ddf1d078779f875e56c5d6d4"
        ),
        .target(
            name: "QuaynorFFI",
            dependencies: ["CQuaynorFFI"],
            path: "quaynor/swift/Sources/QuaynorFFI"
        ),
        .target(
            name: "Quaynor",
            dependencies: ["QuaynorFFI"],
            path: "quaynor/swift/Sources/Quaynor"
        ),
    ]
)
