//
//  Hostname.swift
//  SwiftCross
//
//  Two small helpers so portable code (SMTP/IMAP EHLO/HELO, logging,
//  diagnostics) can ask for the local hostname / IP once and get a sensible
//  answer on every platform.
//
//  `Foundation.ProcessInfo.hostName` already abstracts the per-platform
//  hostname lookup (and exists on swift-corelibs-foundation too), so we lean
//  on it rather than spelling out `gethostname` / `GetComputerNameExW` and
//  the libc-module differences that come with them. The libc import below is
//  only for `getifaddrs`, used by `localIPAddress`.
//

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension String {

    /// The local machine's hostname.
    ///
    /// Backed by `ProcessInfo.processInfo.hostName`, which resolves the right
    /// way per platform. Falls back to the primary IP address in brackets,
    /// then to `"localhost"`, if no hostname is reported.
    public static var localHostname: String {
        let name = ProcessInfo.processInfo.hostName
        if !name.isEmpty { return name }
        if let ip = localIPAddress { return "[\(ip)]" }
        return "localhost"
    }

    /// The machine's primary non-loopback IPv4/IPv6 address over a physical
    /// interface (`en*` / `eth*` / `wl*`), or `nil` if it can't be found.
    ///
    /// Implemented with `getifaddrs`, which is unavailable on Windows and not
    /// dependably exposed by the Android libc overlay; this returns `nil`
    /// there rather than failing to build.
    public static var localIPAddress: String? {
        #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let entry = cursor {
            let interface = entry.pointee
            cursor = interface.ifa_next

            guard let address = interface.ifa_addr else { continue }
            let family = address.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("eth") || name.hasPrefix("wl") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            #if canImport(Darwin)
            let saLen = socklen_t(address.pointee.sa_len)
            #else
            let saLen = family == UInt8(AF_INET)
                ? socklen_t(MemoryLayout<sockaddr_in>.size)
                : socklen_t(MemoryLayout<sockaddr_in6>.size)
            #endif

            if getnameinfo(address, saLen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0,
               let resolved = String(cString: host, encoding: .utf8), !resolved.isEmpty {
                return resolved
            }
        }
        return nil
        #else
        return nil
        #endif
    }
}
