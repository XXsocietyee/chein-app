import SwiftUI

/// Leaves the card retired when the page goes away. A late read cannot refill it.
/// subpackageMember/character/index: branches on `CharacterCardPageModel.phase` (loading / empty / error / unknown / ready).
@available(macOS 14.0, *)
@MainActor struct CharacterCardReadbackView: View {
    @ObservedObject var session: AppSession
    let model: CharacterCardReadback
    @State private var login = false
    var body: some View {
        let _ = session.account?.id
        let card = model.cardIfCurrent()
        let page = model.pageModel
        // Mini-program subpackageMember/character: 我的角色卡 with the run's traits; states are user words, never raw availability codes.
        Group {
            switch page.phase {
            case .loading:
                CYLoadingState("characterCard.loading", messageIdentifier: "characterCard.loading")
            case .error:
                CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(failureKey),
                             messageIdentifier: "characterCard.error",
                             // MP offers 登录 on the signed-out state (character/index.js:84-91, PLY-24-3).
                             actionTitle: model.issue == .unauthorized ? "auth.signIn" : "characterCard.refresh",
                             actionIdentifier: model.issue == .unauthorized ? "characterCard.signIn" : "characterCard.refresh",
                             kind: .failure) {
                    if model.issue == .unauthorized { login = true } else { Task { await model.load() } }
                }
            case .unknown:
                CYEmptyState(systemImage: "person.text.rectangle", "characterCard.unavailable",
                             detailVerbatim: CharacterCardPageModel.unknownStat, messageIdentifier: "characterCard.unknown",
                             actionTitle: "characterCard.refresh", actionIdentifier: "characterCard.refresh") { Task { await model.load() } }
                    .accessibilityLabel(Text("characterCard.unavailable"))
                    .accessibilityValue(Text(verbatim: CharacterCardPageModel.unknownStat))
                    .accessibilityHint(Text("characterCard.refresh"))
            case .empty:
                // A loaded card with no attributes: count is a real 0, not unknown.
                CYEmptyState(systemImage: "person.text.rectangle", "characterCard.empty", messageIdentifier: "characterCard.empty",
                             actionTitle: "characterCard.refresh", actionIdentifier: "characterCard.refresh") { Task { await model.load() } }
            case .ready:
                if model.isCurrent, let card {
                    CharacterSheetDetailView(card: card, rpgSheet: card.rpgSheet, definitionSource: card.definitionSource,
                                             attributeLevels: card.attributeLevels)
                        .refreshable { await model.load() }
                } else {
                    CYLoadingState("characterCard.loading", messageIdentifier: "characterCard.loading")
                }
            }
        }
        .cyAnimation(CYMotion.standard, value: page.phase)
        .cyPageTitle("characterCard.title")
        .sheet(isPresented: $login, onDismiss: { Task { await model.load() } }) { LoginView(intent: .player) }
        .task { await model.load() }
        .onDisappear { model.dismiss() }
    }

    /// Source failure copy: sign in, no access, or a generic retry.
    private var failureKey: String {
        switch model.issue {
        case .unauthorized?: return "characterCard.failure.unauthorized"
        case .rejected(let code, _)?: return code == 403 ? "characterCard.failure.forbidden" : "characterCard.failure.error"
        default: return "characterCard.failure.error"
        }
    }
}
