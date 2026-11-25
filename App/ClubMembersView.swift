import SwiftUI

@MainActor
struct ClubMembersView<Reader: ClubReading & ObservableObject>: View {
    let id: Int
    @ObservedObject var reader: Reader
    var profile: ClubEnrollmentProfileContext? = nil
    var governance: ClubGovernanceContext? = nil
    @Environment(\.clubEnrollmentProfile) private var inheritedProfile
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    private struct ProfileDestination: Hashable {
        let selectionID = UUID()
        let clubID: Int
        let viewerRevision: UInt64?
        let memberID: Int
        var customer = false
        let identity: ClubReadIdentity
    }
    @State private var destination: ProfileDestination?
    @State private var choice: ProfileDestination?
    @State private var choosing = false
    @State private var memberReport: ClubMemberReportTarget?
    @State private var reportDirectory: ClubMemberDirectory?
    @State private var reportReadGeneration: UInt64 = 0
    @State private var reportRefreshRevision: UInt64 = 0
    @State private var reportSourceActive = true
    private var reportContext: ClubGovernanceReadContext {
        .init(operation: .members, scope: .init(clubID: id), identity: reader.clubIdentity,
              viewerRevision: governance?.viewerRevision ?? 0, authorizationGeneration: governance?.access.authorizationGeneration,
              accessIdentity: governance.map { ObjectIdentifier($0.access) })
    }
    private func matchesGovernance(_ identity: ClubReadIdentity) -> Bool {
        identity.isSignedIn && governance?.access.identity == identity && governance?.access.isConfigured == true
    }
    private var profileContext: ClubEnrollmentProfileContext? { profile ?? inheritedProfile }
    private func matches(_ context: ClubEnrollmentProfileContext, _ identity: ClubReadIdentity) -> Bool {
        identity.isSignedIn && context.reader.identity.accountID == identity.accountID && context.reader.identity.epoch == identity.epoch
    }
    var onSignIn: (() -> Void)? = nil
    var body: some View {
        // The reader re-fetches detail before members, rather than inheriting the previous page's gate.
        ClubReadScreen(reader: reader, accessibilityPrefix: "club.members", requiresSignIn: true, refreshRevision: reportRefreshRevision,
                       onSignIn: onSignIn, load: {
                           reportReadGeneration &+= 1
                           let revision = reportReadGeneration, expected = reportContext
                           reportDirectory = nil; memberReport = nil
                           let directory = try await reader.clubMembers(id: id, isCurrent: {
                               revision == reportReadGeneration && expected == reportContext && reportSourceActive
                           })
                           guard revision == reportReadGeneration, expected == reportContext, reportSourceActive, !Task.isCancelled else { throw CancellationError() }
                           reportDirectory = directory
                           return directory
                       }) { directory in
            List {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        // CLB-detail-33 (parity r2): a sheet title is CYSheetHeader (22 pt), not a 34 pt hero; ✕ stays in the toolbar.
                        CYSheetHeader(title: Text("club.members"))
                        ClubName(value: directory.club.name)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        // verify-r1 2.6 / N-14: the role counts are the subtitle; the roster card moved to 报名名册.
                        if !directory.members.isEmpty {
                            Text(verbatim: ClubRosterCardModel.roleSummary(directory, locale: locale))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .monospacedDigit()
                                .accessibilityIdentifier("club.members.roleSummary")
                        }
                    }
                    .listRowInsets(Self.rowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                if directory.members.isEmpty {
                    CYEmptyState(
                        systemImage: "person.3",
                        directory.isReportedListUnavailable ? LocalizedStringKey("club.membersUnavailable") : LocalizedStringKey("club.emptyMembers"),
                        detail: directory.isReportedListUnavailable ? LocalizedStringKey("club.membersUnavailableHint") : LocalizedStringKey("club.emptyMembersHint"),
                        messageIdentifier: "club.members.empty",
                        kind: .generic
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        // Figma 223:3698: 邀请成员 is the first row. Clubs have no invite link yet, so it shares a
                        // text invitation (club name + how to find it in the app) through the system share sheet.
                        if directory.club.isOwner || directory.club.viewerIsAdmin {
                            ClubMemberInviteRow(clubName: directory.club.name)
                                .listRowInsets(Self.rowInsets)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        ForEach(Array(directory.members.enumerated()), id: \.offset) { _, member in
                            memberLine(member, directory: directory)
                                .listRowInsets(Self.rowInsets)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
        }
        .cyHeroScreen()
        .sheet(item: $memberReport) { target in Group {
            if let governance, currentReport(target) {
                NavigationStack { ClubMemberReportView(target: target, identity: reader.clubIdentity, governance: governance) }
            } else {
                Color.clear.onAppear { if memberReport?.id == target.id { memberReport = nil } }
            }
        }.cySheet(detents: [.large])
        }
        .onChange(of: reportContext) { _, _ in
            reportReadGeneration &+= 1; reportDirectory = nil; memberReport = nil; reportRefreshRevision &+= 1
        }
        .onAppear {
            if !reportSourceActive { reportSourceActive = true; reportRefreshRevision &+= 1 }
        }
        .onDisappear { reportSourceActive = false; reportReadGeneration &+= 1 }
        .sheet(isPresented: $choosing) {
            if let target = choice {
                let items: [CYOptionSheetItem<String>] = {
                    var list: [CYOptionSheetItem<String>] = [
                        CYOptionSheetItem(
                            id: "public",
                            title: appLocalized("social.profile", locale: locale),
                            systemImage: "person.crop.circle",
                            identifier: "club.member.choice.public"
                        )
                    ]
                    if target.viewerRevision == governance?.viewerRevision, matchesGovernance(target.identity) {
                        list.append(CYOptionSheetItem(
                            id: "customer",
                            title: appLocalized("club.gov.customer", locale: locale),
                            systemImage: "person.text.rectangle",
                            identifier: "club.member.choice.customer"
                        ))
                    }
                    return list
                }()
                CYOptionSheet(
                    title: appLocalized("club.members", locale: locale),
                    items: items,
                    onSelect: { selected in
                        choosing = false
                        select(target, customer: selected == "customer")
                    },
                    onClose: {
                        choosing = false
                        choice = nil
                    }
                )
                .cyDomainSheet(detents: [.peek, .half])
            }
        }
        .navigationDestination(item: $destination) { target in
            if target.clubID == id, target.viewerRevision == governance?.viewerRevision, target.identity == reader.clubIdentity {
                if target.customer, let governance, matchesGovernance(target.identity) {
                    // This existing reader rechecks access/me and exact member scope before exposing CRM data.
                    ClubGovernanceReadView(operation: .customer, scope: .init(clubID: target.clubID, memberID: target.memberID),
                                           identity: target.identity, access: governance.access, coordinator: governance.coordinator)
                        .environment(\.clubCustomerTopics, governance.customerTopics)
                        .id(target)
                } else if !target.customer, let profileContext, matches(profileContext, target.identity) {
                    SocialPublicProfileView(memberID: target.memberID, reader: profileContext.reader,
                                            squareReader: profileContext.squareReader, actions: profileContext.actions)
                        .id(target)
                }
            }
        }
        .onChange(of: reader.clubIdentity) { _, _ in destination = nil; choice = nil; choosing = false }
        .onChange(of: id) { _, _ in destination = nil; choice = nil; choosing = false }
        .onChange(of: governance?.viewerRevision) { _, _ in destination = nil; choice = nil; choosing = false }
    }
    @ViewBuilder private func memberLine(_ member: ClubMember, directory: ClubMemberDirectory) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                memberIdentity(member, directory: directory)
                reportButton(member, directory: directory)
            }
            .buttonStyle(.borderless)
        } else {
            HStack(alignment: .center, spacing: CYSpacing.sm) {
                memberIdentity(member, directory: directory)
                Spacer(minLength: 0)
                reportButton(member, directory: directory)
            }
            .buttonStyle(.borderless)
        }
    }
    @ViewBuilder private func memberIdentity(_ member: ClubMember, directory: ClubMemberDirectory) -> some View {
        if member.memberId > 0, let profileContext, matches(profileContext, reader.clubIdentity) {
            Button {
                let target = ProfileDestination(clubID: id, viewerRevision: governance?.viewerRevision, memberID: member.memberId, identity: reader.clubIdentity)
                if directory.club.id == id, directory.club.canGovern, matchesGovernance(target.identity) {
                    choice = target; choosing = true
                } else { destination = target }
            } label: { memberRow(member).cyPressTracking() }
            .buttonStyle(.cyPressTracked)
            .accessibilityIdentifier("club.member.\(member.memberId)")
            .accessibilityHint(Text(directory.club.canGovern && matchesGovernance(reader.clubIdentity) ? "club.members" : "social.profile"))
        } else {
            memberRow(member).accessibilityIdentifier("club.member.\(member.memberId)")
        }
    }
    @ViewBuilder private func reportButton(_ member: ClubMember, directory: ClubMemberDirectory) -> some View {
        if let governance, governance.access.isConfigured, governance.access.identity == reader.clubIdentity,
           let target = ClubMemberReportTarget(member: member, directory: directory, context: reportContext) {
            // HANDOFF-R1 MC-20: one "⋯" menu per member row (举报 · 设为管理员 · 临时封禁 · 移除, 移除 last in red).
            // Organiser actions open the member's governance page, where each command is confirmed.
            let canGovern = directory.club.canGovern && matchesGovernance(reader.clubIdentity) && member.memberId > 0
            ClubMemberActionMenu(actions: ClubMemberAction.menu(canGovern: canGovern, targetIsOwner: member.isOwner, targetIsAdmin: member.isAdmin,
                                                               canTempBan: directory.club.isOwner),
                                 memberName: target.displayName,
                                 reportIdentifier: "club.memberReport.open.\(member.memberId)") { action in
                if action == .report {
                    guard reportSourceActive, memberReport == nil, destination == nil, !choosing, choice == nil,
                          reportDirectory == directory, currentReport(target) else { return }
                    memberReport = target
                } else {
                    let governed = ProfileDestination(clubID: id, viewerRevision: governance.viewerRevision, memberID: member.memberId, identity: reader.clubIdentity)
                    choice = governed
                    select(governed, customer: true)
                }
            }
            .accessibilityHint(reportLabel(target))
            .disabled(reportDirectory != directory || !reportSourceActive || memberReport != nil || destination != nil || choosing)
        }
    }
    private func reportLabel(_ target: ClubMemberReportTarget) -> Text {
        if let name = target.displayName { return Text("club.memberReport.actionNamed \(name)") }
        return Text("club.memberReport.action")
    }
    private func currentReport(_ target: ClubMemberReportTarget) -> Bool {
        governance?.access.isConfigured == true && governance?.access.identity == reader.clubIdentity &&
        target.isCurrent(directory: reportDirectory, context: reportContext)
    }
    private func select(_ target: ProfileDestination, customer: Bool) {
        guard choice == target else { return }
        choice = nil; choosing = false
        guard target.clubID == id, target.viewerRevision == governance?.viewerRevision, target.identity == reader.clubIdentity, target.memberID > 0, id > 0 else { return }
        if customer { guard matchesGovernance(target.identity) else { return } }
        else { guard let profileContext, matches(profileContext, target.identity) else { return } }
        var selected = target; selected.customer = customer; destination = selected
    }
    private func memberRow(_ member: ClubMember) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            ClubMPAvatar(url: QuestifyCardArtwork.safeURL(member.avatar), name: member.trimmedNickname ?? "\(member.memberId)", size: .md)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let nickname = member.trimmedNickname {
                    Text(verbatim: nickname)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("club.memberNumber \(member.memberId)")
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if member.isOwner { CYStatusChip("club.role.creator", tone: .neutral, systemImage: "star") }
                else if member.isAdmin { CYStatusChip("club.role.administrator", tone: .neutral, systemImage: "shield") }
                if let level = member.displayedLevel {
                    Text("club.memberLevel \(level)")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("club.member.level.\(member.memberId)")
                }
                // verify-r1 1.5 / MC-02: 11月16日, not the server's raw wall-clock text.
                if let joined = member.displayedJoinTime.map({ ClubJoinDateDisplay.text($0, locale: locale) }) {
                    Text("club.memberJoined \(joined)")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("club.member.joined.\(member.memberId)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
    }
    private static var rowInsets: EdgeInsets { EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal) }
}


/// verify-r1 1.5 / MC-02: member rows show the join date as 11月16日, not the server's `2026-11-16 05:46:11`.
/// The server text has no time zone, so its wall-clock fields are read and printed as they are (no conversion).
enum ClubJoinDateDisplay {
    static func text(_ raw: String, locale: Locale) -> String {
        let digits = raw.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard digits.count >= 3, (1...12).contains(digits[1]), (1...31).contains(digits[2]) else { return raw }
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else { return raw }
        calendar.timeZone = utc
        guard let date = calendar.date(from: DateComponents(year: digits[0], month: digits[1], day: digits[2])) else { return raw }
        var style = Date.FormatStyle.dateTime.month().day().locale(locale)
        style.timeZone = utc
        return date.formatted(style)
    }
}

/// 邀请成员 (Figma 223:3698): a row with a plus disc that opens the system share sheet with a text invitation.
struct ClubMemberInviteRow: View {
    let clubName: String
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        ShareLink(item: String(format: OpsR3Text.string("r3club.invite.message", locale: locale), clubName)) {
            HStack(spacing: CYSpacing.md) {
                Image(systemName: "person.badge.plus")
                    .cyText(.bodyMedium)  // CLB-detail-41
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(palette.bgElevated))
                    .accessibilityHidden(true)
                OpsR3Text.text("r3club.invite.title")
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cyPressable)
        .accessibilityHint(OpsR3Text.text("r3club.invite.hint"))
        .accessibilityIdentifier("club.members.invite")
    }
}
