// swift-tools-version: 5.9
// Open in Xcode: File → Open → select this Package.swift
// Requirements: Xcode 15+ on macOS 13+
import PackageDescription

let package = Package(
    name: "FourHUnfolder",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure-Swift library: Core algorithms, IO, Services — no UI deps.
        // Compiled with -enable-testing so that both the app target (via
        // @testable import) and the test target can access internal symbols
        // without requiring public access modifiers throughout.
        .target(
            name: "FourHUnfolderCore",
            path: "Sources/FourHUnfolderCore",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"])
            ]
        ),

        // SwiftUI + AppKit application entry point
        .executableTarget(
            name: "FourHUnfolder",
            dependencies: ["FourHUnfolderCore"],
            path: "Sources/FourHUnfolder"
        ),

        // Unit tests for Core algorithms, IO loaders, and Services
        .testTarget(
            name: "FourHUnfolderTests",
            dependencies: ["FourHUnfolderCore"],
            path: "Tests/FourHUnfolderTests"
        )
    ]
)
