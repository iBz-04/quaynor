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
            url: "https://github.com/iBz-04/quaynor/releases/download/quaynor-swift-0.1.0/QuaynorFFI.xcframework.zip",
            checksum: "2da0e469a64f5dcfb98c80ce6f98c602f9ca26828e64d877a9c763ca709b7197"
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
