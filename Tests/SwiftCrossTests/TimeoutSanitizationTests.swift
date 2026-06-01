// `swiftCrossSafeTimeout` guards the URLSession.bytes shim, which only exists
// where Foundation's networking lives in FoundationNetworking (Linux /
// Windows / Android). On Apple the native URLSession.bytes is used and this
// whole suite compiles out.
//
// swift-corelibs-foundation computes `Int(timeout) * 1000` for libcurl in
// `_HTTPURLProtocol.configureEasyHandle`, so a `.infinity` timeout traps with
// SIGILL (and a huge finite value overflows). These tests pin the clamp.
#if canImport(FoundationNetworking)

import XCTest
import Foundation
import FoundationNetworking
@testable import SwiftCross

final class TimeoutSanitizationTests: XCTestCase {

    private let ceiling: TimeInterval = 60 * 60 * 24 * 7  // 1 week

    func testInfiniteTimeoutIsClamped() {
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(.infinity), ceiling)
    }

    func testNaNTimeoutIsClamped() {
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(.nan), ceiling)
    }

    func testFiniteTimeoutsArePreserved() {
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(60), 60)
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(ceiling), ceiling)
        // The default `timeoutIntervalForResource` (7 days) must survive.
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(604_800), 604_800)
    }

    func testOversizedFiniteTimeoutIsClamped() {
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(.greatestFiniteMagnitude), ceiling)
        XCTAssertEqual(URLSession.swiftCrossSafeTimeout(ceiling + 1), ceiling)
    }
}

#endif
