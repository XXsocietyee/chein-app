import Foundation
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

struct ExternalGameSessionBridge {
    let baseURL: URL
    let token: String
    let transport: any HTTPTransport
}

private struct ExternalGameSessionKey: EnvironmentKey {
    static let defaultValue: ExternalGameSessionBridge? = nil
}

extension EnvironmentValues {
    var externalGameSession: ExternalGameSessionBridge? {
        get { self[ExternalGameSessionKey.self] }
        set { self[ExternalGameSessionKey.self] = newValue }
    }
}

@available(macOS 14.0, *)
struct ExternalGameCatalogLaunch: ViewModifier {
    @Environment(\.externalGameSession) private var session

    func body(content: Content) -> some View {
        content.task(id: session?.token) {
            await ColdStartAfterFirstFrame.waitUntilOpen()
            await Self.refresh(session)
        }
    }

    /// Approved-catalog read after the first frame. A failed read leaves installed games in place.
    @MainActor static func refresh(_ session: ExternalGameSessionBridge?) async {
        guard ExternalGameSessionRead.externalGamesOpen(baseURL: session?.baseURL) else { return }
        let store = ExternalGameStore()
        let model = ExternalGameReviewModel(store: store)
        await model.reload(session: session)
    }
}

enum ExternalGameSessionRead {
    /// `externalGames(host:testOrDebug:)` on `ReviewedAreaSwitch`. That call needs TEST/DEBUG and a host other than `productionHost` (`productionAPIHost` is the same string). `externalGames(apiHost:)` follows the host only and is not this mount.
    static func externalGamesOpen(baseURL: URL?, bundle: Bundle = .main) -> Bool {
        let host: String
        if let baseURL {
            host = baseURL.host ?? ""
        } else {
            let raw = bundle.object(forInfoDictionaryKey: "QUESTIFY_API_BASE_URL") as? String ?? ""
            host = Self.host(from: raw)
        }
        return ReviewedAreaSwitch.externalGames(host: host, testOrDebug: ReviewedAreaSwitch.compiledTestOrDebug)
    }

    private static func host(from baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let url = URL(string: trimmed), let host = url.host, !host.isEmpty { return host }
        return trimmed
    }

    @MainActor static func bridge(_ session: AppSession) -> ExternalGameSessionBridge? {
        guard let base = session.regionalConfiguration?.apiConfiguration?.baseURL,
              let token = session.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return ExternalGameSessionBridge(baseURL: base, token: token, transport: session.runtimeHTTPTransport)
    }
}
