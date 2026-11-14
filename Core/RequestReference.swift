import Foundation

/// OWN-OPT-072: the non-sensitive server request reference (`x-request-id`, a 32-hex id) of the latest response
/// per route family, so an unknown-result or server-error state can show something copyable for support.
/// Only the id and the URL path are kept: never a token, header value other than the id, query, body or user id.
public final class RequestReferenceLedger: @unchecked Sendable {
    public static let shared = RequestReferenceLedger()
    public static let headerName = "x-request-id"
    private struct Entry { let path: String; let reference: String; let at: Date }
    private let lock = NSLock()
    private var entries: [Entry] = []
    private let capacity = 32
    public init() {}

    /// Ids are 8–64 characters of `[0-9A-Za-z-]`; anything else is dropped rather than shown.
    public static func sanitize(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespaces), (8...64).contains(value.count),
              value.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" }) else { return nil }
        return value
    }
    public func record(path: String, headerValue: String?, now: Date = Date()) {
        guard let reference = Self.sanitize(headerValue) else { return }
        lock.lock(); defer { lock.unlock() }
        entries.append(Entry(path: path, reference: reference, at: now))
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }
    public func record(_ response: HTTPURLResponse, now: Date = Date()) {
        record(path: response.url?.path ?? "", headerValue: response.value(forHTTPHeaderField: Self.headerName), now: now)
    }
    /// The newest reference whose path contains `pathFragment`, no older than `maxAge`.
    public func latest(pathFragment: String, maxAge: TimeInterval = 120, now: Date = Date()) -> String? {
        lock.lock(); defer { lock.unlock() }
        return entries.last { $0.path.contains(pathFragment) && now.timeIntervalSince($0.at) <= maxAge }?.reference
    }
    public func clear() { lock.lock(); entries.removeAll(); lock.unlock() }
}
