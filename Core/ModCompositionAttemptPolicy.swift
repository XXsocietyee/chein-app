import Foundation

/// Exact reviewed node policy; nil count/duration remain unlimited/no challenge deadline.
public struct ModCompositionAttemptPolicy: Codable, Equatable {
    public let maxAttempts, timeoutSeconds: Int?
    public let onRejected, onTimedOut, onAbandoned: String?
    public var branches: [String: String] {
        var result: [String: String] = [:]
        if let onRejected { result["H5_REJECTED"] = onRejected }
        if let onTimedOut { result["H5_TIMEOUT"] = onTimedOut }
        if let onAbandoned { result["H5_ABANDONED"] = onAbandoned }; return result
    }
    public var valid: Bool {
        func node(_ s: String?) -> Bool { s?.range(of: #"\A[a-z][a-z0-9_-]{0,63}\z"#, options: .regularExpression) != nil }
        return (maxAttempts == nil ? onRejected == nil : (1...1_000_000).contains(maxAttempts!) && node(onRejected))
            && (timeoutSeconds == nil ? onTimedOut == nil : (1...31_536_000).contains(timeoutSeconds!) && node(onTimedOut))
            && (onAbandoned == nil || node(onAbandoned)) && !branches.isEmpty
    }
}
