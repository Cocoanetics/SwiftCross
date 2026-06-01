//
//  ProcessInfo+LocalIPAddress.swift
//  SwiftCross
//
//  For the local hostname, no shim is needed: Foundation already exposes
//  `ProcessInfo.processInfo.hostName` on every platform (it's implemented on
//  swift-corelibs-foundation too), so use that directly.
//
//  What Foundation has no portable API for is the machine's *own* IP address.
//  SwiftCross adds it as a companion to the built-in `hostName`, implemented
//  per platform:
//
//    • Apple / Linux / Android use `getifaddrs` to find the address bound to
//      a physical interface.
//    • Windows has no `getifaddrs`, so it opens a `SOCK_DGRAM` socket and
//      "connects" it to a routable address — no datagram is sent; this only
//      drives the OS's source-address selection — then reads back the local
//      endpoint with `getsockname`.
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

extension ProcessInfo {

    /// The machine's primary non-loopback IPv4/IPv6 address, or `nil` if it
    /// can't be determined (e.g. no active network interface).
    public var localIPAddress: String? {
        #if os(Windows)
        return swiftCrossLocalIPAddressWindows()
        #elseif canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)
        return swiftCrossLocalIPAddressPOSIX()
        #else
        return nil
        #endif
    }
}

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android)
/// Enumerate interfaces with `getifaddrs` and return the address on a physical
/// interface (`en*` / `eth*` / `wl*`). A routable IPv4 address is preferred; a
/// non-link-local IPv6 is used as a fallback. Link-local addresses
/// (IPv4 `169.254/16`, IPv6 `fe80::/10`) are skipped — they aren't useful as
/// "the machine's IP".
private func swiftCrossLocalIPAddressPOSIX() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    var ipv6Fallback: String?
    var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let entry = cursor {
        let interface = entry.pointee
        cursor = interface.ifa_next

        guard let address = interface.ifa_addr else { continue }
        let family = address.pointee.sa_family
        let isIPv4 = family == UInt8(AF_INET)
        let isIPv6 = family == UInt8(AF_INET6)
        guard isIPv4 || isIPv6 else { continue }

        // `ifa_name` is a strict optional on the Android overlay (an
        // implicitly-unwrapped optional on Darwin/glibc), so bind it explicitly.
        guard let namePointer = interface.ifa_name else { continue }
        let name = String(cString: namePointer)
        guard name.hasPrefix("en") || name.hasPrefix("eth") || name.hasPrefix("wl") else { continue }

        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        #if canImport(Darwin)
        let saLen = socklen_t(address.pointee.sa_len)
        #else
        let saLen = isIPv4
            ? socklen_t(MemoryLayout<sockaddr_in>.size)
            : socklen_t(MemoryLayout<sockaddr_in6>.size)
        #endif

        // The host-buffer length is `socklen_t` on Darwin/glibc but `Int`
        // (size_t) on the Android overlay; `numericCast` adapts to either.
        guard getnameinfo(address, saLen, &host, numericCast(host.count), nil, 0, NI_NUMERICHOST) == 0,
              let resolved = String(cString: host, encoding: .utf8), !resolved.isEmpty else { continue }

        if isIPv4 {
            // A routable IPv4 wins outright; skip the 169.254/16 link-local block.
            if !resolved.hasPrefix("169.254.") { return resolved }
        } else if ipv6Fallback == nil, !resolved.hasPrefix("fe80") {
            // Remember the first global IPv6 in case there's no usable IPv4.
            ipv6Fallback = resolved
        }
    }
    return ipv6Fallback
}

#endif

#if os(Windows)

/// Windows has no `getifaddrs`. Open a UDP socket and "connect" it to a
/// routable address (no datagram is sent — `connect` on a datagram socket
/// only performs route/source-address selection), then read back the local
/// endpoint the OS bound it to.
private func swiftCrossLocalIPAddressWindows() -> String? {
    var wsaData = WSADATA()
    guard WSAStartup(0x0202, &wsaData) == 0 else { return nil }
    defer { WSACleanup() }

    let handle = socket(AF_INET, SOCK_DGRAM, 0)
    guard handle != INVALID_SOCKET else { return nil }
    defer { closesocket(handle) }

    var destination = sockaddr_in()
    destination.sin_family = ADDRESS_FAMILY(AF_INET)
    destination.sin_port = 0
    // 192.0.2.1 — RFC 5737 documentation address. Nothing is sent here.
    _ = "192.0.2.1".withCString { inet_pton(AF_INET, $0, &destination.sin_addr) }

    let connectStatus = withUnsafePointer(to: &destination) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(handle, $0, Int32(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connectStatus == 0 else { return nil }

    var local = sockaddr_in()
    var length = Int32(MemoryLayout<sockaddr_in>.size)
    let nameStatus = withUnsafeMutablePointer(to: &local) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(handle, $0, &length)
        }
    }
    guard nameStatus == 0 else { return nil }

    var text = [CChar](repeating: 0, count: 46) // INET6_ADDRSTRLEN
    let converted = withUnsafePointer(to: &local.sin_addr) {
        inet_ntop(AF_INET, $0, &text, 46)
    }
    guard converted != nil else { return nil }
    let result = String(cString: text)
    return result.isEmpty ? nil : result
}

#endif
