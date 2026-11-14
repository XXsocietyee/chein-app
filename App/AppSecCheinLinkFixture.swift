#if DEBUG
import SwiftUI

/// Offline fixture for one malicious `chein://` link. It calls the existing parsers and shows a destination
/// only when one of them accepts the URL. No session, no transport, no production host.
@MainActor struct AppSecCheinLinkFixtureHost: View {
    private let opened: String?

    init() {
        let args = ProcessInfo.processInfo.arguments
        let raw: String
        if let index = args.firstIndex(of: "--appsec-chein-url"), args.indices.contains(index + 1) {
            raw = args[index + 1]
        } else {
            raw = ""
        }
        opened = Self.classifiedPage(raw)
    }

    var body: some View {
        Group {
            if let opened {
                Text(verbatim: opened)
                    .accessibilityIdentifier("appsec.chein.opened")
            } else {
                Text(verbatim: "—")
                    .accessibilityIdentifier("appsec.chein.closed")
            }
        }
    }

    /// Existing classifiers only. A nil URL, an unknown page, or a rejected token stays closed.
    private static func classifiedPage(_ raw: String) -> String? {
        guard let url = URL(string: raw) else { return nil }
        if let page = MiniProgramPageLink(cheinURL: url) { return page.page }
        if CheinDeepLink(url: url) != nil { return "chein" }
        return nil
    }
}
#endif
