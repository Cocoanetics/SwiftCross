// `swiftCrossSafeTimeout` guards the URLSession.bytes shim, which only exists
// where Foundation's networking lives in FoundationNetworking (Linux /
// Windows / Android). On Apple the native URLSession.bytes is used and this
// whole suite compiles out.
//
// swift-corelibs-foundation computes `Int(timeout) * 1000` for libcurl in
// `_HTTPURLProtocol.configureEasyHandle`, so a `.infinity` timeout traps with
// SIGILL (and an `Int`-overflowing finite value also traps). Only those are
// replaced; ordinary finite durations must pass through unchanged.
#if canImport(FoundationNetworking)

import XCTest
import Foundation
import FoundationNetworking
@testable import SwiftCross

final class TimeoutSanitizationTests: XCTestCase {

    private let maxSafe = TimeInterval(1 << 53)

    func testNonFiniteTimeoutsAreClamped() {
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(.infinity), maxSafe)
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(.nan), maxSafe)
    }

    func testOverflowProneFiniteTimeoutIsClamped() {
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(.greatestFiniteMagnitude), maxSafe)
    }

    func testRealisticFiniteTimeoutsArePreservedUnchanged() {
        // The whole point: a caller's configured duration is never shortened.
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(60), 60)
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(604_800), 604_800)        // 1 week
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(60 * 60 * 24 * 30), 60 * 60 * 24 * 30)  // 30 days
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(60 * 60 * 24 * 365), 60 * 60 * 24 * 365) // 1 year
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(maxSafe), maxSafe)
    }
}

#endif
