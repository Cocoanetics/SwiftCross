import XCTest
import SwiftCross

final class StringEncodingTests: XCTestCase {

    // These resolve identically through Apple's CoreFoundation IANA table
    // and the built-in fallback table, so they hold on every platform.
    func testCommonCharsets() throws {
        XCTAssertEqual(String.Encoding(ianaCharsetName: "utf-8"), .utf8)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "us-ascii"), .ascii)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "iso-8859-1"), .isoLatin1)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "windows-1252"), .windowsCP1252)
    }

    // The built-in fallback table (used off-Apple) maps these legacy Japanese
    // labels to the classic String.Encoding cases. Apple's CoreFoundation
    // prefers the Windows/DOS variants for some of them (e.g. "shift_jis" →
    // CP932, which String.Encoding can't represent), so this is checked only
    // where the fallback table is in effect.
    #if !canImport(Darwin)
    func testFallbackTableCharsets() throws {
        XCTAssertEqual(String.Encoding(ianaCharsetName: "shift_jis"), .shiftJIS)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "euc-jp"), .japaneseEUC)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "iso-2022-jp"), .iso2022JP)
    }
    #endif

    func testCaseAndWhitespaceAreNormalized() throws {
        XCTAssertEqual(String.Encoding(ianaCharsetName: "UTF-8"), .utf8)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "  utf-8  "), .utf8)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "\"utf-8\""), .utf8)
    }

    func testAliasesAreFolded() throws {
        XCTAssertEqual(String.Encoding(ianaCharsetName: "utf8"), .utf8)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "ascii"), .ascii)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "latin1"), .isoLatin1)
        XCTAssertEqual(String.Encoding(ianaCharsetName: "cp1252"), .windowsCP1252)
    }

    func testNonTextAndUnknownReturnNil() throws {
        XCTAssertNil(String.Encoding(ianaCharsetName: "binary"))
        XCTAssertNil(String.Encoding(ianaCharsetName: ""))
        XCTAssertNil(String.Encoding(ianaCharsetName: "totally-bogus-charset-xyz"))
    }
}
