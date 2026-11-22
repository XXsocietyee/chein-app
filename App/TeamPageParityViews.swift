import SwiftUI

/// Mini-program `pages/team/detail` / `pages/team/join` header, state shell and notes.
/// Presentation only; every action still goes through `TeamScreenModel` and the review sheet.
struct TeamPageHeader: View {
    let detail: TeamDetail
    let kind: TeamPageKind
    var confirmedJoinMode: TeamJoinMode? = nil
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    @ViewBuilder private var teamTitle: some View {
        let title = detail.team.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { Text("team.untitled").cyText(.pageTitle).accessibilityAddTraits(.isHeader).foregroundStyle(CYColor.textPrimary) }
        else { Text(verbatim: title).cyText(.pageTitle).accessibilityAddTraits(.isHeader).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if kind == .invitation {
                // Mini join page `.team-head`: eyebrow, title, explainer, then the meta card.
                teamTitle
                Text("team.page.inviteExplainer").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamPage.inviteExplainer")
            } else {
                // Mini `.team-status(.live)`: brand-soft pill while recruiting, neutral pill otherwise.
                CYStatusChip(LocalizedStringKey(detail.team.status.key),
                             tone: TeamPagePresentation.statusIsLive(detail.team.status) ? .success : .neutral,
                             systemImage: TeamPagePresentation.statusIsLive(detail.team.status) ? "dot.radiowaves.left.and.right" : nil)
                    .accessibilityIdentifier("teamPage.status")
                teamTitle
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(TeamPagePresentation.modeKey(confirmedJoinMode ?? detail.team.joinMode)))
                    Text(verbatim: "·").accessibilityHidden(true)
                    Text("team.page.noEffectOnActivity")
                }.cyText(.body).foregroundStyle(CYColor.textSecondary).accessibilityElement(children: .combine)
                    .accessibilityIdentifier("teamPage.subtitle")
            }
            // Mini `.team-meta`: two equal columns, bold value over caption key (members / start or method).
            let metaLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.lg))
                : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.xl))
            metaLayout {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    // pages/team/join: a missing joined count or capacity is an em dash; a literal 0 stays "0 / max".
                    Text(verbatim: TeamPagePresentation.memberCountText(detail.team))
                        .cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("team.members.count").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if kind == .invitation { Text("team.page.inviteOnlyMethod").cyText(.numericBody).foregroundStyle(CYColor.textPrimary) }
                    else if let start = TeamPagePresentation.startText(detail.team.expireTime, chinese: chinese) { Text(verbatim: start).cyText(.numericBody).foregroundStyle(CYColor.textPrimary) }
                    else { Text("team.page.startPending").cyText(.numericBody).foregroundStyle(CYColor.textPrimary) }
                    Text(kind == .invitation ? "team.mode.title" : "team.sessionStart").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.meta")
            }.padding(.top, CYSpacing.sm)
            if kind == .invitation {
                Text("team.join.consequence").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TeamPageStateView: View {
    let state: TeamPageState
    var signIn: (() -> Void)?
    var reload: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        CYEmptyState(
            systemImage: state.kind == .signIn ? "person.crop.circle.badge.questionmark" : "exclamationmark.triangle",
            LocalizedStringKey(state.titleKey),
            detail: LocalizedStringKey(state.detailKey),
            messageIdentifier: "teamPage.state.title",
            actionTitle: state.actionKey.map { LocalizedStringKey($0) },
            actionIdentifier: "teamPage.state.action",
            actionStyle: .primary,
            action: handler
        )
        .frame(maxWidth: .infinity)
    }
    private var handler: (() -> Void)? {
        switch state.action {
        case .goBack: return { dismiss() }
        case .signIn: return signIn
        case .reload: return reload
        case .none: return nil
        }
    }
}

struct TeamStaleBanner: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(LocalizedStringKey(title), systemImage: "arrow.clockwise.circle").cyText(.label, weight: .semibold).foregroundStyle(CYColor.warningText)
            Text(LocalizedStringKey(detail)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }.padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.warningSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.stale")
    }
}

/// The source join page's disabled CTA for a full or ended team.
struct TeamClosedInvitationButton: View {
    let cta: TeamInvitationCTA
    var body: some View {
        CYPillButton(LocalizedStringKey(cta.key), style: .secondary) {}
            .disabled(true).accessibilityIdentifier("teamPage.closedInvitation")
    }
}

/// Source join page `cy-inline-error` 暂时无法加入; the retry button below opens a new review.
struct TeamJoinRetryNotice: View {
    /// U06-01: the `/join` errorCode copy (INVITE_EXPIRED, TEAM_FULL, TICKET_REQUIRED…) when the server sent one.
    var reasonKey: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("team.page.joinFailed", systemImage: "exclamationmark.circle").cyText(.label, weight: .semibold).foregroundStyle(CYColor.dangerText)
            Text(LocalizedStringKey(reasonKey ?? "team.page.joinFailed.detail")).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }.padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.dangerSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.joinFailed")
    }
}
