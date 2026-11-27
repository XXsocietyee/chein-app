import SwiftUI
import UIKit

struct ClubEnrollmentProfileContext {
    let reader: any SocialAccountReading
    let squareReader: any SquareReading
    var actions: SocialActionCoordinator? = nil
}
private struct ClubEnrollmentProfileKey: EnvironmentKey {
    static let defaultValue: ClubEnrollmentProfileContext? = nil
}
extension EnvironmentValues {
    var clubEnrollmentProfile: ClubEnrollmentProfileContext? {
        get { self[ClubEnrollmentProfileKey.self] }
        set { self[ClubEnrollmentProfileKey.self] = newValue }
    }
}

/// Replacing a reader or its authorization creates a new page-scoped reader.
@MainActor struct ClubEnrollmentHostContext: @preconcurrency Equatable, @preconcurrency Hashable {
    let clubID: Int
    let focusTopicID: Int?
    let identity: ClubReadIdentity?
    let accessID: ObjectIdentifier
    let authorization: UUID?
    let namespace: String
    let realm: String
    let configured: Bool
    let profileID: ObjectIdentifier?
    let profileIdentity: SocialAccountIdentity?
    let profileRevision: UInt64?
    let profileConfigured: Bool
    let squareID: ObjectIdentifier?
    let squareScope: UUID?
    init(clubID: Int, focusTopicID: Int?, identity: ClubReadIdentity?, access: any ClubGovernanceAccess,
         profile: ClubEnrollmentProfileContext?) {
        self.clubID = clubID; self.focusTopicID = focusTopicID; self.identity = identity
        accessID = ObjectIdentifier(access); authorization = access.authorizationGeneration
        namespace = access.storageNamespace; realm = access.journalRealm; configured = access.isConfigured
        profileID = profile.map { ObjectIdentifier($0.reader) }; profileIdentity = profile?.reader.identity
        profileRevision = profile?.reader.presentationRevision; profileConfigured = profile?.reader.isConfigured == true
        squareID = profile.map { ObjectIdentifier($0.squareReader) }; squareScope = profile?.squareReader.scope
    }
    var permitsProfile: Bool {
        identity?.isSignedIn == true && profileConfigured && profileID != nil && squareID != nil &&
            profileIdentity?.accountID == identity?.accountID && profileIdentity?.epoch == identity?.epoch
    }
}

@MainActor struct ClubEnrollmentView: View {
    let clubID: Int
    var focusTopicID: Int? = nil
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    @Environment(\.clubEnrollmentProfile) private var profile
    var body: some View {
        let context = ClubEnrollmentHostContext(clubID: clubID, focusTopicID: focusTopicID, identity: identity, access: access, profile: profile)
        ClubEnrollmentContent(clubID: clubID, focusTopicID: focusTopicID, identity: identity,
                              access: access, coordinator: coordinator, host: context).id(context)
    }
}

