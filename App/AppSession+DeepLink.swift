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

import SwiftUI

/// DEBUG verification hook: `--debug-open-url <url>` hands one URL to the same `receiveNativeURL` intake as
/// `onOpenURL`, once, after the session has restored. The app registers no URL scheme yet, so on-device checks of
/// chein:// links need this; Release builds compile it to nothing.
struct DebugOpenURLLaunchArgument: ViewModifier {
    let session: AppSession
    func body(content: Content) -> some View {
        #if DEBUG
        content.task {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "--debug-open-url"), arguments.indices.contains(index + 1),
                  let url = URL(string: arguments[index + 1]) else { return }
            for _ in 0..<60 where !session.restorationFinished { try? await Task.sleep(nanoseconds: 100_000_000) }
            let delay = arguments.firstIndex(of: "--debug-open-url-delay").flatMap { arguments.indices.contains($0 + 1) ? Double(arguments[$0 + 1]) : nil } ?? 0.8
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            session.receiveNativeURL(url)
        }
        #else
        content
        #endif
    }
}
