import Foundation

/// A one-shot delivery gate for an untrusted, unmodified scanner payload.
///
/// Validation belongs to the receiving feature. In particular, accepting text here
/// does not authorize opening a URL, redeeming a code, or writing to a service.
struct ScanPayloadGate {
    private(set) var isFinished = false

    mutating func take(_ payload: String?) -> String? {
        guard !isFinished, let payload, !payload.isEmpty else { return nil }
        isFinished = true
        return payload
    }

    mutating func cancel() {
        isFinished = true
    }
}

/// FP-C7. One classification point for scanned text. It only decides which typed destination a payload
/// names; it never opens, redeems, verifies or writes anything. Ticket, coupon and door-verification codes
/// stay with their owning features, so text that is not a verified link or a known source path is
/// `.unrecognized` and is never guessed into a destination.
public enum ScanRoute: Equatable {
    case entry(NativeEntryIntent)
    case unrecognized
}
public struct ScanRouter {
    private let links: NativeEntryLinkPolicy
    /// The default policy has no verified origins, so a scanned https link routes nowhere until the host supplies them.
    public init(links: NativeEntryLinkPolicy = NativeEntryLinkPolicy()) { self.links = links }
    public func route(_ payload: String?) -> ScanRoute {
        guard let payload, !payload.isEmpty, payload.utf8.count <= 8192,
              !payload.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return .unrecognized }
        // Surrounding whitespace is a scanner artifact for routing only; the raw payload is untouched elsewhere.
        let text = payload.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("https://") {
            guard let url = URL(string: text), let intent = links.parse(url) else { return .unrecognized }
            return .entry(PlayerLaunch.gate(intent)) // Lane G
        }
        // Mini-program share codes carry a source path, with or without the leading slash.
        let path = text.hasPrefix("/") ? text : (text.hasPrefix("pages/") || text.hasPrefix("subpackage") ? "/" + text : nil)
        guard let path, let intent = NativeNavigationContract.parseInternal(path) else { return .unrecognized }
        return .entry(PlayerLaunch.gate(intent)) // Lane G
    }
}
