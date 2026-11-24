import Foundation

/// Same-origin check for `ReviewedOrientOfficialRoute`. Kept out of `AppCompositionRoot.swift` (size ratchet).
extension ReviewedOrientOfficialRoute {
    static func sameOrigin(_ url: URL, _ baseURL: URL) -> Bool {
        url.scheme == baseURL.scheme && url.host == baseURL.host && url.port == baseURL.port
    }
}
