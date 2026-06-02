//
//  Environment.swift
//  SwiftCross
//
//  Setting a process environment variable is POSIX `setenv` everywhere except
//  Windows, whose C runtime has no `setenv` — it uses `_putenv_s` (ucrt).
//  SwiftCross wraps both so callers (e.g. a `.env` loader) get one portable
//  surface that lands values in `ProcessInfo.processInfo.environment`.
//

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WinSDK)
import WinSDK
#endif

public enum Environment {
    /// Sets the environment variable `name` to `value` for the current
    /// process, overwriting any existing value, so it becomes visible through
    /// `ProcessInfo.processInfo.environment`.
    ///
    /// POSIX uses `setenv`; Windows has no `setenv` and uses `_putenv_s`.
    /// - Returns: `true` on success.
    @discardableResult
    public static func set(_ name: String, _ value: String) -> Bool {
        #if os(Windows)
        return _putenv_s(name, value) == 0
        #else
        return setenv(name, value, 1) == 0
        #endif
    }
}
