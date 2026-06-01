import XCTest
import SwiftCross

final class UTTypeTests: XCTestCase {

    // Forward mapping (filename extension → MIME). These values hold for both
    // the native UniformTypeIdentifiers `UTType` (Apple) and the SwiftCross
    // shim (Linux / Windows / Android), so the assertions run everywhere.
    func testExtensionToMIMEParity() throws {
        XCTAssertEqual(UTType(filenameExtension: "json")?.preferredMIMEType, "application/json")
        XCTAssertEqual(UTType(filenameExtension: "png")?.preferredMIMEType, "image/png")
        XCTAssertEqual(UTType(filenameExtension: "pdf")?.preferredMIMEType, "application/pdf")
        XCTAssertEqual(UTType(filenameExtension: "html")?.preferredMIMEType, "text/html")
        XCTAssertEqual(UTType(filenameExtension: "txt")?.preferredMIMEType, "text/plain")
        XCTAssertEqual(UTType(filenameExtension: "gif")?.preferredMIMEType, "image/gif")
        XCTAssertEqual(UTType(filenameExtension: "zip")?.preferredMIMEType, "application/zip")
    }

    // The shim's own surface: reverse mapping (MIME → extension), parameter
    // stripping, leading-dot / case normalization. The native `UTType` may
    // canonicalize differently, so these are checked against the shim only.
    #if !canImport(UniformTypeIdentifiers)
    func testMIMEToExtensionShim() throws {
        XCTAssertEqual(UTType(mimeType: "image/png")?.preferredFilenameExtension, "png")
        XCTAssertEqual(UTType(mimeType: "application/json")?.preferredFilenameExtension, "json")
        XCTAssertEqual(UTType(mimeType: "text/plain")?.preferredFilenameExtension, "txt")
    }

    func testMIMEParametersAreStripped() throws {
        XCTAssertEqual(UTType(mimeType: "text/html; charset=utf-8")?.preferredMIMEType, "text/html")
    }

    func testLeadingDotAndCaseAreNormalized() throws {
        XCTAssertEqual(UTType(filenameExtension: ".PNG")?.preferredMIMEType, "image/png")
    }

    func testUnknownTypesReturnNil() throws {
        XCTAssertNil(UTType(filenameExtension: "definitely-not-a-real-extension"))
        XCTAssertNil(UTType(mimeType: "application/x-not-real"))
        XCTAssertNil(UTType(filenameExtension: ""))
    }
    #endif
}
