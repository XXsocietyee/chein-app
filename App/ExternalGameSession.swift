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
        content.task(id: session?.token) { await Self.refresh(session) }
    }

    /// Approved-catalog read at launch. A failed read leaves installed games in place.
    @MainActor static func refresh(_ session: ExternalGameSessionBridge?) async {
        guard ReviewedAreaSwitch.externalGamesMount() else { return }
        let store = ExternalGameStore()
        let model = ExternalGameReviewModel(store: store)
        await model.reload(session: session)
    }
}

enum ExternalGameSessionRead {
    @MainActor static func bridge(_ session: AppSession) -> ExternalGameSessionBridge? {
        guard let base = session.regionalConfiguration?.apiConfiguration?.baseURL,
              let token = session.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return ExternalGameSessionBridge(baseURL: base, token: token, transport: session.runtimeHTTPTransport)
    }
}
