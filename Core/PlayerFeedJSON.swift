import Foundation
import os

/// Runs one feed decode or projection off the main actor.
/// The decoded value is immutable and is read only after the background write finishes.
enum PlayerFeedJSON {
    static func perform<T>(_ work: @escaping () throws -> T) async throws -> T {
        nonisolated(unsafe) let work = work
        let slot = Slot()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    slot.set(try work())
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        guard let value = slot.take() as? T else { throw APIError.malformedResponse }
        return value
    }

    private final class Slot: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Any?
        func set(_ value: Any) {
            lock.lock()
            self.value = value
            lock.unlock()
        }
        func take() -> Any? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }
}

/// One HTTP body plus the status the transport reported. Not a stored cache.
public struct InFlightHTTPBody: Sendable, Equatable {
    public let data: Data
    public let status: Int
    public init(data: Data, status: Int) { self.data = data; self.status = status }
}

/// Identity of a read. Form boundaries are random, so form posts key on the fields.
public enum InFlightReadKey {
    public static func fields(method: String, path: String, fields: [String: String], token: String?, tag: String = "") -> String {
        var lines = [method, path, "form", token ?? "", tag]
        for key in fields.keys.sorted() {
            let value = fields[key] ?? ""
            lines.append("\(key.utf8.count):\(key)=\(value.utf8.count):\(value)")
        }
        return lines.joined(separator: "\n")
    }

    public static func bytes(method: String, path: String, body: Data, token: String?, tag: String = "") -> String {
        [method, path, "bytes", token ?? "", tag, body.base64EncodedString()].joined(separator: "\n")
    }

    public static func query(path: String, items: [URLQueryItem], token: String) -> String {
        let lines = items.map { item in
            let name = item.name
            let value = item.value ?? ""
            return "\(name.utf8.count):\(name)=\(value.utf8.count):\(value)"
        }.sorted()
        return (["GET", path, "query", token] + lines).joined(separator: "\n")
    }

    /// One key for a built request. Multipart boundaries are random, so they are not part of the key.
    public static func request(_ request: URLRequest) -> String {
        let method = request.httpMethod ?? ""
        let url = request.url
        let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
        return [method, url?.path ?? "", url?.query ?? "", token, normalizedBody(request)].joined(separator: "\n")
    }

    private static func normalizedBody(_ request: URLRequest) -> String {
        guard let data = request.httpBody, let text = String(data: data, encoding: .utf8) else { return "" }
        guard let header = request.value(forHTTPHeaderField: "Content-Type"),
              let marker = header.range(of: "boundary=") else { return text }
        let boundary = header[marker.upperBound...].trimmingCharacters(in: .whitespaces)
        guard !boundary.isEmpty else { return text }
        return text.replacingOccurrences(of: boundary, with: "boundary")
    }
}

/// Runs one body for a key while that read is still in flight. The value is dropped when it finishes.
public final class InFlightReadCoalescer<Value>: @unchecked Sendable {
    private struct Slot {
        let id: UUID
        let task: Task<Value, Error>
        var waiters: Int
    }

    private let lock = OSAllocatedUnfairLock()
    private var slots: [String: Slot] = [:]
    /// A body that finished before its slot was published. Cleared when publish observes it.
    private var finishedEarly: Set<UUID> = []
    /// Reads retired by their last cancelled waiter; their late finish must not mark `finishedEarly`.
    private var retired: Set<UUID> = []

    public init() {}

    public func isInFlight(_ key: String) -> Bool {
        lock.withLock { slots[key] != nil }
    }

    /// A read whose every waiter was cancelled is retired: its shared task is cancelled and the key
    /// is freed, so a later (fresh-lifetime) caller dispatches its own read instead of adopting the
    /// held, retired response. Regression from 82a8c6126, which made cancelled reads join-able.
    public func join(_ key: String, _ body: @escaping () async throws -> Value) async throws -> Value {
        let (task, id): (Task<Value, Error>, UUID) = lock.withLock {
            if var existing = slots[key] {
                existing.waiters += 1; slots[key] = existing
                return (existing.task, existing.id)
            }
            let id = UUID()
            let task = Task { () throws -> Value in
                defer { self.finish(key, id) }
                return try await body()
            }
            if finishedEarly.remove(id) == nil {
                slots[key] = Slot(id: id, task: task, waiters: 1)
            }
            return (task, id)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            self.leave(key, id)
        }
    }

    private func leave(_ key: String, _ id: UUID) {
        let orphan: Task<Value, Error>? = lock.withLock {
            guard var slot = slots[key], slot.id == id else { return nil }
            slot.waiters -= 1
            if slot.waiters > 0 { slots[key] = slot; return nil }
            slots[key] = nil; retired.insert(id)
            return slot.task
        }
        orphan?.cancel()
    }

    private func finish(_ key: String, _ id: UUID) {
        lock.withLock {
            if retired.remove(id) != nil { return }
            if slots[key]?.id == id {
                slots[key] = nil
            } else if slots[key] == nil {
                finishedEarly.insert(id)
            }
        }
    }
}
