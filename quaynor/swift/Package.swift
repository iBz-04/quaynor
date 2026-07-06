// swift-tools-version: 6.0

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let workspaceDirectory = packageDirectory.deletingLastPathComponent()
let rustDebugLibraryDirectory = workspaceDirectory.appendingPathComponent("target/debug").path
let rustReleaseLibraryDirectory = workspaceDirectory.appendingPathComponent("target/release").path

var rustLinkerFlags = [
    "-L\(rustDebugLibraryDirectory)",
    "-Xlinker", "-rpath",
    "-Xlinker", rustDebugLibraryDirectory,
]

if FileManager.default.fileExists(atPath: rustReleaseLibraryDirectory) {
    rustLinkerFlags.append(contentsOf: [
        "-L\(rustReleaseLibraryDirectory)",
        "-Xlinker", "-rpath",
        "-Xlinker", rustReleaseLibraryDirectory,
    ])
}

let package = Package(
    name: "Quaynor",
    platforms: [
        .macOS(.v13),
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
            path: "Sources/QuaynorFFI",
            linkerSettings: [
                .linkedLibrary("quaynor_uniffi", .when(platforms: [.macOS])),
                .unsafeFlags(rustLinkerFlags, .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "Quaynor",
            dependencies: ["QuaynorFFI"],
            path: "Sources/Quaynor"
        ),
        .testTarget(
            name: "QuaynorTests",
            dependencies: ["Quaynor"],
            path: "Tests/QuaynorTests"
        ),
    ]
)
