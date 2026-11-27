import SwiftUI

/// Mini-program pages/club/governance + pages/club/roles presentation. Every action is an
/// existing `edit` route handed in by the read view; nothing here reads, writes or authorizes.
enum ClubOpsGovernanceCopy {
    static func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "ClubOpsGovernance") }
    static func source(_ source: ClubOpsBanSource) -> Text { text(source == .platform ? "clubOpsGov.source.platform" : "clubOpsGov.source.club") }
    static func time(_ value: String?) -> Text {
        if let value { return Text(verbatim: value) }
        return text("clubOpsGov.timeUnknown")
    }
    static func expiry(_ expiry: ClubOpsBanExpiry) -> Text {
        switch expiry {
        case .until(let value): return Text("clubOpsGov.until \(value)", tableName: "ClubOpsGovernance")
        case .platformPermanent: return text("clubOpsGov.platformPermanent")
        case .unknown: return text("clubOpsGov.timeUnknown")
        }
    }
    static func member(_ name: String?, id: Int) -> Text {
        if let name { return Text(verbatim: name) }
        return Text("clubOpsGov.memberNumber \(id)", tableName: "ClubOpsGovernance")
    }
    static let separator = Text(verbatim: " · ")
    /// `{来源} · {时间} · {至…|平台永久封禁}[ · 仅平台可解封]`, one description line as in the mini-program row.
    static func banLine(source: ClubOpsBanSource, bannedAt: String?, expiry: ClubOpsBanExpiry, platformOnly: Bool = false) -> Text {
        var line: Text = self.source(source)
        line = line + separator + time(bannedAt)
        line = line + separator + self.expiry(expiry)
        if platformOnly { line = line + separator + text("clubOpsGov.platformOnly") }
        return line
    }
}

/// CLB-governance-16 (MP governance wxss:7,17-22): ban and case status are plain coloured text, not pills.
/// Active bans read red, pending cases amber, everything else secondary.
private struct ClubOpsStatusText: View {
    enum Tone { case danger, warning, neutral }
    let label: Text
    var tone: Tone = .neutral
    var body: some View {
        label.font(.subheadline)
            .foregroundStyle(tone == .danger ? Color.red : (tone == .warning ? Color.orange : Color.secondary))
    }
}

private struct ClubOpsTag: View {
    let label: Text
    var isDanger: Bool = false
    var body: some View {
        label.font(.subheadline)
            .foregroundStyle(isDanger ? Color.red : Color.secondary)
    }
}

struct ClubOpsBanSection: View {
    let list: ClubOpsBanList
    var scope: ClubGovernanceScope? = nil
    var capability: ClubOpsGovernanceCapability? = nil
    var document: ClubGovernanceValue? = nil
    let unban: (ClubOpsBanRow) -> AnyView
    private var page: ClubOpsGovernancePage? {
        guard let scope, let capability else { return nil }
        return ClubOpsGovernancePage.project(bans: document, scope: scope, capability: capability)
    }
    private var countText: String? {
        guard page?.hidden == false, capability?.manageMembers == true, let count = page?.counts?.bans else { return nil }
        if count.literal == 0 { return "0" }
        return count.literal == nil ? "—" : count.displayText
    }
    var body: some View {
        let list = (page?.hidden == false ? page?.bans : nil) ?? self.list
        if page?.hidden != true, capability?.manageMembers != false {
        Section {
            // CLB-governance-07 (parity r2): the count carries its label, never a lone number.
            if let text = countText { Text("clubOpsGov.count.bans \(text)", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary).monospacedDigit() }
            if list.rows.isEmpty {
                ClubOpsGovernanceCopy.text("clubOpsGov.bans.empty").font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("clubOpsGov.bans.empty")
            }
            ForEach(list.rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("clubOpsGov.banTarget \(ClubOpsGovernanceCopy.member(row.nickname, id: row.targetMemberID))", tableName: "ClubOpsGovernance").font(.headline)
                        Spacer()
                        ClubOpsStatusText(label: ClubOpsGovernanceCopy.text("clubOpsGov.banStatus." + row.status.rawValue), tone: row.status == .active ? .danger : .neutral)
                    }
                    ClubOpsGovernanceCopy.banLine(source: row.source, bannedAt: row.bannedAt, expiry: row.expiry, platformOnly: row.platformOnly)
                        .font(.footnote).foregroundStyle(.secondary)
                    if let note = row.unbanReason {
                        Text("clubOpsGov.unbanNote \(note)", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary)
                    }
                    // CLB-governance-18: VoiceOver names the member on 解封.
                    if row.unbanSeed != nil {
                        unban(row).accessibilityLabel(Text("club.gov.a11y.unban \(row.nickname ?? "#\(row.targetMemberID)")"))
                    }
                }.accessibilityIdentifier("clubOpsGov.ban.\(row.id)")
            }
        } header: { Text("club.gov.bans") }
        }
    }
}

