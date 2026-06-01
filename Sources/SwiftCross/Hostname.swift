//
//  Hostname.swift
//  SwiftCross
//
//  `Host.current().name` is macOS-only. On other platforms the local
//  hostname has to come from a libc/Win32 call, and each platform spells it
//  differently. These helpers paper over that so portable code (SMTP/IMAP
//  EHLO/HELO, logging, diagnostics) can ask for the hostname once.
//

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Android)
import Android
#elseif canImport(WinSDK)
import WinSDK
#endif

extension String {

    /// The local machine's hostname, resolved consistently across platforms.
    ///
    /// Uses `Host.current().name` on macOS, `GetComputerNameExW` on Windows
    /// (which, unlike Winsock's `gethostname`, needs no `WSAStartup`), and
    /// POSIX `gethostname` elsewhere. Falls back to the primary IP address in
    /// brackets, then to `"localhost"`, if the hostname can't be determined.
    public static var localHostname: String {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        if let name = Host.current().name { return name }
        #elseif os(Windows)
        var size: DWORD = 256
        var buffer = [WCHAR](repeating: 0, count: Int(size))
        if GetComputerNameExW(ComputerNameDnsFullyQualified, &buffer, &size) {
            let name = String(decodingCString: buffer, as: UTF16.self)
            if !name.isEmpty { return name }
        }
        #else
        // POSIX HOST_NAME_MAX is 64; 256 is generous headroom.
        var hostname = [CChar](repeating: 0, count: 256)
        if gethostname(&hostname, hostname.count) == 0,
           let name = String(cString: hostname, encoding: .utf8), !name.isEmpty {
            return name
        }
        #endif

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
