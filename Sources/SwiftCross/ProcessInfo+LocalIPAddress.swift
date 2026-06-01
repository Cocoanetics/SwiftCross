//
//  ProcessInfo+LocalIPAddress.swift
//  SwiftCross
//
//  For the local hostname, no shim is needed: Foundation already exposes
//  `ProcessInfo.processInfo.hostName` on every platform (it's implemented on
//  swift-corelibs-foundation too), so use that directly.
//
//  What Foundation has no portable API for is the machine's *own* IP address.
//  That requires `getifaddrs`, which differs across platforms and is absent on
//  Windows — so SwiftCross adds it as a companion to the built-in `hostName`.
//

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension ProcessInfo {

    /// The machine's primary non-loopback IPv4/IPv6 address over a physical
    /// interface (`en*` / `eth*` / `wl*`), or `nil` if it can't be found.
    ///
    /// Implemented with `getifaddrs`, which is unavailable on Windows and not
    /// dependably exposed by the Android libc overlay; returns `nil` there
    /// rather than failing to build.
    public var localIPAddress: String? {
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
