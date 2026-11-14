import Foundation

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
