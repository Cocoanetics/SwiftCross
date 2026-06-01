//
//  URLSession+AsyncBytes.swift
//  SwiftCross
//
//  swift-corelibs-foundation (Linux / Windows / Android) keeps its
//  networking in `FoundationNetworking` and does NOT provide Apple's
//  `URLSession.bytes(for:)` / `bytes(from:)` async APIs or the
//  `URLSession.AsyncBytes` sequence. This file supplies a source-compatible
//  implementation on exactly those platforms, so `for try await byte in
//  bytes { … }` and `for try await line in bytes.lines { … }` compile and
//  behave the same everywhere. On Apple platforms the native APIs are used
//  unchanged (this whole file is compiled out there).
//
//  This is a *real* incremental stream, not a buffer-the-whole-body-then-
//  replay shim: a one-shot `URLSession` with a data delegate forwards each
//  `didReceive(data:)` chunk into an `AsyncThrowingStream` and resolves the
//  response the moment the headers arrive — so server-sent events and other
//  long-lived streaming responses progress with the network instead of
//  waiting for the body to finish.
//

#if canImport(FoundationNetworking)

import Foundation
import FoundationNetworking

extension URLSession {

    /// A cross-platform stand-in for Apple's `URLSession.AsyncBytes`: an
    /// `AsyncSequence` over the response body's bytes, with a `lines` helper.
    public struct AsyncBytes: AsyncSequence, Sendable {
        public typealias Element = UInt8

        let chunks: AsyncThrowingStream<Data, Error>

        public struct AsyncIterator: AsyncIteratorProtocol {
            var chunkIterator: AsyncThrowingStream<Data, Error>.AsyncIterator
            var current: Data = Data()
            var index: Data.Index = 0

            public mutating func next() async throws -> UInt8? {
                // Pull chunks until one has a byte left to hand out (skips
                // any empty chunks) or the stream ends.
                while index >= current.endIndex {
                    guard let chunk = try await chunkIterator.next() else { return nil }
                    current = chunk
                    index = current.startIndex
                }
                let byte = current[index]
                index = current.index(after: index)
                return byte
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(chunkIterator: chunks.makeAsyncIterator())
        }

        /// The body split into lines, mirroring Apple's
        /// `URLSession.AsyncBytes.lines`. Both `\n` and `\r\n` terminate a
        /// line, and a trailing newline does not yield an extra empty line.
        public var lines: AsyncLineSequence { AsyncLineSequence(bytes: self) }

        public struct AsyncLineSequence: AsyncSequence, Sendable {
            public typealias Element = String
            let bytes: AsyncBytes

            public struct AsyncIterator: AsyncIteratorProtocol {
                var byteIterator: AsyncBytes.AsyncIterator
                var buffer: [UInt8] = []
                var didEmitTrailing = false

                public mutating func next() async throws -> String? {
                    while let byte = try await byteIterator.next() {
                        if byte == 0x0A { // "\n"
                            if buffer.last == 0x0D { buffer.removeLast() } // "\r\n"
                            let line = String(decoding: buffer, as: UTF8.self)
                            buffer.removeAll(keepingCapacity: true)
                            return line
                        }
                        buffer.append(byte)
                    }
                    // EOF: surface a final line that wasn't newline-terminated.
                    if didEmitTrailing || buffer.isEmpty { return nil }
                    didEmitTrailing = true
                    if buffer.last == 0x0D { buffer.removeLast() }
                    return String(decoding: buffer, as: UTF8.self)
                }
            }

            public func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(byteIterator: bytes.makeAsyncIterator())
            }
        }
    }

    /// Cross-platform port of Apple's `URLSession.bytes(for:delegate:)`.
    public func bytes(for request: URLRequest) async throws -> (AsyncBytes, URLResponse) {
        try await streamingBytes(for: request)
    }

    /// Cross-platform port of Apple's `URLSession.bytes(from:delegate:)`.
    public func bytes(from url: URL) async throws -> (AsyncBytes, URLResponse) {
        try await streamingBytes(for: URLRequest(url: url))
    }

    private func streamingBytes(for request: URLRequest) async throws -> (AsyncBytes, URLResponse) {
        let (chunks, continuation) = AsyncThrowingStream<Data, Error>.makeStream()

        // swift-corelibs URLSession can't attach a delegate to an existing
        // session (and `URLSession.shared` has none), so we spin up a
        // one-shot session that inherits this session's configuration. The
        // session + task are owned by the stream's termination handler and
        // torn down when the consumer stops reading — whether by reaching
        // the end or by breaking out of the loop early.
        let response = try await withCheckedThrowingContinuation {
            (responseContinuation: CheckedContinuation<URLResponse, Error>) in
            let delegate = StreamingBytesDelegate(
                chunkContinuation: continuation,
                responseContinuation: responseContinuation
            )
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            // `URLSessionDataTask` / `URLSession` aren't `Sendable`; box them
            // so the @Sendable termination handler can own their teardown.
            let teardown = SessionTeardown(task: task, session: session)
            continuation.onTermination = { @Sendable _ in teardown.cancel() }
            task.resume()
        }

        return (AsyncBytes(chunks: chunks), response)
    }
}

/// Owns a one-shot streaming session/task so an `@Sendable` termination
/// handler can cancel it. `@unchecked Sendable` because the wrapped
/// Foundation types predate `Sendable` annotations but are safe to cancel
/// from any thread.
private struct SessionTeardown: @unchecked Sendable {
    let task: URLSessionDataTask
    let session: URLSession

    func cancel() {
        task.cancel()
        // Breaks URLSession's intentional session↔delegate retain cycle.
        session.finishTasksAndInvalidate()
    }
}

/// `URLSessionDataDelegate` that resolves the response as soon as headers
/// arrive and forwards body chunks into an `AsyncThrowingStream`.
private final class StreamingBytesDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var responseContinuation: CheckedContinuation<URLResponse, Error>?
    private let chunkContinuation: AsyncThrowingStream<Data, Error>.Continuation

    init(
        chunkContinuation: AsyncThrowingStream<Data, Error>.Continuation,
        responseContinuation: CheckedContinuation<URLResponse, Error>
    ) {
        self.chunkContinuation = chunkContinuation
        self.responseContinuation = responseContinuation
    }

    /// Pop the response continuation atomically so "headers arrived" and
    /// "task finished with an error" can't both try to resume it.
    private func takeResponseContinuation() -> CheckedContinuation<URLResponse, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let continuation = responseContinuation
        responseContinuation = nil
        return continuation
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        takeResponseContinuation()?.resume(returning: response)
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        chunkContinuation.yield(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            takeResponseContinuation()?.resume(throwing: error)
            chunkContinuation.finish(throwing: error)
        } else {
            // Completing without ever delivering headers means the task
            // ended before `didReceive(response:)` fired; surface it as an
            // error so a caller awaiting the response doesn't hang.
            takeResponseContinuation()?.resume(throwing: URLError(.badServerResponse))
            chunkContinuation.finish()
        }
    }
}

#endif
