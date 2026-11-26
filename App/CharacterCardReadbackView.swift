import SwiftUI

/// Leaves the card retired when the page goes away. A late read cannot refill it.
/// subpackageMember/character/index: branches on `CharacterCardPageModel.phase` (loading / empty / error / unknown / ready).
@available(macOS 14.0, *)
@MainActor struct CharacterCardReadbackView: View {
    @ObservedObject var session: AppSession
    let model: CharacterCardReadback
    @State private var login = false
    @Environment(\.dismiss) private var dismiss
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
                // R7-MEM-24-1: MP `failure()` states (user-character.js:121-131): 登录 / 无权查看 / 暂时无法查看该主题 /
                // 链接已失效 / 登录状态已变更 / 请更新 / 角色卡暂时无法读取, each with the MP action or none.
                let failure = CharacterCardFailure(model.issue)
                CYEmptyState(systemImage: failure.systemImage, LocalizedStringKey(failure.titleKey),
                             messageIdentifier: "characterCard.error",
                             actionTitle: failure.actionKey.map { LocalizedStringKey($0) },
                             actionIdentifier: failure.actionIdentifier,
                             kind: .failure,
                             action: failure.hasAction ? {
                                 switch failure {
                                 case .signIn: login = true
                                 case .missingLink: dismiss()
                                 default: Task { await model.load() }
                                 }
                             } : nil)
            case .unknown:
                CYEmptyState(systemImage: "person.text.rectangle", "characterCard.unavailable",
                             detailVerbatim: CharacterCardPageModel.unknownStat, messageIdentifier: "characterCard.unknown",
                             actionTitle: "characterCard.refresh", actionIdentifier: "characterCard.refresh") { Task { await model.load() } }
                    .accessibilityLabel(Text("characterCard.unavailable"))
                    .accessibilityValue(Text(verbatim: CharacterCardPageModel.unknownStat))
                    .accessibilityHint(Text("characterCard.refresh"))
            case .empty:
                // A failed refresh of a card that had nothing to show keeps that card and the failure.
                // With no failure, this is the MP missing-param state 链接已失效 · 返回 (character/index.wxml:10).
                if model.isCurrent, model.issue != nil, let card {
                    readyCard(card)
                } else {
                    CYEmptyState(systemImage: "link.badge.plus", "characterCard.empty", messageIdentifier: "characterCard.empty",
                                 actionTitle: "characterCard.back", actionIdentifier: "characterCard.back") { dismiss() }
                }
            case .ready:
                if model.isCurrent, let card {
                    readyCard(card)
                } else {
                    CYLoadingState("characterCard.loading", messageIdentifier: "characterCard.loading")
                }
            }
        }
        .cyAnimation(CYMotion.standard, value: page.phase)
        .cyPageTitle("characterCard.title")
        .sheet(isPresented: $login, onDismiss: { Task { await model.load() } }) {
            LoginView(intent: .player).environmentObject(session)
        }
        .task { await model.load() }
        .onDisappear { model.dismiss() }
    }

    /// PLY-24-6: the ready card ends with a system 刷新角色卡 button. It calls the existing read.
    /// A failure stays on this card; the button does not depend on pull-to-refresh.
    private func readyCard(_ card: CharacterCard) -> some View {
        CharacterSheetDetailView(card: card, rpgSheet: card.rpgSheet, definitionSource: card.definitionSource,
                                 attributeLevels: card.attributeLevels)
            .safeAreaInset(edge: .bottom, spacing: CYSpacing.sm) {
                VStack(spacing: CYSpacing.sm) {
                    if model.issue != nil {
                        let failure = CharacterCardFailure(model.issue)
                        Text(LocalizedStringKey(failure.titleKey))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("characterCard.refresh.failure")
                    }
                    Button("characterCard.refresh") { Task { await model.load() } }
                        .buttonStyle(.bordered)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("characterCard.refresh.ready")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.sm)
                .background(CYColor.bgPage)
            }
    }

}

/// R7-MEM-24-1: the MP character page failure states (`STATES` in character/index.js).
enum CharacterCardFailure: Equatable {
    case signIn, forbidden, unavailable, missingLink, sessionChanged, upgrade, error
    init(_ issue: PlayExperienceError?) {
        switch issue {
        case .unauthorized?: self = .signIn
        case .staleSession?: self = .sessionChanged
        case .unsupported?: self = .upgrade
        case .rejected(let code, _)?:
            switch code {
            case 401, 2: self = .signIn
            case 403: self = .forbidden
            case 404: self = .unavailable
            case 400: self = .missingLink
            case 426: self = .upgrade
            default: self = .error
            }
        default: self = .error
        }
    }
    var titleKey: String {
        switch self {
        case .signIn: return "characterCard.failure.unauthorized"
        case .forbidden: return "characterCard.failure.forbidden"
        case .unavailable: return "characterCard.failure.topicUnavailable"
        case .missingLink: return "characterCard.empty"
        case .sessionChanged: return "characterCard.failure.sessionChanged"
        case .upgrade: return "characterCard.failure.upgrade"
        case .error: return "characterCard.failure.error"
        }
    }
    var systemImage: String {
        switch self {
        case .signIn, .forbidden, .sessionChanged: return "lock"
        case .unavailable: return "questionmark.folder"
        case .missingLink: return "link.badge.plus"
        case .upgrade: return "arrow.down.app"
        case .error: return "exclamationmark.triangle"
        }
    }
    /// MP: 不可查看 and 请更新 carry no action.
    var hasAction: Bool { self != .unavailable && self != .upgrade }
    var actionKey: String? {
        switch self {
        case .signIn: return "auth.signIn"
        case .missingLink: return "characterCard.back"
        case .unavailable, .upgrade: return nil
        default: return "characterCard.refresh"
        }
    }
    var actionIdentifier: String? {
        switch self {
        case .signIn: return "characterCard.signIn"
        case .missingLink: return "characterCard.back"
        case .unavailable, .upgrade: return nil
        default: return "characterCard.refresh"
        }
    }
}
