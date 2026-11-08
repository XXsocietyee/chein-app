import SwiftUI

/// Mini-program `pages/team/detail` / `pages/team/join` header, state shell and notes.
/// Presentation only; every action still goes through `TeamScreenModel` and the review sheet.
struct TeamPageHeader: View {
    let detail: TeamDetail
    let kind: TeamPageKind
    var confirmedJoinMode: TeamJoinMode? = nil
    @Environment(\.locale) private var locale
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    @ViewBuilder private var teamTitle: some View {
        let title = detail.team.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { Text("team.untitled").font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary) }
        else { Text(verbatim: title).font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if kind == .invitation {
                // Mini join page `.team-head`: eyebrow, title, explainer, then the meta card.
                teamTitle
                Text("team.page.inviteExplainer").font(CYTypography.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamPage.inviteExplainer")
            } else {
                // Mini `.team-status(.live)`: brand-soft pill while recruiting, neutral pill otherwise.
                Text(LocalizedStringKey(detail.team.status.key)).font(CYTypography.label)
                    .foregroundStyle(TeamPagePresentation.statusIsLive(detail.team.status) ? CYColor.accentText : CYColor.textSecondary)
                    .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                    .background(TeamPagePresentation.statusIsLive(detail.team.status) ? CYColor.accentSoft : CYColor.bgElevated, in: Capsule())
                    .accessibilityIdentifier("teamPage.status")
                teamTitle
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(TeamPagePresentation.modeKey(confirmedJoinMode ?? detail.team.joinMode)))
                    Text(verbatim: "·").accessibilityHidden(true)
                    Text("team.page.noEffectOnActivity")
                }.font(CYTypography.body).foregroundStyle(CYColor.textSecondary).accessibilityElement(children: .combine)
                    .accessibilityIdentifier("teamPage.subtitle")
            }
            // Mini `.team-meta`: two equal columns, bold value over caption key (members / start or method).
            HStack(alignment: .top, spacing: CYSpacing.xl) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if let joined = detail.team.joinedCount, let max = detail.team.maxMembers { Text(verbatim: "\(joined) / \(max)").font(CYTypography.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary) }
                    else { Text(verbatim: "—").font(CYTypography.numericBody).foregroundStyle(CYColor.textPrimary) }
                    Text("team.members.count").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if kind == .invitation { Text("team.page.inviteOnlyMethod").font(CYTypography.numericBody).foregroundStyle(CYColor.textPrimary) }
                    else if let start = TeamPagePresentation.startText(detail.team.expireTime, chinese: chinese) { Text(verbatim: start).font(CYTypography.numericBody).foregroundStyle(CYColor.textPrimary) }
                    else { Text("team.page.startPending").font(CYTypography.numericBody).foregroundStyle(CYColor.textPrimary) }
                    Text(kind == .invitation ? "team.mode.title" : "team.sessionStart").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.meta")
            }.padding(.top, CYSpacing.sm)
            if kind == .invitation {
                Text("team.join.consequence").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
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
        VStack(spacing: CYSpacing.md) {
            Image(systemName: state.kind == .signIn ? "person.crop.circle.badge.questionmark" : "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            Text(LocalizedStringKey(state.titleKey)).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
                .accessibilityIdentifier("teamPage.state.title")
            Text(LocalizedStringKey(state.detailKey)).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let key = state.actionKey, let action = handler {
                Button(LocalizedStringKey(key), action: action).buttonStyle(.cyPrimary)
                    .accessibilityIdentifier("teamPage.state.action")
            }
        }.padding().frame(maxWidth: .infinity)
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
            Label(LocalizedStringKey(title), systemImage: "arrow.clockwise.circle").font(CYTypography.label.weight(.semibold)).foregroundStyle(CYColor.warningText)
            Text(LocalizedStringKey(detail)).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        }.padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.warningSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.stale")
    }
}

/// The source join page's disabled CTA for a full or ended team.
struct TeamClosedInvitationButton: View {
    let cta: TeamInvitationCTA
    var body: some View {
        Button {} label: { Text(LocalizedStringKey(cta.key)) }
            .buttonStyle(.cySecondary(fullWidth: true)).disabled(true).accessibilityIdentifier("teamPage.closedInvitation")
    }
}

/// Source join page `cy-inline-error` 暂时无法加入; the retry button below opens a new review.
struct TeamJoinRetryNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("team.page.joinFailed", systemImage: "exclamationmark.circle").font(CYTypography.label.weight(.semibold)).foregroundStyle(CYColor.dangerText)
            Text("team.page.joinFailed.detail").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }.padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.dangerSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.joinFailed")
    }
}
