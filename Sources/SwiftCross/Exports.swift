//
//  Exports.swift
//  SwiftCross
//
//  The umbrella import. `import SwiftCross` brings in Foundation — plus
//  FoundationNetworking on the platforms (Linux / Windows / Android) where
//  swift-corelibs-foundation splits its networking types into a separate
//  module — so the same source compiles everywhere without each file
//  repeating the `#if canImport(FoundationNetworking)` import dance.
//

@_exported import Foundation

#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif
