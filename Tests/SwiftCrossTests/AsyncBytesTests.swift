// The AsyncBytes shim only exists where Foundation's networking lives in
// FoundationNetworking (Linux / Windows / Android); on Apple the native
// URLSession.AsyncBytes is used and this whole suite compiles out. The tests
// drive the shim's line-splitting and byte iteration through a synthetic
// chunk stream — no network required, so they're deterministic in CI.
#if canImport(FoundationNetworking)

import XCTest
import Foundation
import FoundationNetworking
@testable import SwiftCross

final class AsyncBytesTests: XCTestCase {

    private func makeBytes(_ chunks: [Data]) -> URLSession.AsyncBytes {
        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        for chunk in chunks { continuation.yield(chunk) }
        continuation.finish()
        return URLSession.AsyncBytes(chunks: stream)
    }

    private func makeBytes(_ string: String) -> URLSession.AsyncBytes {
        makeBytes([Data(string.utf8)])
    }

    func testLinesSplitOnLF() async throws {
        var lines: [String] = []
        for try await line in makeBytes("alpha\nbeta\ngamma\n").lines {
            lines.append(line)
        }
        XCTAssertEqual(lines, ["alpha", "beta", "gamma"])
    }

    func testLinesHandleCRLFAndTrailingPartialLine() async throws {
        var lines: [String] = []
        for try await line in makeBytes("one\r\ntwo\r\nthree").lines {
            lines.append(line)
        }
        XCTAssertEqual(lines, ["one", "two", "three"])
    }

    func testBytesIterateInOrderAndSkipEmptyChunks() async throws {
        let bytes = makeBytes([
            Data([0x41, 0x42]), // "AB"
            Data(),             // empty chunk must be skipped, not end the stream
            Data([0x43]),       // "C"
        ])
        var collected: [UInt8] = []
        for try await byte in bytes { collected.append(byte) }
        XCTAssertEqual(collected, [0x41, 0x42, 0x43])
    }
}

#endif
