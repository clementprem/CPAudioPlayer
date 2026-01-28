// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CPAudioPlayer",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16)
    ],
    products: [
        // Main library product
        .library(
            name: "CPAudioPlayer",
            targets: ["CPAudioPlayer", "CPAudioPlayerUI"]
        ),
        // Core audio player only (Objective-C)
        .library(
            name: "CPAudioPlayerCore",
            targets: ["CPAudioPlayer"]
        ),
        // SwiftUI views only
        .library(
            name: "CPAudioPlayerUI",
            targets: ["CPAudioPlayerUI"]
        )
    ],
    targets: [
        // Objective-C core audio player
        .target(
            name: "CPAudioPlayer",
            path: "Sources/CPAudioPlayer",
            sources: [
                "CPAudioPlayer.mm",
                "CPBandEqulizer.m",
                "CPReverbEngine.m"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath(".")
            ],
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation")
            ]
        ),
        // Swift wrapper and SwiftUI views
        .target(
            name: "CPAudioPlayerUI",
            dependencies: ["CPAudioPlayer"],
            path: "Sources/CPAudioPlayerUI",
            sources: [
                "AudioPlayer.swift",
                "AudioPlayerView.swift",
                "LibraryManager.swift"
            ]
        ),
        // Tests
        .testTarget(
            name: "CPAudioPlayerTests",
            dependencies: ["CPAudioPlayer", "CPAudioPlayerUI"],
            path: "Tests/CPAudioPlayerTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
