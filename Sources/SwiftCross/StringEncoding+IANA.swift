//
//  StringEncoding+IANA.swift
//  SwiftCross
//
//  Mapping an IANA charset label (`"utf-8"`, `"ISO-8859-1"`,
//  `"windows-1252"`, `"shift_jis"`, …) to a `String.Encoding` is trivial on
//  Apple platforms — CoreFoundation ships `CFStringConvertIANACharSetName-
//  ToEncoding`. swift-corelibs-foundation has no equivalent, so portable
//  code that decodes email or HTTP bodies has to carry its own table. This
//  shim uses CoreFoundation where available and a hand-maintained table
//  everywhere else, behind one initializer.
//

import Foundation

#if canImport(CoreFoundation) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS))
import CoreFoundation
#endif

extension String.Encoding {

    /// Resolve an IANA charset label to a `String.Encoding`.
    ///
    /// The label is normalized (trimmed, unquoted, lowercased, common aliases
    /// folded). Returns `nil` for unknown or explicitly non-text labels
    /// (e.g. `"binary"`). On Apple platforms CoreFoundation's full IANA table
    /// is consulted first; elsewhere a built-in table of the encodings that
    /// `String.Encoding` actually exposes is used.
    public init?(ianaCharsetName name: String) {
        guard let encoding = String.Encoding.resolveIANACharset(name) else { return nil }
        self = encoding
    }

    private static func resolveIANACharset(_ rawCharset: String) -> String.Encoding? {
        guard !rawCharset.isEmpty else { return nil }
        let label = canonicalLabel(rawCharset)

        switch label {
        case "binary", "x-binary":
            return nil
        default:
            break
        }

        #if canImport(CoreFoundation) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS))
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(label as CFString)
        if cfEncoding != kCFStringEncodingInvalidId {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }
        #endif

        return knownEncodings[label]
    }

    /// Trim/unquote/lowercase, collapse separators, strip odd suffixes seen in
    /// the wild, then fold aliases to canonical IANA names.
    private static func canonicalLabel(_ rawCharset: String) -> String {
        var label = rawCharset
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .lowercased()
        label = label.replacingOccurrences(of: "_", with: "-")
        label = label.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        label = label.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        if label.hasSuffix("$esc") { label = String(label.dropLast(4)) }
        return aliases[label] ?? label
    }

    /// Odd or ambiguous labels folded to known-good IANA names.
    private static let aliases: [String: String] = [
        // UTF variants & typos
        "utf8": "utf-8",
        "utf8mb4": "utf-8",
        "utf7": "utf-7",
        "utf-16le": "utf-16le",
        "utf-16be": "utf-16be",
        "utf-32le": "utf-32le",
        "utf-32be": "utf-32be",
        // ASCII
        "iso646-us": "us-ascii",
        "ascii": "us-ascii",
        // Latin-1 family / Windows code pages
        "latin1": "iso-8859-1",
        "latin-1": "iso-8859-1",
        "cp1252": "windows-1252",
        "win-1252": "windows-1252",
        // Shift-JIS & friends
        "shift-jis": "shift_jis",
        "sjis": "shift_jis",
        "cp932": "shift_jis",
        // ISO-2022-JP oddities
        "_iso-2022-jp": "iso-2022-jp",
        // Korean aliases
        "ks-c-5601-1987": "euc-kr",
        "ks-c-5601": "euc-kr",
        "ks-c-5601-1992": "euc-kr",
        // Misc
        "macroman": "macintosh",
        "gbk/gb2312": "gbk",
    ]

    /// Hand-maintained label → `String.Encoding` map for the encodings that
    /// `String.Encoding` exposes. Used when CoreFoundation isn't available.
    /// Encodings without a native `String.Encoding` case fall back to `.utf8`.
    private static let knownEncodings: [String: String.Encoding] = [
        "utf-8": .utf8,
        "utf-16": .utf16,
        "utf-16le": .utf16LittleEndian,
        "utf-16be": .utf16BigEndian,
        "utf-32": .utf32,
        "utf-32le": .utf32LittleEndian,
        "utf-32be": .utf32BigEndian,
        "us-ascii": .ascii,
        "iso-8859-1": .isoLatin1,
        "iso-8859-2": .isoLatin2,
        "windows-1250": .windowsCP1250,
        "windows-1251": .windowsCP1251,
        "windows-1252": .windowsCP1252,
        "windows-1253": .windowsCP1253,
        "windows-1254": .windowsCP1254,
        "shift_jis": .shiftJIS,
        "euc-jp": .japaneseEUC,
        "iso-2022-jp": .iso2022JP,
        // Encodings String.Encoding can't represent natively — fall back to
        // UTF-8 so decoding still has a reasonable chance rather than nil.
        "euc-kr": .utf8,
        "gb2312": .utf8,
        "gbk": .utf8,
        "gb18030": .utf8,
        "big5": .utf8,
        "koi8-r": .utf8,
        "macintosh": .utf8,
    ]
}