struct ClubOpsGovernanceMembersSection: View {
    let roster: ClubOpsGovernanceMembers
    let ban: (ClubOpsGovernanceMember) -> AnyView
    let transfer: (ClubOpsGovernanceMember) -> AnyView
    var scope: ClubGovernanceScope? = nil
    var capability: ClubOpsGovernanceCapability? = nil
    var document: ClubGovernanceValue? = nil
    var showsBan = true
    var memberGovernanceDenial: String? = nil
    @Environment(\.clubFocusMemberID) private var focusMemberID
    private var page: ClubOpsGovernancePage? {
        guard let scope, let capability else { return nil }
        return ClubOpsGovernancePage.project(members: document, scope: scope, capability: capability, includeBans: false, includeMembers: true, includeCases: false)
    }
    private var countText: String? {
        guard page?.hidden == false, let count = page?.counts?.members else { return nil }
        return count.displayText
    }
    var body: some View {
        Section {
            if let text = countText {
                Text("clubOpsGov.count.members \(text)", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary).monospacedDigit().accessibilityIdentifier(ClubOpsGovernancePage.Accessibility.memberCount)
            }
            if let memberGovernanceDenial {
                Text(verbatim: memberGovernanceDenial)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("club.memberGovernance.denied")
            }
            if roster.members.isEmpty {
                ContentUnavailableView {
                    Label { ClubOpsGovernanceCopy.text("clubOpsGov.members.empty").accessibilityIdentifier("clubOpsGov.members.empty") } icon: { Image(systemName: "person.2") }
                }
            }
            // One row per member: name, then its actions side by side (ban, and transfer for the owner).
            // CLB-G16: a `memberId` link lists that member first and marks it (MP preselects it).
            ForEach(ClubFocusMember.ordered(roster.members, focus: focusMemberID)) { member in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        // Round 2 MP asset: governance wxml:149 `item.avatar || d_profile.png` (the read has no avatar yet).
                        ClubMPAvatar(url: nil, name: member.nickname ?? "", size: .sm)
                        ClubOpsGovernanceCopy.member(member.nickname, id: member.id).font(.headline)
                        if member.id == focusMemberID {
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(member.id == focusMemberID ? .isSelected : [])
                    HStack(spacing: 8) {
                        // CLB-governance-18: VoiceOver names the member on 封禁 / 转让.
                        if showsBan {
                            ban(member).foregroundStyle(.red)
                                .accessibilityLabel(Text("club.gov.a11y.ban \(member.nickname ?? "#\(member.id)")"))
                        }
                        if roster.viewerIsOwner {
                            transfer(member).accessibilityLabel(Text("club.gov.a11y.transfer \(member.nickname ?? "#\(member.id)")"))
                        }
                    }.buttonStyle(.bordered).controlSize(.small)
                }.accessibilityIdentifier("clubOpsGov.member.\(member.id)")
            }
        } header: { ClubOpsGovernanceCopy.text("clubOpsGov.members.title") } footer: {
            // Mini-program 转让主理人 card: its one consequence line, shown once rather than under every member.
            if roster.viewerIsOwner, !roster.members.isEmpty { ClubOpsGovernanceCopy.text("clubOpsGov.transfer.hint") }
        }
    }
}

struct ClubOpsCaseSection: View {
    let list: ClubOpsCaseList
    let report: AnyView?
    let appeal: AnyView?
    var scope: ClubGovernanceScope? = nil
    var capability: ClubOpsGovernanceCapability? = nil
    var document: ClubGovernanceValue? = nil
    private var page: ClubOpsGovernancePage? {
        guard let scope, let capability else { return nil }
        return ClubOpsGovernancePage.project(cases: document, scope: scope, capability: capability, includeBans: false, includeMembers: false, includeCases: true)
    }
    private var countText: String? {
        guard page?.hidden == false, let count = page?.counts?.cases else { return nil }
        return count.displayText
    }
    var body: some View {
        Group {
        // Mini governance `mode=appeal` page title 封禁申诉 is the inline bar title (ClubGovernanceReadView.pageTitleKey).
        if list.canReport, let report {
            // CLB-governance-15 (parity r2): the 请提交可核实的事实 note stays once, in the form.
            Section {
                report
            } header: { ClubOpsGovernanceCopy.text("clubOpsGov.report.title") }
        }
        switch list.appeal {
        case .none:
            Section {
                ClubOpsGovernanceCopy.text("clubOpsGov.appeal.empty").font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("clubOpsGov.appeal.empty")
                // CLB-governance-10: MP sub 仅限期封禁可申诉.
                ClubOpsGovernanceCopy.text("clubOpsGov.appeal.emptyBody").font(.footnote).foregroundStyle(.tertiary)
            } header: { ClubOpsGovernanceCopy.text("clubOpsGov.appeal.title") }
        case .ban(let ban):
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ClubOpsGovernanceCopy.text("clubOpsGov.appeal.current").font(.headline)
                    ClubOpsGovernanceCopy.banLine(source: ban.source, bannedAt: ban.bannedAt, expiry: ban.expiry).font(.footnote).foregroundStyle(.secondary)
                    if let reason = ban.reason {
                        Text("clubOpsGov.banReason \(reason)", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("clubOpsGov.appeal.ban")
                ClubOpsGovernanceCopy.text("clubOpsGov.appeal.note").font(.footnote).foregroundStyle(.secondary)
                if let appeal { appeal }
            } header: { ClubOpsGovernanceCopy.text("clubOpsGov.appeal.title") }
        case .unknown: EmptyView()
        }
        Section {
            if let text = countText {
                Text("clubOpsGov.count.cases \(text)", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary).monospacedDigit().accessibilityIdentifier(ClubOpsGovernancePage.Accessibility.caseCount)
            }
            if list.rows.isEmpty {
                ClubOpsGovernanceCopy.text("clubOpsGov.cases.empty").font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("clubOpsGov.cases.empty")
            }
            ForEach(list.rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Self.type(row.kind).font(.headline)
                        if let reason = row.reason { Text(verbatim: reason).font(.subheadline) }
                        Text("clubOpsGov.submittedAt \(ClubOpsGovernanceCopy.time(row.submittedAt))", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary)
                        if let decision = row.decisionReason {
                            Text("clubOpsGov.decision \(decision)", tableName: "ClubOpsGovernance").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    ClubOpsStatusText(label: ClubOpsGovernanceCopy.text("clubOpsGov.caseStatus." + row.status.rawValue), tone: row.status == .pending ? .warning : .neutral)
                }.accessibilityIdentifier("clubOpsGov.case.\(row.id)")
            }
        } header: { Text("club.gov.cases") }
        }
    }
    static func type(_ kind: ClubOpsCaseKind) -> Text {
        switch kind {
        case .appeal: return ClubOpsGovernanceCopy.text("clubOpsGov.caseType.APPEAL")
        case .report(let target): return ClubOpsGovernanceCopy.text("clubOpsGov.caseType.REPORT_" + target)
        }
    }
}

/// Display-only names for the roles page. A failed or stale member read only loses names.
@MainActor final class ClubOpsRoleMemberNames: ObservableObject {
    @Published private(set) var snapshot: ClubGovernanceSnapshot?
    private var context: ClubGovernanceReadContext?
    func accepted(_ expected: ClubGovernanceReadContext) -> ClubGovernanceSnapshot? { context == expected ? snapshot : nil }
    func load(context expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess) async {
        guard context != expected || snapshot == nil else { return }
        context = expected; snapshot = nil
        guard expected.identity?.isSignedIn == true, expected.identity == access.identity, access.isConfigured else { return }
        func check() throws {
            guard context == expected, expected.identity == access.identity,
                  expected.authorizationGeneration == access.authorizationGeneration, !Task.isCancelled else { throw CancellationError() }
        }
        guard let result = try? await access.read(.members, scope: expected.scope, options: [:], check: check),
              (try? check()) != nil, result.operation == .members, result.scope == expected.scope else { return }
        snapshot = result
    }
}

struct ClubOpsRoleSection: View {
    let roles: ClubGovernanceSnapshot
    let context: ClubGovernanceReadContext
    let access: any ClubGovernanceAccess
    let assign: AnyView
    let revoke: (ClubOpsRoleAssignmentRow) -> AnyView
    @StateObject private var names = ClubOpsRoleMemberNames()
    var body: some View {
        Group {
            if let roster = try? ClubOpsRoleRoster(roles: roles, members: names.accepted(context)) {
                content(roster)
            } else { Text("club.gov.malformed").accessibilityIdentifier("clubOpsGov.roles.malformed") }
        }
        .task(id: context) { await names.load(context: context, access: access) }
    }
    /// `{角色说明}[ · 至 MM-DD]`; the summary keys are the existing role-picker copy.
    static func summary(_ row: ClubOpsRoleAssignmentRow) -> Text {
        let summary = Text(LocalizedStringKey(row.summaryKey))
        guard let day = row.expiresMonthDay else { return summary }
        return summary + Text("clubOpsGov.roles.until \(day)", tableName: "ClubOpsGovernance")
    }
    /// mp-club r3 (MP roles wxml:19, js:364): with no member to delegate to and nothing delegated, the page is 暂无成员.
    @ViewBuilder private func content(_ roster: ClubOpsRoleRoster) -> some View {
        if roster.delegableMemberCount == 0 && roster.assignments.isEmpty {
            Section {
                ContentUnavailableView {
                    Label { Text("club.gov.roles.noMembers") } icon: { Image(systemName: "person.3") }
                }
                .accessibilityIdentifier("clubOpsGov.roles.empty")
            }
        } else {
            rosterContent(roster)
        }
    }
    @ViewBuilder private func rosterContent(_ roster: ClubOpsRoleRoster) -> some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    if let owner = roster.ownerName { Text(verbatim: owner).font(.headline) }
                    else { Text("club.gov.role.CLUB_OWNER").font(.headline) }
                }
                Spacer()
                ClubOpsTag(label: Text("club.gov.role.CLUB_OWNER"))
            }.accessibilityIdentifier("clubOpsGov.roles.owner")
            ForEach(roster.assignments) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        // Round 2 MP asset: roles wxml:87 `item.avatar || d_profile.png` (the read has no avatar yet).
                        ClubMPAvatar(url: nil, name: row.memberName ?? "", size: .sm)
                        ClubOpsGovernanceCopy.member(row.memberName, id: row.targetMemberID).font(.headline)
                        Spacer()
                        ClubOpsTag(label: row.roleName.map { Text(verbatim: $0) } ?? ClubOpsGovernanceCopy.text("clubOpsGov.roles.roleFallback"))
                    }
                    Self.summary(row).font(.footnote).foregroundStyle(.secondary)
                    revoke(row).accessibilityLabel(Text("club.gov.a11y.revoke \(row.memberName ?? "#\(row.targetMemberID)")"))
                }.accessibilityIdentifier("clubOpsGov.roles.assignment.\(row.id)")
            }
        } header: { Text("club.gov.assignments") }
        // mp-club r3 (MP roles wxml:23-45): the owner row is name + 主理人 tag only, and the list has no footer line.
        Section {
            if roster.delegableMemberCount == 0 {
                // CLB-roles-10: MP roles empty copy 暂无成员.
                Text("club.gov.roles.noMembers").font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("clubOpsGov.roles.empty")
            } else {
                assign
            }
        } header: { ClubOpsGovernanceCopy.text("clubOpsGov.roles.assign.title") }
    }
}

