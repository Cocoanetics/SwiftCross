# SwiftCross

[![Swift](https://github.com/Cocoanetics/SwiftCross/actions/workflows/swift.yml/badge.svg)](https://github.com/Cocoanetics/SwiftCross/actions/workflows/swift.yml)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Linux%20%7C%20Windows%20%7C%20Android-lightgrey.svg)](#platform-support)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Small, dependency-free compatibility shims so the **same Swift source compiles
and runs on every platform the toolchain targets** — Apple (macOS, iOS, tvOS,
watchOS, visionOS), Linux, Windows, and Android.

## The problem

A lot of convenient Foundation API only exists on Apple's Foundation, not on
the open-source `swift-corelibs-foundation` used on Linux/Windows/Android. The
moment a cross-platform package touches one of these, it stops building
elsewhere:

```swift
// Compiles on Apple. On Linux: "value of type 'URLSession' has no member 'bytes'"
let (bytes, response) = try await URLSession.shared.bytes(for: request)
for try await line in bytes.lines { … }

// Compiles on Apple. On Linux: "cannot find type 'UTType' in scope"
let mime = UTType(filenameExtension: "png")?.preferredMIMEType
```

The usual fix is to scatter `#if canImport(FoundationNetworking)` shims through
every project that hits the gap. SwiftCross collects those shims in one place
so you write the API once and import a single module.

## Approach

`import SwiftCross` is a drop-in replacement for `import Foundation`. It
re-exports Foundation (plus `FoundationNetworking` where that's a separate
module, and `UniformTypeIdentifiers` where it exists) and layers the shims on
top. On a platform that already has the real API, SwiftCross gets out of the
way and you get the native implementation; on one that doesn't, you get the
shim — same call site either way.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Cocoanetics/SwiftCross.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyLibrary", dependencies: ["SwiftCross"]),
]
```

```swift
import SwiftCross   // instead of: import Foundation
```

## What's included

### `URLSession.bytes(for:)` / `bytes(from:)` + `AsyncBytes`

Apple's async byte-streaming API, ported to `FoundationNetworking`. This is a
*real* incremental stream — a one-shot `URLSession` data delegate forwards
chunks as they arrive and resolves the response the moment headers land, so
Server-Sent Events and other long-lived responses work, not just small bodies.

```swift
let (bytes, response) = try await URLSession.shared.bytes(for: request)
for try await line in bytes.lines {
    print(line)   // streams as the server sends it, on Linux/Windows too
}
```

### `UTType`

A minimal stand-in for `UniformTypeIdentifiers.UTType` covering the
filename-extension ↔ MIME-type mapping that portable code needs.

```swift
UTType(filenameExtension: "png")?.preferredMIMEType        // "image/png"
UTType(mimeType: "application/json")?.preferredFilenameExtension  // "json"
```

On Apple platforms the real `UTType` is re-exported unchanged, so its full UTI
hierarchy (conformances, supertypes, system-declared types) stays available
there; the shim intentionally models only the extension/MIME surface.

### `ProcessInfo.localIPAddress`

The machine's primary non-loopback IP address. Foundation has no portable API
for this — it needs `getifaddrs`, which differs per platform and is absent on
Windows — so SwiftCross adds it as a companion to the built-in, already-portable
`ProcessInfo.hostName` (no shim needed for the hostname itself).

```swift
let host = ProcessInfo.processInfo.hostName        // built-in, works everywhere
let ip   = ProcessInfo.processInfo.localIPAddress  // SwiftCross; nil on Windows/Android
```

### `String.Encoding(ianaCharsetName:)`

Resolve an IANA charset label (`"utf-8"`, `"ISO-8859-1"`, `"windows-1252"`,
`"shift_jis"`, …) to a `String.Encoding`, with normalization and alias folding.
Uses CoreFoundation's full IANA table on Apple platforms and a built-in table
elsewhere.

```swift
let data = …
let encoding = String.Encoding(ianaCharsetName: charsetFromHeader) ?? .utf8
let text = String(data: data, encoding: encoding)
```

## Platform support

| Platform | Status | Notes |
| --- | --- | --- |
| macOS / iOS / tvOS / watchOS / visionOS | ✅ build + test | Native APIs re-exported |
| Linux | ✅ build + test | Primary shim target (`swift-corelibs-foundation`) |
| Windows | ✅ build + test | `localIPAddress` returns `nil` (no `getifaddrs`) |
| Android | ✅ build (library) | `localIPAddress` returns `nil` |

Every platform is exercised in [CI](.github/workflows/swift.yml) on each push.

## Contributing

The bar for a shim: it should let the *same* source compile and run across
platforms, be dependency-free, and re-export/defer to the real API where it
already exists. Add the implementation under `Sources/SwiftCross/`, add a
cross-platform test (assert behaviour that holds on both the native and shimmed
paths — see `Tests/SwiftCrossTests`), and make sure all five CI legs stay
green.

## License

MIT — see [LICENSE](LICENSE).
