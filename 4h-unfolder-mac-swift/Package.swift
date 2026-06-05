// swift-tools-version: 5.9
// Open in Xcode: File → Open → select this Package.swift
// Requirements: Xcode 15+ on macOS 13+
// Note: `swift test` is not supported for executable targets — use Xcode Test Navigator instead
import PackageDescription

let package = Package(
    name: "FourHUnfolder",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FourHUnfolder",
            path: "Sources/FourHUnfolder"
        )
    ]
)
