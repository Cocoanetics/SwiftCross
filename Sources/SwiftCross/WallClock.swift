//
//  WallClock.swift
//  SwiftCross
//
//  Foundation's `Date` is a wall clock, but its `Double` seconds-since-1970
//  carry only ~100 ns of granularity near the current epoch, so it cannot
//  represent true nanoseconds. POSIX exposes `clock_gettime(CLOCK_REALTIME)`
//  at nanosecond resolution; Windows has no `clock_gettime`, so it uses
//  `GetSystemTimePreciseAsFileTime` (sub-microsecond, 100 ns FILETIME ticks).
//
//  SwiftCross wraps both so callers that need a high-resolution wall-clock
//  timestamp (e.g. trace/span recording) get one portable surface.
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

public enum WallClock {
    /// The current wall-clock time since the Unix epoch (1970-01-01 UTC),
    /// split into whole `seconds` and the `nanoseconds` within that second
    /// (`0 ..< 1_000_000_000`), at the platform's best resolution.
    ///
    /// POSIX uses `clock_gettime(CLOCK_REALTIME)` (true nanoseconds); Windows
    /// uses `GetSystemTimePreciseAsFileTime` (100 ns ticks).
    public static func now() -> (seconds: Int, nanoseconds: Int) {
        #if os(Windows)
        var fileTime = FILETIME()
        GetSystemTimePreciseAsFileTime(&fileTime)
        // FILETIME counts 100-nanosecond intervals since 1601-01-01 UTC.
        let ticks = (UInt64(fileTime.dwHighDateTime) << 32) | UInt64(fileTime.dwLowDateTime)
        // 11_644_473_600 seconds between 1601-01-01 and 1970-01-01, in 100 ns ticks.
        let unixTicks = ticks &- 116_444_736_000_000_000
        return (Int(unixTicks / 10_000_000), Int((unixTicks % 10_000_000) &* 100))
        #else
        var time = timespec()
        clock_gettime(CLOCK_REALTIME, &time)
        return (Int(time.tv_sec), Int(time.tv_nsec))
        #endif
    }
}
