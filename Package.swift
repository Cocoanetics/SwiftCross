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
        // Floor is set by the native `URLSession.bytes` / `AsyncBytes` APIs.
        // SwiftCross only ships its own `bytes` shim under
        // `canImport(FoundationNetworking)` (Linux/Windows/Android); on Apple
        // it defers to the native API, which lands in macOS 12 / iOS 15 /
        // tvOS 15 / watchOS 8. Advertising anything lower would let a consumer
        // resolve the package and then hit availability errors on the
        // README's `URLSession.shared.bytes(...)` usage. (UniformTypeIdentifiers,
        // needed for the UTType re-export, is iOS 14 / macOS 11 — covered.)
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
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
