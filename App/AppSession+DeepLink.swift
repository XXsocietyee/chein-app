import Foundation

/// W3-6 chein:// intake. Kept out of `AppSession.swift` (size ratchet). A link grants nothing: a valid one only records
/// the owning tab request in `pendingDeepLink`; destination gating (sign-in, capability, confirmation) stays with the screen.
extension AppSession {
    /// True when `url` is a chein:// URL and was handled here (valid -> pending link, invalid -> unsupported route error).
    func receiveCheinURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == CheinDeepLink.scheme else { return false }
        if receiveMiniProgramPageURL(url) { return true }
        if let link = CheinDeepLink(url: url) { pendingDeepLink = link } else { receiveNativeIntent(.routeError(.unsupported)) }
        return true
    }

    func consumeDeepLink() -> CheinDeepLink? { defer { pendingDeepLink = nil }; return pendingDeepLink }
}
