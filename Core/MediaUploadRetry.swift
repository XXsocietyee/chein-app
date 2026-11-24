import Foundation

/// Bounded auto-retry for an idempotent media upload. A non-idempotent write is one attempt.
/// Transport failures retry with backoff, at most three attempts. A rejection does not retry.
public enum MediaUploadRetryError: Error, Equatable {
    case transport
    case rejected
}

public enum MediaUploadRetry {
    public static let maximumAttempts = 3

    /// Delay before the next attempt. `attempt` is the attempt that just failed (1, then 2).
    public static func delay(afterFailure attempt: Int) -> TimeInterval {
        guard attempt >= 1, attempt < maximumAttempts else { return 0 }
        return 0.2 * pow(2.0, Double(attempt - 1))
    }

    public static func isRetryable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if let upload = error as? MediaUploadRetryError { return upload == .transport }
        return error is URLError
    }

    public static func perform<T: Sendable>(
        idempotent: Bool,
        sleep: @Sendable (TimeInterval) async throws -> Void = { seconds in
            let delay = UInt64((seconds * 1_000_000_000).rounded())
            if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        },
        operation: @Sendable (Int) async throws -> T
    ) async throws -> T {
        let limit = idempotent ? maximumAttempts : 1
        var last: Error = MediaUploadRetryError.transport
        for attempt in 1...limit {
            do { return try await operation(attempt) }
            catch {
                last = error
                let retry = idempotent && attempt < limit && isRetryable(error)
                if !retry { throw error }
                try await sleep(delay(afterFailure: attempt))
            }
        }
        throw last
    }
}
