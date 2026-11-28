import SwiftUI

/// Mini-program `pages/team/detail` / `pages/team/join` header, state shell and notes.
/// Presentation only; every action still goes through `TeamScreenModel` and the review sheet.
struct TeamPageHeader: View {
    let detail: TeamDetail
    let kind: TeamPageKind
    var confirmedJoinMode: TeamJoinMode? = nil
    /// MP team/detail `teamTitleOf`: an unnamed team is called after its captain (「X的队伍」), then the generic name.
    /// MP team/join shows `team.title || '一起出发的玩家队伍'` only.
    private var captainName: String? {
        guard kind == .detail else { return nil }
        let name = detail.members.first(where: { $0.isCaptain })?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
    @ViewBuilder private var teamTitle: some View {
        let title = detail.team.title.trimmingCharacters(in: .whitespacesAndNewlines)
        Group {
            if !title.isEmpty { Text(verbatim: title) }
            else if let captainName { Text("mpr3.team.captainTeam \(captainName)") }
            else { Text("team.untitled") }
        }
        .font(.title2.bold()).accessibilityAddTraits(.isHeader).fixedSize(horizontal: false, vertical: true)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kind == .invitation {
                // MP join `.tj-head`: the title alone; seats, facts and the deadline follow in the `.tj-card` section.
                teamTitle
            } else {
                // Mini `.team-status(.live)`: a live symbol while recruiting, plain status otherwise.
                let live = TeamPagePresentation.statusIsLive(detail.team.status)
                Label {
                    Text(LocalizedStringKey(detail.team.status.key))
                } icon: {
                    Image(systemName: live ? "dot.radiowaves.left.and.right" : "circle.fill")
                        .imageScale(live ? .medium : .small)
                        .foregroundStyle(live ? Color.green : Color.secondary)
                }
                .font(.subheadline)
                .accessibilityIdentifier("teamPage.status")
                teamTitle
                // MP detail wxml:26 `.team-sub`: 公开招募 / 仅邀请, hidden for the captain of a recruiting team
                // (the 公开招募 switch below says it instead).
                if !(detail.leader == true && detail.team.status == .recruiting) {
                    Text(LocalizedStringKey(TeamPagePresentation.modeKey(confirmedJoinMode ?? detail.team.joinMode)))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("teamPage.subtitle")
                }
                // Mini `.team-meta`: two equal columns, value over caption key (members / session start).
                TeamPageFacts(detail: detail, kind: .detail).padding(.top, 4)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// MP `.team-meta` (detail: 当前成员 / 场次开始) and `.tj-facts` (join: 当前成员 / 加入方式), value over caption.
/// Side by side; stacked at accessibility text sizes so long English never truncates.
struct TeamPageFacts: View {
    let detail: TeamDetail
    let kind: TeamPageKind
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        let metaLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        metaLayout {
            VStack(alignment: .leading, spacing: 2) {
                // A missing joined count or capacity is an em dash; a literal 0 stays "0 / max".
                Text(verbatim: TeamPagePresentation.memberCountText(detail.team))
                    .font(.headline).monospacedDigit()
                    .contentTransition(.numericText())
                Text("team.members.count").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    // MP join wxml:46 `team.joinMode == 2 ? '公开招募' : '仅邀请'`.
                    if kind == .invitation { Text(LocalizedStringKey(TeamPagePresentation.modeKey(detail.team.joinMode))) }
                    else if let start = TeamPagePresentation.startText(detail.team.expireTime, chinese: chinese) { Text(verbatim: start) }
                    else { Text("team.page.startPending") }
                }.font(.headline)
                Text(kind == .invitation ? "team.mode.title" : "team.sessionStart").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
                .accessibilityIdentifier(kind == .invitation ? "teamJoin.facts" : "teamPage.meta")
        }
    }
}

struct TeamPageStateView: View {
    let state: TeamPageState
    var signIn: (() -> Void)?
    var reload: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(state.titleKey)).accessibilityIdentifier("teamPage.state.title")
            } icon: {
                Image(systemName: state.kind == .signIn ? "person.crop.circle.badge.questionmark" : "exclamationmark.triangle")
            }
        } description: {
            Text(LocalizedStringKey(state.detailKey))
        } actions: {
            if let actionKey = state.actionKey, let handler {
                Button(action: handler) { Text(LocalizedStringKey(actionKey)) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("teamPage.state.action")
            }
        }
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
            Label(LocalizedStringKey(title), systemImage: "arrow.clockwise.circle").font(.subheadline.weight(.semibold)).foregroundStyle(CYColor.warningText)
            Text(LocalizedStringKey(detail)).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.stale")
    }
}

/// The source join page's disabled CTA for a full or ended team.
struct TeamClosedInvitationButton: View {
    let cta: TeamInvitationCTA
    var body: some View {
        Button {} label: { Text(LocalizedStringKey(cta.key)).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered).controlSize(.large)
            .disabled(true).accessibilityIdentifier("teamPage.closedInvitation")
    }
}

/// Source join page `cy-inline-error` 暂时无法加入; the retry button below opens a new review.
struct TeamJoinRetryNotice: View {
    /// U06-01: the `/join` errorCode copy (INVITE_EXPIRED, TEAM_FULL, TICKET_REQUIRED…) when the server sent one.
    var reasonKey: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("team.page.joinFailed", systemImage: "exclamationmark.circle").font(.subheadline.weight(.semibold)).foregroundStyle(CYColor.dangerText)
            Text(LocalizedStringKey(reasonKey ?? "team.page.joinFailed.detail")).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine).accessibilityIdentifier("teamPage.joinFailed")
    }
}