/// Page-specific denial copy shown beside the generic failure; `.access` offers the own-case read a banned member keeps.
struct ClubOpsGovernanceDeniedNote: View {
    let operation: ClubGovernanceRead
    let cases: AnyView?
    @Environment(\.dismiss) private var dismiss
    /// Reads whose denial is this page's own note, so the generic 当前权限不允许访问此内容 is not stacked on it (X3).
    static func covers(_ operation: ClubGovernanceRead) -> Bool {
        switch operation {
        case .bans, .members, .roles, .audienceCounts: return true
        default: return false
        }
    }
    var body: some View {
        switch operation {
        case .bans, .members:
            // cursor/core-club hand-off (CLB-r7-A-07 / C-02): member governance is owner or co-owner only; the body is
            // `ClubGovernancePermissions.memberGovernanceDenial` (仅主理人与联合主理人可进行成员治理), catalogued.
            note("clubOpsGov.denied.title", Text("club.memberGovernance.denied"))
        case .roles:
            note("clubOpsGov.roles.denied.title", ClubOpsGovernanceCopy.text("clubOpsGov.roles.denied.body"))
        case .audienceCounts:
            Section { ClubOpsNotifyDeniedText() }
        case .access:
            if let cases { Section { ClubOpsGovernanceCopy.text("clubOpsGov.appeal.entry").font(.footnote); cases } }
        default: EmptyView()
        }
    }
    private func note(_ title: String, _ message: Text) -> some View {
        Section {
            ContentUnavailableView {
                Label { ClubOpsGovernanceCopy.text(title) } icon: { Image(systemName: "lock") }
            } description: {
                message
            } actions: {
                // CLB-governance-08 / CLB-roles-06 (parity r2): the MP denial offers 返回 (cta="返回").
                Button { dismiss() } label: { ClubOpsGovernanceCopy.text("clubOpsGov.back") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("clubOpsGov.denied.back")
            }
            .accessibilityIdentifier("clubOpsGov.denied." + operation.rawValue)
        }
    }
}

/// Copy that frames the existing review form; it never changes fields, anchors or gates.
struct ClubOpsGovernanceFormNotes: View {
    let operation: ClubGovernanceMutation
    let seed: [String: ClubGovernanceValue]
    static func applies(_ operation: ClubGovernanceMutation) -> Bool { [.ban, .unban, .transferOwner, .report, .appeal, .revokeRole].contains(operation) }
    var body: some View {
        let nickname = seed["targetNickname"]?.string
        switch operation {
        case .ban:
            if let nickname { Text("clubOpsGov.ban.title \(nickname)", tableName: "ClubOpsGovernance").font(.headline) }
            ClubOpsGovernanceCopy.text("clubOpsGov.ban.consequence")
            ClubOpsGovernanceCopy.text("clubOpsGov.ban.reasonHint").font(.footnote).foregroundStyle(.secondary)
        case .unban:
            ClubOpsGovernanceCopy.text("clubOpsGov.unban.reasonHint").font(.footnote).foregroundStyle(.secondary)
        case .transferOwner:
            if let nickname { Text("clubOpsGov.transfer.title \(nickname)", tableName: "ClubOpsGovernance").font(.headline) }
            ClubOpsGovernanceCopy.text("clubOpsGov.transfer.hint")
            ClubOpsGovernanceCopy.text("clubOpsGov.transfer.reasonHint").font(.footnote).foregroundStyle(.secondary)
        case .report:
            // Mini 举报目标 card: type plus the optional entry-supplied name, never an internal id.
            LabeledContent {
                if let name = ClubGovernanceReportPort.quotedName(seed["targetName"]?.string) {
                    Text(verbatim: name)
                }
            } label: {
                ClubOpsGovernanceCopy.text("clubOpsGov.report.targetType." + ClubGovernanceReportPort.typeKey(seed["targetType"]?.string))
            }.accessibilityIdentifier("clubOpsGov.report.target")
            ClubOpsGovernanceCopy.text("clubOpsGov.report.note")
        case .appeal:
            ClubOpsGovernanceCopy.text("clubOpsGov.appeal.note")
        case .revokeRole:
            // CLB-roles-07: the three consequences live in the one confirm sheet (`ClubGovernanceConsequence.revokeRole`);
            // the form keeps only the title and the one-line effect.
            if let role = seed["roleName"]?.string { Text("clubOpsGov.roles.revoke.title \(role)", tableName: "ClubOpsGovernance").font(.headline) }
            ClubOpsGovernanceCopy.text("clubOpsGov.roles.revoke.body")
        default: EmptyView()
        }
    }
}

/// 7/30/90-day ban term. The draft turns the selection into an absolute epoch only when a review is prepared.
struct ClubOpsBanDurationPicker: View {
    @Binding var days: String
    var body: some View {
        Picker(selection: $days) {
            ForEach(ClubGovernanceFormDraft.banDayChoices, id: \.self) { value in
                Text("clubOpsGov.days \(value)", tableName: "ClubOpsGovernance").tag(String(value))
            }
        } label: { ClubOpsGovernanceCopy.text("clubOpsGov.duration") }
        .accessibilityIdentifier("club.gov.input.banDays")
    }
}

struct ClubOpsBanExpiryReview: View {
    let fields: [String: ClubGovernanceValue]
    var body: some View {
        if let days = fields["durationDays"]?.int, ClubGovernanceFormDraft.banDayChoices.contains(days) {
            LabeledContent {
                Text("clubOpsGov.days \(days)", tableName: "ClubOpsGovernance")
            } label: { ClubOpsGovernanceCopy.text("clubOpsGov.duration") }
            .accessibilityIdentifier("clubOpsGov.review.expiry")
        }
    }
}

/// Shown only inside the acknowledged receipt section, i.e. after a confirmed server acknowledgement.
struct ClubOpsGovernanceSuccess: View {
    let operation: ClubGovernanceMutation
    var body: some View {
        if let key = Self.key(operation) {
            ClubOpsGovernanceCopy.text(key).font(.headline).accessibilityIdentifier("clubOpsGov.success")
        }
    }
    static func key(_ operation: ClubGovernanceMutation) -> String? {
        switch operation {
        case .ban: return "clubOpsGov.success.ban"
        case .unban: return "clubOpsGov.success.unban"
        case .transferOwner: return "clubOpsGov.success.transfer"
        case .dissolve: return "clubOpsGov.success.dissolve"
        case .report, .appeal: return "clubOpsGov.success.case"
        case .assignRole: return "clubOpsGov.roles.success.assign"
        case .revokeRole: return "clubOpsGov.roles.success.revoke"
        default: return nil
        }
    }
}
