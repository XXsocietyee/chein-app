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

private struct ClubOpsTag: View {
    let label: Text
    var isDanger: Bool = false
    var body: some View {
        label.font(CYTypography.caption.weight(.semibold))
            .foregroundStyle(isDanger ? CYColor.dangerText : CYColor.textSecondary)
            .padding(.horizontal, CYSpacing.xs).padding(.vertical, 3)
            .background(isDanger ? CYColor.dangerSoft : CYColor.bgElevated, in: Capsule())
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
            if let text = countText { Text(verbatim: text).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit() }
            if list.rows.isEmpty {
                ClubOpsGovernanceCopy.text("clubOpsGov.bans.empty").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("clubOpsGov.bans.empty")
            }
            ForEach(list.rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("clubOpsGov.banTarget \(ClubOpsGovernanceCopy.member(row.nickname, id: row.targetMemberID))", tableName: "ClubOpsGovernance").font(CYTypography.cardTitle)
                        Spacer()
                        ClubOpsTag(label: ClubOpsGovernanceCopy.text("clubOpsGov.banStatus." + row.status.rawValue), isDanger: row.status == .active)
                    }
                    ClubOpsGovernanceCopy.banLine(source: row.source, bannedAt: row.bannedAt, expiry: row.expiry, platformOnly: row.platformOnly)
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    if let note = row.unbanReason {
                        Text("clubOpsGov.unbanNote \(note)", tableName: "ClubOpsGovernance").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    if row.unbanSeed != nil { unban(row) }
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
                Text(verbatim: text).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit().accessibilityIdentifier(ClubOpsGovernancePage.Accessibility.memberCount)
            }
            if roster.members.isEmpty {
                CYEmptyState(systemImage: "person.2", "clubOpsGov.members.empty", tableName: "ClubOpsGovernance", messageIdentifier: "clubOpsGov.members.empty")
                    .listRowBackground(Color.clear)
            }
            // One row per member: name, then its actions side by side (ban, and transfer for the owner).
            ForEach(roster.members) { member in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    ClubOpsGovernanceCopy.member(member.nickname, id: member.id).font(CYTypography.cardTitle)
                    HStack(spacing: CYSpacing.sm) {
                        ban(member).foregroundStyle(CYColor.dangerText)
                        if roster.viewerIsOwner { transfer(member) }
                    }.buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false)).controlSize(.small)
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
        if list.appealMode {
            // Mini governance `mode=appeal` page title, reached by a viewer this club has banned.
            Section {
                ClubOpsGovernanceCopy.text("clubOpsGov.appeal.mode").font(CYTypography.sectionTitle)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("clubOpsGov.appeal.mode")
            }
        }
        if list.canReport, let report {
            Section {
                ClubOpsGovernanceCopy.text("clubOpsGov.report.note").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                report
            } header: { ClubOpsGovernanceCopy.text("clubOpsGov.report.title") }
        }
        switch list.appeal {
        case .none:
            Section {
                ClubOpsGovernanceCopy.text("clubOpsGov.appeal.empty").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("clubOpsGov.appeal.empty")
            } header: { ClubOpsGovernanceCopy.text("clubOpsGov.appeal.title") }
        case .ban(let ban):
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ClubOpsGovernanceCopy.text("clubOpsGov.appeal.current").font(CYTypography.cardTitle)
                    ClubOpsGovernanceCopy.banLine(source: ban.source, bannedAt: ban.bannedAt, expiry: ban.expiry).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    if let reason = ban.reason {
                        Text("clubOpsGov.banReason \(reason)", tableName: "ClubOpsGovernance").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }.accessibilityIdentifier("clubOpsGov.appeal.ban")
                ClubOpsGovernanceCopy.text("clubOpsGov.appeal.note").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                if let appeal { appeal }
            } header: { ClubOpsGovernanceCopy.text("clubOpsGov.appeal.title") }
        case .unknown: EmptyView()
        }
        Section {
            if let text = countText {
                Text(verbatim: text).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit().accessibilityIdentifier(ClubOpsGovernancePage.Accessibility.caseCount)
            }
            if list.rows.isEmpty {
                ClubOpsGovernanceCopy.text("clubOpsGov.cases.empty").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("clubOpsGov.cases.empty")
            }
            ForEach(list.rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Self.type(row.kind).font(CYTypography.cardTitle)
                        if let reason = row.reason { Text(verbatim: reason).font(CYTypography.bodyCompact) }
                        Text("clubOpsGov.submittedAt \(ClubOpsGovernanceCopy.time(row.submittedAt))", tableName: "ClubOpsGovernance").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        if let decision = row.decisionReason {
                            Text("clubOpsGov.decision \(decision)", tableName: "ClubOpsGovernance").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    Spacer()
                    ClubOpsTag(label: ClubOpsGovernanceCopy.text("clubOpsGov.caseStatus." + row.status.rawValue))
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
    @ViewBuilder private func content(_ roster: ClubOpsRoleRoster) -> some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    if let owner = roster.ownerName { Text(verbatim: owner).font(CYTypography.cardTitle) }
                    else { Text("club.gov.role.CLUB_OWNER").font(CYTypography.cardTitle) }
                    ClubOpsGovernanceCopy.text("clubOpsGov.roles.ownerSummary").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                }
                Spacer()
                ClubOpsTag(label: Text("club.gov.role.CLUB_OWNER"))
            }.accessibilityIdentifier("clubOpsGov.roles.owner")
            ForEach(roster.assignments) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        ClubOpsGovernanceCopy.member(row.memberName, id: row.targetMemberID).font(CYTypography.cardTitle)
                        Spacer()
                        ClubOpsTag(label: row.roleName.map { Text(verbatim: $0) } ?? ClubOpsGovernanceCopy.text("clubOpsGov.roles.roleFallback"))
                    }
                    Self.summary(row).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    revoke(row)
                }.accessibilityIdentifier("clubOpsGov.roles.assignment.\(row.id)")
            }
        } header: { Text("club.gov.assignments") } footer: {
            // Mini-program roles page: the one consequence line under the delegation list.
            if !roster.assignments.isEmpty { ClubOpsGovernanceCopy.text("clubOpsGov.roles.footer") }
        }
        Section {
            if roster.delegableMemberCount == 0 {
                ClubOpsGovernanceCopy.text("clubOpsGov.roles.empty").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
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
    var body: some View {
        switch operation {
        case .bans, .members:
            note("clubOpsGov.denied.title", "clubOpsGov.denied.body")
        case .roles:
            note("clubOpsGov.roles.denied.title", "clubOpsGov.roles.denied.body")
        case .audienceCounts:
            Section { ClubOpsNotifyDeniedText() }
        case .access:
            if let cases { Section { ClubOpsGovernanceCopy.text("clubOpsGov.appeal.entry").font(CYTypography.meta); cases } }
        default: EmptyView()
        }
    }
    private func note(_ title: String, _ body: String) -> some View {
        Section {
            VStack(spacing: CYSpacing.sm) {
                Image(systemName: "lock")
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(CYColor.textSecondary)
                ClubOpsGovernanceCopy.text(title)
                    .font(CYTypography.cardTitle)
                ClubOpsGovernanceCopy.text(body)
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CYSpacing.md)
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
            if let nickname { Text("clubOpsGov.ban.title \(nickname)", tableName: "ClubOpsGovernance").font(CYTypography.cardTitle) }
            ClubOpsGovernanceCopy.text("clubOpsGov.ban.consequence")
            ClubOpsGovernanceCopy.text("clubOpsGov.ban.reasonHint").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        case .unban:
            ClubOpsGovernanceCopy.text("clubOpsGov.unban.reasonHint").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        case .transferOwner:
            if let nickname { Text("clubOpsGov.transfer.title \(nickname)", tableName: "ClubOpsGovernance").font(CYTypography.cardTitle) }
            ClubOpsGovernanceCopy.text("clubOpsGov.transfer.hint")
            ClubOpsGovernanceCopy.text("clubOpsGov.transfer.reasonHint").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
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
            if let role = seed["roleName"]?.string { Text("clubOpsGov.roles.revoke.title \(role)", tableName: "ClubOpsGovernance").font(CYTypography.cardTitle) }
            ClubOpsGovernanceCopy.text("clubOpsGov.roles.revoke.body")
            ForEach(["clubOpsGov.roles.revoke.consequence1", "clubOpsGov.roles.revoke.consequence2", "clubOpsGov.roles.revoke.consequence3"], id: \.self) { key in
                Label { ClubOpsGovernanceCopy.text(key).font(CYTypography.meta) } icon: { Image(systemName: "exclamationmark.triangle") }
            }
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
        if let value = fields["expiresAtEpochMs"], let text = ClubOpsGovernanceClock.minute(value) {
            LabeledContent { Text("clubOpsGov.until \(text)", tableName: "ClubOpsGovernance") } label: { ClubOpsGovernanceCopy.text("clubOpsGov.duration") }
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
        case .report, .appeal: return "clubOpsGov.success.case"
        case .assignRole: return "clubOpsGov.roles.success.assign"
        case .revokeRole: return "clubOpsGov.roles.success.revoke"
        default: return nil
        }
    }
}
