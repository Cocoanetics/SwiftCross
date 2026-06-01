import XCTest
import SwiftCross

final class ProcessInfoTests: XCTestCase {

    func testLocalIPAddressIsNilOrNonEmpty() throws {
        // May legitimately be nil (CI runners, Windows, Android), but if a
        // value comes back it must be a non-empty string.
        if let ip = ProcessInfo.processInfo.localIPAddress {
            XCTAssertFalse(ip.isEmpty)
        }
    }
}
