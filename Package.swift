// swift-tools-version:6.2
import PackageDescription

// SwiftCross is a collection of small, dependency-free compatibility shims
// that let the *same* Swift source compile and run across every platform
// the toolchain targets — Apple (macOS / iOS / tvOS / watchOS / visionOS),
// Linux, Windows, and Android.
//
// Each shim fills a gap where an API exists on Apple's Foundation but is
// missing from swift-corelibs-foundation (or vice versa). On platforms
// that already have the real API, SwiftCross gets out of the way and
// re-exports it, so consumers write to one surface and `import SwiftCross`
// everywhere.

let package = Package(
    name: "SwiftCross",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SwiftCross", targets: ["SwiftCross"]),
    ],
    targets: [
        .target(name: "SwiftCross"),
        .testTarget(
            name: "SwiftCrossTests",
            dependencies: ["SwiftCross"]
        ),
    ]
)