/// Club-wide roster. Financial actions are intentionally absent from roster rows.
@MainActor private struct ClubEnrollmentContent: View {
    let clubID: Int
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    @Environment(\.clubEnrollmentProfile) private var profile
    @State private var reader: ClubEnrollmentReader
    let host: ClubEnrollmentHostContext
    let focusTopicID: Int?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .headline) private var coverSide: CGFloat = 72  // CLB-enroll-06: MP cover 144 rpx
    @StateObject private var navigation = ClubEnrollmentNavigation()
    private var liveHost: ClubEnrollmentHostContext {
        .init(clubID: clubID, focusTopicID: focusTopicID, identity: identity, access: access, profile: profile)
    }
    init(clubID: Int, focusTopicID: Int?, identity: ClubReadIdentity?, access: any ClubGovernanceAccess, coordinator: ClubGovernanceCoordinator, host: ClubEnrollmentHostContext) {
        self.clubID = clubID; self.identity = identity; self.access = access; self.coordinator = coordinator
        self.host = host; self.focusTopicID = focusTopicID
        _reader = State(initialValue: ClubEnrollmentReader(clubID: clubID, focusTopicID: focusTopicID, access: access))
    }
    var body: some View {
        List {
            // mp-club r3 (MP enroll wxml:17-20): the sub line comes first, then 正在更新报名名册…, then the stale error.
            if host == liveHost, scenePhase == .active, reader.isCurrentAccess, identity == reader.identity, identity == access.identity, reader.hasLoaded {
                // Mini-program sub line: 「俱乐部名 · N 个团」 (俱乐部名 falls back to 我的俱乐部); MP enroll wxml:17 has no escrow note.
                Section {
                    subLine.accessibilityIdentifier("club.enroll.headerLine")
                }
            }
            if reader.loading, reader.hasLoaded {
                // CLB-r9-enroll-01 (MP enroll wxml:18): a refresh over a loaded roster says 正在更新报名名册… and keeps it.
                HStack {
                    ProgressView()
                    Text("club.enroll.refreshing").font(.footnote).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("club.enroll.refreshing")
            } else if reader.loading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("club.enroll.loading")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("club.enroll.loading")
            }
            if let issue = reader.failure {
                Section {
                    if reader.hasLoaded {
                        Label {
                            Text("club.enroll.stale")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                        .accessibilityIdentifier("club.enroll.stale")
                    }
                    // Core's denied title is a Chinese literal; show the localized equivalent.
                    if ClubEnrollmentReader.failureTitle(for: issue) != nil {
                        Text("club.enroll.denied")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("club.enroll.deniedTitle")
                    }
                    Label {
                        Text(LocalizedStringKey(issue.localizationKey))
                    } icon: {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                    }
                    if let message = issue.message {
                        Text(verbatim: message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // A Settings-style row action.
                    Button {
                        Task { await refreshVisible() }
                    } label: {
                        // mp-club r3 (MP enroll wxml:20): over a loaded roster the inline error's action is 重试更新.
                        Label(reader.hasLoaded ? "club.enroll.retryUpdate" : "club.enroll.retry", systemImage: "arrow.clockwise")
                    }
                    .disabled(reader.loading)
                }
            }
            if host == liveHost, scenePhase == .active, reader.isCurrentAccess, identity == reader.identity, identity == access.identity, reader.hasLoaded {
                if reader.teams.isEmpty {
                    ContentUnavailableView {
                        Label { Text("club.enroll.emptyTeams").accessibilityIdentifier("club.enroll.emptyTeams") } icon: { Image(systemName: "person.3") }
                    }
                }
                ForEach(reader.teams) { team in
                    Section {
                        Button { Task { if canRead { await reader.toggle(topicID: team.id) } } } label: {
                            teamHeader(team)
                        }
                        .disabled(reader.loading)
                        .accessibilityValue(Text(reader.expanded.contains(team.id) ? "club.enroll.expanded" : "club.enroll.collapsed"))
                        .accessibilityIdentifier("club.enroll.team.\(team.id)")
                        if reader.expanded.contains(team.id) { detail(team) }
                    }
                }
            }
        }
        // The enrollment UI test addresses navigationBars["Enrollment roster"].
        // That bar title is the one screen title; a second hero would duplicate it.
        .navigationTitle("club.enroll.title").navigationBarTitleDisplayMode(.inline)
        .background {
            if let attachment = navigation.attachment {
                ClubEnrollmentLifetime {
                    if navigation.depart(attachment) { reader.invalidatePresentation() }
                }.frame(width: 0, height: 0).id(attachment)
            }
            if let item = navigation.item {
                ClubEnrollmentDestinationOwner(item: item, owner: navigation,
                    source: { currentSource(item.source) }, didClose: { closed(item) }) {
                        destination(item)
                    }.id(item.id)
            }
        }
        .onChange(of: liveHost) { _, _ in
            if let attachment = navigation.attachment { _ = navigation.depart(attachment) }
            reader.invalidatePresentation()
        }
        .onChange(of: reader.presentationRevision) { _, _ in navigation.retire() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { navigation.retire(); navigation.pauseReturnRead(); reader.invalidatePresentation() }
            else { Task { await activateAndReturn() } }
        }
        .onAppear { navigation.appear(); Task { await activateAndReturn() } }
        .accessibilityIdentifier("club.enroll.screen")
        .refreshable { await refreshVisible() }
        .task(id: host) { await activateAndReturn() }
        .onDisappear { reader.suspend() }
        .onDisappear { navigation.hide(); navigation.pauseReturnRead() }
    }
    private var canRead: Bool { host == liveHost && navigation.visible && scenePhase == .active }
    @MainActor private func refreshVisible() async {
        guard canRead, !Task.isCancelled else { return }
        if navigation.hasPendingReturn { await readReturnedRoster() }
        else { await reader.refresh() }
    }
    @MainActor private func activateAndReturn() async {
        guard host == liveHost, navigation.visible, scenePhase == .active else { return }
        await reader.activate(identity: identity)
        guard host == liveHost, navigation.visible, scenePhase == .active, !Task.isCancelled else { return }
        await readReturnedRoster()
    }
    @MainActor private func readReturnedRoster() async {
        await navigation.refreshReturn(using: reader, active: { scenePhase == .active }, isCurrent: { host == liveHost })
    }
    private func source(topicID: Int, registrant: ClubEnrollmentRegistrant) -> ClubEnrollmentNavigation.Source? {
        guard host == liveHost else { return nil }
        return .init(host: host, reader: reader, access: access, topicID: topicID, registrant: registrant)
    }
    private func currentSource(_ expected: ClubEnrollmentNavigation.Source) -> ClubEnrollmentNavigation.Source? {
        source(topicID: expected.topicID, registrant: expected.registrant)
    }
    private func open(_ kind: ClubEnrollmentNavigation.Kind, source: ClubEnrollmentNavigation.Source?) {
        navigation.open(kind, source: source, current: source.flatMap { currentSource($0) }, active: scenePhase == .active)
    }
    private func closed(_ item: ClubEnrollmentNavigation.Item) {
        guard let kind = navigation.closed(item, source: currentSource(item.source)) else { return }
        if kind == .checkin { Task { await activateAndReturn() } }
    }
    @ViewBuilder private func destination(_ item: ClubEnrollmentNavigation.Item) -> some View {
        if navigation.current(item, source: currentSource(item.source)), scenePhase == .active {
            switch item.kind {
            case .profile:
                if let profile, let memberID = item.source.registrant.memberID {
                    SocialPublicProfileView(memberID: memberID, reader: profile.reader,
                        squareReader: profile.squareReader, actions: profile.actions,
                        isCurrent: { scenePhase == .active && navigation.current(item, source: currentSource(item.source)) })
                }
            case .checkin:
                ClubGovernanceReadView(operation: .checkin,
                    scope: .init(clubID: clubID, registrationID: item.source.registrant.id),
                    identity: identity, access: access, coordinator: coordinator)
            }
        } else { Color.clear }
    }
    private func teamHeader(_ team: ClubEnrollmentTeam) -> some View {
        let expanded = reader.expanded.contains(team.id)
        let text = VStack(alignment: .leading, spacing: CYSpacing.xs) {
            title(team.name, fallback: "club.enroll.unnamedTeam")
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                signupLine(team)
                VStack(alignment: .leading, spacing: CYSpacing.xs) { signupLine(team) }
            }
        }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    cover(team)
                    text
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))  // CLB-enroll-06
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            } else {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    cover(team)
                    text
                    Spacer(minLength: CYSpacing.sm)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))  // CLB-enroll-06
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    private func cover(_ team: ClubEnrollmentTeam) -> some View {
        Group {
            if let image = team.image { SquareImage(source: image) }
            // Round 2 MP asset: `team.imgUrl || '/images/route_city_cover.png'` (enroll wxml:37).
            else { MPAsset.BannerCover.routeCityCover.resizable().scaledToFill() }
        }
        .frame(width: coverSide, height: coverSide)
        .clipped()
        .accessibilityHidden(true)
    }
    private func signupLine(_ team: ClubEnrollmentTeam) -> some View {
        HStack(spacing: CYSpacing.xs) {
            // r4 · MC-25 / handbook dates: 「11月15日 周六」, not 2026-11-15 (unparseable source text stays as sent).
            title(team.date.map { ClubR4Date.day($0, locale: locale) }, fallback: "club.enroll.dateUnknown")
            Text(verbatim: "·").accessibilityHidden(true)
            // Source team-meta: 已报名 N 人, or 已报名 — when the count is unknown.
            if let count = team.signupCount, count >= 0 { Text("u9cde.clubEnroll.signups \(count)").monospacedDigit() }
            else { Text("club.enroll.signups"); Text("club.enroll.unknown") }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func detail(_ team: ClubEnrollmentTeam) -> some View {
        if reader.detailLoading.contains(team.id) {
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text("club.enroll.detailLoading")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let issue = reader.detailFailures[team.id] {
            if reader.rosters[team.id] != nil {
                Text("club.enroll.stale").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(LocalizedStringKey(issue.localizationKey))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { if canRead { await reader.loadDetail(topicID: team.id) } }
            } label: {
                Label("club.enroll.retry", systemImage: "arrow.clockwise")
            }
            .disabled(reader.detailLoading.contains(team.id))
            .accessibilityIdentifier("club.enroll.retry.\(team.id)")
        }
        if let roster = reader.rosters[team.id] {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                fact("club.enroll.paid", value: Text(roster.paidCount, format: .number))
                    .accessibilityIdentifier("club.enroll.paidRefundSummary.\(team.id)")
                fact("club.enroll.refundable", value: number(roster.refundableCount))
                if let deadline = roster.deadline { fact("club.enroll.deadline", value: Text(verbatim: deadline)) }
                // CLB-enroll-05: the MP removed the 团状态 row (enroll/index.js teamStatusText is gone).
            }
            .accessibilityIdentifier("club.enroll.summary.\(team.id)")
            // CLB-enroll-01: MP C-13 per-session money, matched to the books to the cent (owner only).
            if !roster.sessionMoney.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(roster.sessionMoney) { money in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack(spacing: CYSpacing.xs) {
                                if let label = money.label { Text(verbatim: label).lineLimit(1) } else { Text("club.enroll.money.session") }
                                if money.cancelled { Text("club.enroll.money.cancelled").font(.caption).foregroundStyle(.secondary) }
                            }
                            Text("club.enroll.money.line \(ClubMoneyText.twoDecimals(money.paidText)) \(ClubMoneyText.twoDecimals(money.refundedText)) \(ClubMoneyText.twoDecimals(money.netText))")
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("club.enroll.money.\(money.id)")
                    }
                }
            }
            if roster.tickets.isEmpty {
                Text("club.enroll.emptyTickets").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            // MP enroll js:421-422 (hideEmpty): once any ticket has signups, tickets with none are not listed.
            ForEach(visibleTickets(roster.tickets)) { ticket in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    // Mini-program ticket row: name left, 「已报名 / 上限」 as one right-aligned fraction.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            ticketTitle(ticket)
                            Spacer(minLength: CYSpacing.sm)
                            capacity(ticket)
                        }
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            ticketTitle(ticket)
                            capacity(ticket)
                        }
                    }
                    if ticket.registrants.isEmpty {
                        Text("club.enroll.emptyRegistrants").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(ticket.registrants) { registrant in row(registrant, topicID: team.id) }
                }
                .padding(.vertical, CYSpacing.xs)
            }
        }
    }
    private func visibleTickets(_ tickets: [ClubEnrollmentTicket]) -> [ClubEnrollmentTicket] {
        let anySignup = tickets.contains { !$0.registrants.isEmpty }
        return anySignup ? tickets.filter { !$0.registrants.isEmpty } : tickets
    }
    private func ticketTitle(_ ticket: ClubEnrollmentTicket) -> some View {
        title(ticket.name, fallback: "club.enroll.unnamedTicket")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("club.enroll.ticket.\(ticket.id)")
    }
    /// CLB-r8-enroll-01 (fix-r8-club): MP enroll wxml:70 shows 「n / 上限」 only for a positive totalInventory;
    /// 0 or nil reads 「n 人」.
    private func capacity(_ ticket: ClubEnrollmentTicket) -> some View {
        HStack(spacing: 2) {
            Text(ticket.registrants.count, format: .number)
            if let capacity = ticket.capacity, capacity > 0 {
                Text(verbatim: "/")
                Text(capacity, format: .number)
            } else {
                Text("club.enroll.registrants")
            }
        }
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("club.enroll.capacity.\(ticket.id)")
    }
    @ViewBuilder private func teamStatusText(_ status: Int) -> some View {
        switch status {
        case 0: Text("club.enroll.teamStatus.0")
        case 1: Text("club.enroll.teamStatus.1")
        case 2: Text("club.enroll.teamStatus.2")
        default: Text(verbatim: "—")
        }
    }
    private func fact(_ title: LocalizedStringKey, value: some View) -> some View {
        ViewThatFits(in: .horizontal) {
            LabeledContent(title) { value }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(title).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                value
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private func row(_ registrant: ClubEnrollmentRegistrant, topicID: Int) -> some View {
        let source = source(topicID: topicID, registrant: registrant)
        // Mini-program registrant row: avatar + name (opens profile) left, check-in status (opens detail) right.
        let wide = !dynamicTypeSize.isAccessibilitySize
        Group {
            if wide {
                HStack(spacing: CYSpacing.md) {
                    profileControl(registrant, source: source)
                    Spacer(minLength: CYSpacing.sm)
                    checkinControl(registrant, source: source)
                }
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    profileControl(registrant, source: source)
                    checkinControl(registrant, source: source)
                }
            }
        }
        .disabled(source == nil || navigation.item != nil)
    }
    /// CLB-enroll-02 (fix-r8-club): MP enroll wxml:75 `reg-l bindtap="goCheckinDetail"`: the person opens 核销详情
    /// (报名与退款), the same destination as the status chip; the roster no longer opens the public profile.
    @ViewBuilder private func profileControl(_ registrant: ClubEnrollmentRegistrant, source: ClubEnrollmentNavigation.Source?) -> some View {
        Button { open(.checkin, source: source) } label: { attendee(registrant) }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("club.enroll.profile.\(registrant.id)")
    }
    private func checkinControl(_ registrant: ClubEnrollmentRegistrant, source: ClubEnrollmentNavigation.Source?) -> some View {
        Button { open(.checkin, source: source) } label: { checkinChip(registrant) }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("club.enroll.checkin.\(registrant.id)")
    }
    private func checkinChip(_ registrant: ClubEnrollmentRegistrant) -> some View {
        let key: LocalizedStringKey
        let tint: Color
        let symbol: String
        switch registrant.checkin {
        case .done: key = "club.enroll.checkin.done"; tint = .green; symbol = "checkmark.circle"
        case .pending: key = "club.enroll.checkin.pending"; tint = .orange; symbol = "ticket"
        case .unknown: key = "club.enroll.checkin.unknown"; tint = .secondary; symbol = "questionmark.circle"
        }
        return Label(key, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(tint)
    }
    private func attendee(_ value: ClubEnrollmentRegistrant) -> some View {
        HStack(spacing: CYSpacing.sm) {
            // Round 2 MP asset: `r.avatar || '/images/d_profile.png'` (enroll wxml:76).
            Group {
                if let avatar = value.avatar { SquareImage(source: avatar) }
                else { MPAsset.AvatarDefault.dProfile.resizable().scaledToFill() }
            }
            .frame(width: coverSide * 0.64, height: coverSide * 0.64)
            .clipShape(Circle())
            .accessibilityHidden(true)
            title(value.nickname, fallback: "club.enroll.player")
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    /// The team total is a real count: 0 stays 0.
    @ViewBuilder private var subLine: some View {
        let name = reader.clubName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Group {
            if name.isEmpty { Text("u9cde.clubEnroll.subLineMine \(reader.teams.count)") }
            else { Text("u9cde.clubEnroll.subLine \(name) \(reader.teams.count)") }
        }
        .font(.subheadline).monospacedDigit()
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func title(_ text: String?, fallback: LocalizedStringKey) -> some View {
        if let text { Text(verbatim: text) } else { Text(fallback) }
    }
    /// Nil is the catalog em dash. A real count, including 0, keeps its digits.
    @ViewBuilder private func number(_ count: Int?) -> some View {
        if let count, count >= 0 { Text(count, format: .number).monospacedDigit() } else { Text("club.enroll.unknown") }
    }
}

@MainActor final class ClubEnrollmentNavigation: ObservableObject {
    enum Kind: Equatable { case profile, checkin }
    struct Source: Equatable {
        let host: ClubEnrollmentHostContext
        let revision: UInt64
        let topicID: Int
        let roster: ClubEnrollmentRoster
        let registrant: ClubEnrollmentRegistrant
        @MainActor init?(host: ClubEnrollmentHostContext, reader: ClubEnrollmentReader, access: any ClubGovernanceAccess,
                         topicID: Int, registrant: ClubEnrollmentRegistrant) {
            guard host.configured, host.identity?.isSignedIn == true,
                  reader.usesAccess(access), host.accessID == ObjectIdentifier(access),
                  host.identity == access.identity, host.authorization == access.authorizationGeneration,
                  host.namespace == access.storageNamespace, host.realm == access.journalRealm,
                  host.identity == reader.identity, host.clubID == reader.clubID, reader.isCurrentAccess,
                  reader.hasLoaded, !reader.loading, reader.failure == nil,
                  reader.teams.filter({ $0.id == topicID }).count == 1, reader.expanded.contains(topicID),
                  !reader.detailLoading.contains(topicID), reader.detailFailures[topicID] == nil,
                  let roster = reader.rosters[topicID], roster.clubID == host.clubID, roster.topicID == topicID,
                  roster.tickets.flatMap(\.registrants).filter({ $0.id == registrant.id }).count == 1,
                  roster.tickets.flatMap(\.registrants).contains(registrant) else { return nil }
            self.host = host; revision = reader.presentationRevision; self.topicID = topicID
            self.roster = roster; self.registrant = registrant
        }
    }
    struct Item: Identifiable {
        let id = UUID()
        let attachment: UUID
        let source: Source
        let kind: Kind
    }
    struct ReturnRead: Equatable {
        let id = UUID()
        let request: UUID
        let attachment: UUID
    }
    @Published private(set) var pendingReturn: UUID?
    @Published private(set) var returnRead: ReturnRead?
    var hasPendingReturn: Bool { pendingReturn != nil }
    @Published private(set) var item: Item?
    @Published private(set) var isPresented = false
    @Published private(set) var visible = false
    @Published private(set) var attachment: UUID?
    func appear() { visible = true; if attachment == nil { attachment = UUID() } }
    func hide() { visible = false }
    @discardableResult func depart(_ expected: UUID) -> Bool {
        guard attachment == expected else { return false }
        visible = false; attachment = nil; pendingReturn = nil; returnRead = nil; retire(); return true
    }
    func open(_ kind: Kind, source: Source?, current: Source?, active: Bool) {
        guard visible, active, let attachment, item == nil, let source, source == current else { return }
        if kind == .profile { guard source.host.permitsProfile, (source.registrant.memberID ?? 0) > 0 else { return } }
        item = .init(attachment: attachment, source: source, kind: kind); isPresented = true
    }
    func current(_ expected: Item, source: Source?) -> Bool {
        item?.id == expected.id && attachment == expected.attachment && expected.source == source
    }
    func binding(_ expected: Item, source: @escaping () -> Source?) -> Binding<Bool> {
        Binding(get: { self.isPresented && self.current(expected, source: source()) }, set: { shown in
            guard !shown, self.current(expected, source: source()) else { return }
            self.isPresented = false
        })
    }
    func closed(_ expected: Item, source: Source?) -> Kind? {
        guard !isPresented, current(expected, source: source) else { return nil }
        let kind = expected.kind; retire()
        if kind == .checkin { pendingReturn = UUID() }
        return kind
    }
    func beginReturnRead(active: Bool) -> ReturnRead? {
        guard visible, active, let attachment, let request = pendingReturn, returnRead == nil else { return nil }
        let ticket = ReturnRead(request: request, attachment: attachment); returnRead = ticket; return ticket
    }
    func finishReturnRead(_ ticket: ReturnRead, completed: Bool) {
        guard returnRead == ticket, attachment == ticket.attachment, pendingReturn == ticket.request else { return }
        returnRead = nil
        if completed { pendingReturn = nil }
    }
    func pauseReturnRead() { returnRead = nil }
    func refreshReturn(using reader: ClubEnrollmentReader, active: () -> Bool, isCurrent: () -> Bool) async {
        guard visible, active(), isCurrent(), !Task.isCancelled, let ticket = beginReturnRead(active: true) else { return }
        let completed = reader.completedRefreshRevision
        await reader.refresh()
        finishReturnRead(ticket, completed: visible && active() && isCurrent() && !Task.isCancelled && reader.completedRefreshRevision > completed)
    }
    func retire(_ expected: Item) { if item?.id == expected.id { retire() } }
    func retire() { item = nil; isPresented = false }
}

@MainActor private struct ClubEnrollmentDestinationOwner<Content: View>: View {
    let item: ClubEnrollmentNavigation.Item
    @ObservedObject var owner: ClubEnrollmentNavigation
    let source: () -> ClubEnrollmentNavigation.Source?
    let didClose: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onChange(of: owner.isPresented) { _, shown in if !shown { didClose() } }
            .navigationDestination(isPresented: owner.binding(item, source: source)) {
                content().id(item.id)
                    .onChange(of: owner.current(item, source: source()), initial: true) { _, current in
                        if !current { owner.retire(item) }
                    }
                    .onDisappear { didClose() }
            }
    }
}

@MainActor private struct ClubEnrollmentLifetime: UIViewControllerRepresentable {
    let leave: () -> Void
    func makeUIViewController(context: Context) -> Controller { Controller(leave: leave) }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.leave = leave }
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.leave() }
    @MainActor final class Controller: UIViewController {
        var leave: () -> Void
        private var wasAttached = false
        init(leave: @escaping () -> Void) { self.leave = leave; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent != nil { wasAttached = true } else if wasAttached { leave() }
        }
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            var current: UIViewController? = self
            while let controller = current {
                if controller.isBeingDismissed || controller.isMovingFromParent { leave(); return }
                current = controller.parent
            }
        }
    }
}
