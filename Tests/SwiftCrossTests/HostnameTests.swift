import XCTest
import SwiftCross

final class HostnameTests: XCTestCase {

    func testLocalHostnameIsNonEmpty() throws {
        // Whatever the platform, we always resolve *something* — a real
        // hostname, a bracketed IP, or the "localhost" sentinel.
        XCTAssertFalse(String.localHostname.isEmpty)
    }

    func testLocalIPAddressIsNonEmptyWhenPresent() throws {
        // May legitimately be nil (CI runners, Windows, Android), but if a
        // value comes back it must be a non-empty string.
        if let ip = String.localIPAddress {
            XCTAssertFalse(ip.isEmpty)
        }
    }
}
