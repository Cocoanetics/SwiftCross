//
//  UTType.swift
//  SwiftCross
//
//  `UTType` ships in Apple's UniformTypeIdentifiers framework, which only
//  exists on Apple platforms. On Linux / Windows / Android we provide a
//  minimal, source-compatible `UTType` value type backed by a built-in
//  filename-extension ↔ MIME-type table, so code that maps between file
//  extensions and MIME types compiles and runs the same everywhere.
//
//  Scope: the shim models only the extension/MIME surface that portable
//  code actually needs — `init?(filenameExtension:)`, `init?(mimeType:)`,
//  `preferredMIMEType`, and `preferredFilenameExtension`. It does NOT model
//  the full UTI hierarchy (type conformances, supertypes, dynamic
//  identifiers, declared system types). On Apple platforms the real
//  `UTType` is re-exported unchanged, so those richer APIs remain available
//  there.
//

#if canImport(UniformTypeIdentifiers)

@_exported import UniformTypeIdentifiers

#else

import Foundation

/// A minimal, cross-platform stand-in for `UniformTypeIdentifiers.UTType`.
///
/// On Apple platforms `import SwiftCross` re-exports the real `UTType`; this
/// definition is only compiled where UniformTypeIdentifiers is unavailable.
public struct UTType: Hashable, Sendable {

    /// The preferred MIME type, e.g. `"image/png"`.
    public let preferredMIMEType: String?

    /// The preferred filename extension (without a leading dot), e.g. `"png"`.
    public let preferredFilenameExtension: String?

    /// Create a type from a filename extension (`"png"` or `".png"`).
    /// Returns `nil` when the extension isn't in the built-in table.
    public init?(filenameExtension: String) {
        let ext = Self.normalizedExtension(filenameExtension)
        guard !ext.isEmpty, let mime = Self.extensionToMIMEType[ext] else {
            return nil
        }
        self.preferredMIMEType = mime
        self.preferredFilenameExtension = ext
    }

    /// Create a type from a MIME type (`"image/png"`, optionally with
    /// parameters like `"text/html; charset=utf-8"`). Returns `nil` when the
    /// MIME type isn't in the built-in table.
    public init?(mimeType: String) {
        let mime = Self.normalizedMIMEType(mimeType)
        guard !mime.isEmpty, let ext = Self.mimeTypeToExtension[mime] else {
            return nil
        }
        self.preferredMIMEType = mime
        self.preferredFilenameExtension = ext
    }

    private static func normalizedExtension(_ value: String) -> String {
        var ext = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while ext.hasPrefix(".") { ext.removeFirst() }
        return ext
    }

    private static func normalizedMIMEType(_ value: String) -> String {
        value
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static let extensionToMIMEType: [String: String] = [
        "aac": "audio/aac",
        "avi": "video/x-msvideo",
        "bmp": "image/bmp",
        "css": "text/css",
        "csv": "text/csv",
        "doc": "application/msword",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "gif": "image/gif",
        "gz": "application/gzip",
        "heic": "image/heic",
        "htm": "text/html",
        "html": "text/html",
        "ico": "image/vnd.microsoft.icon",
        "jpeg": "image/jpeg",
        "jpg": "image/jpeg",
        "js": "text/javascript",
        "json": "application/json",
        "jsonl": "application/jsonl",
        "md": "text/markdown",
        "mov": "video/quicktime",
        "mp3": "audio/mpeg",
        "mp4": "video/mp4",
        "mpeg": "video/mpeg",
        "oga": "audio/ogg",
        "ogg": "audio/ogg",
        "ogv": "video/ogg",
        "pdf": "application/pdf",
        "png": "image/png",
        "ppt": "application/vnd.ms-powerpoint",
        "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "rtf": "application/rtf",
        "svg": "image/svg+xml",
        "tar": "application/x-tar",
        "text": "text/plain",
        "tif": "image/tiff",
        "tiff": "image/tiff",
        "tsv": "text/tab-separated-values",
        "txt": "text/plain",
        "wav": "audio/wav",
        "webp": "image/webp",
        "xls": "application/vnd.ms-excel",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "xml": "application/xml",
        "zip": "application/zip",
    ]

    private static let mimeTypeToExtension: [String: String] = [
        "application/gzip": "gz",
        "application/json": "json",
        "application/jsonl": "jsonl",
        "application/msword": "doc",
        "application/pdf": "pdf",
        "application/rtf": "rtf",
        "application/vnd.ms-excel": "xls",
        "application/vnd.ms-powerpoint": "ppt",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
        "application/x-tar": "tar",
        "application/xml": "xml",
        "application/zip": "zip",
        "audio/aac": "aac",
        "audio/mpeg": "mp3",
        "audio/ogg": "ogg",
        "audio/wav": "wav",
        "image/bmp": "bmp",
        "image/gif": "gif",
        "image/heic": "heic",
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/svg+xml": "svg",
        "image/tiff": "tiff",
        "image/vnd.microsoft.icon": "ico",
        "image/webp": "webp",
        "text/css": "css",
        "text/csv": "csv",
        "text/html": "html",
        "text/javascript": "js",
        "text/markdown": "md",
        "text/plain": "txt",
        "text/tab-separated-values": "tsv",
        "video/mp4": "mp4",
        "video/mpeg": "mpeg",
        "video/ogg": "ogv",
        "video/quicktime": "mov",
        "video/x-msvideo": "avi",
    ]
}

#endif
