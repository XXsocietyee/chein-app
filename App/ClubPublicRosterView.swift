import SwiftUI

/// The public branch never constructs ClubGovernancePermissions or a member action.
/// Profiles reuse the existing public reader with chat/actions intentionally absent.
@MainActor struct ClubPublicRosterView<Reader: ClubReading & ObservableObject>: View {
    let clubID: Int
    @ObservedObject var reader: Reader
    let source: ClubPublicRosterReader?
    let profile: ClubEnrollmentProfileContext?
    let viewerRevision: UInt64
    let isLeaderboard: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var mode: ClubPublicRosterMode
    @State private var snapshot: ClubPublicRosterSnapshot?
    @State private var snapshotKey: ReadKey?
    @State private var generation: UInt64 = 0
    @State private var loading = false
    @State private var failed = false
    @State private var active = true
    @State private var profileTarget: ProfileTarget?
    private struct ReadKey: Equatable {
        let identity: ClubReadIdentity
        let clubID: Int
        let mode: ClubPublicRosterMode
        let revision: UInt64
        let approval: ClubPublicRosterApproval?
    }
    private struct ProfileTarget: Identifiable {
        let id = UUID()
        let memberID: Int
        let generation: UInt64
        let identity: ClubReadIdentity
        let profileRevision: UInt64
        let profileReader: ObjectIdentifier
        let squareReader: ObjectIdentifier
        let squareScope: UUID
    }
    init(clubID: Int, reader: Reader, source: ClubPublicRosterReader?, profile: ClubEnrollmentProfileContext?,
         viewerRevision: UInt64, leaderboard: Bool) {
        self.clubID = clubID; self.reader = reader; self.source = source; self.profile = profile
        self.viewerRevision = viewerRevision; isLeaderboard = leaderboard
        _mode = State(initialValue: leaderboard ? .composite : .members)
    }
    private var key: ReadKey { .init(identity: reader.clubIdentity, clubID: clubID, mode: mode, revision: viewerRevision, approval: source?.authorization) }
    private var accepted: ClubPublicRosterSnapshot? {
        guard active, scenePhase == .active, snapshotKey == key, let snapshot, snapshot.club.id == clubID,
              snapshot.identity == reader.clubIdentity, snapshot.mode == mode,
              source?.isCurrent(snapshot) == true else { return nil }
        return snapshot
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        Group {
            if !reader.clubIdentity.isSignedIn {
                rosterGate(systemImage: "person.crop.circle.badge.exclamationmark", "club.signInRequired", table: nil)
            } else if source?.authorization == nil {
                rosterGate(systemImage: "lock", "club.publicRoster.unavailable", table: "ClubPublicRoster")
            } else {
                rosterList
            }
        }
        .navigationTitle(isLeaderboard ? Text("club.detail.leaderboard.title") : Text("club.members"))
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .accessibilityIdentifier("club.publicRoster.root")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("club.refresh", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(loading) } }
        .refreshable { await load() }
        .task(id: key) { active = true; await load() }
        .onChange(of: scenePhase) { _, phase in
            invalidate()
            if phase == .active { active = true; Task { await load() } }
        }
        .onAppear { active = true }
        .onDisappear { active = false; invalidate() }
        .cySheet(item: $profileTarget) { target in Group {
            if let profile, current(target) {
                NavigationStack {
                    SocialPublicProfileView(memberID: target.memberID, reader: profile.reader, squareReader: profile.squareReader,
                                            actions: nil, showsStartChat: false, isCurrent: { current(target) })
                }
            } else { Color.clear.onAppear { profileTarget = nil } }
        }.cySheet(detents: [.large])
        }
        .cyDomainScreen(.player)
    }
    private func rosterGate(systemImage: String, _ message: LocalizedStringKey, table: String?) -> some View {
        ContentUnavailableView {
            Label { Text(message, tableName: table) } icon: { Image(systemName: systemImage) }
        }
    }
    private var rosterList: some View {
        List {
            if isLeaderboard {
                Section {
                    Picker("club.gov.sort", selection: $mode) {
                        ForEach([ClubPublicRosterMode.composite, .mileage, .pace, .duration], id: \.self) { value in
                            Text(LocalizedStringKey("club.gov.sort." + value.rawValue)).tag(value)
                        }
                    }
                    .accessibilityIdentifier("club.publicRoster.sort")
                } footer: {
                    Text("club.detail.leaderboard.reset")
                }
            }
            if loading { rosterLoading }
            if failed { rosterError }
            else if let current = accepted { rosterRows(current) }
        }
    }
    private var rosterLoading: some View {
        ProgressView { Text("club.loading") }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }
    private var rosterError: some View {
        Section {
            Label { Text(verbatim: rosterCopy("club.publicRoster.revoked")) } icon: { Image(systemName: "exclamationmark.triangle") }
                .foregroundStyle(.red)
                .accessibilityIdentifier("club.publicRoster.error")
            Button { Task { await load() } } label: { Label("action.retry", systemImage: "arrow.clockwise") }
                .disabled(loading)
        }
    }
    private func rosterCopy(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "ClubPublicRoster", locale: locale))
    }
    private func shown(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    @ViewBuilder private func rosterRows(_ current: ClubPublicRosterSnapshot) -> some View {
        Section {
        if current.memberIDs.isEmpty { rosterEmpty(memberCount: current.club.memberCount) }
        ForEach(current.members) { member in
            memberLink(id: member.memberId, nickname: member.nickname, avatar: member.avatar) {
                if let level = member.levelId, level > 0 { Text("club.memberLevel \(level)") }
                if let time = member.joinTime, !time.isEmpty { Text("club.memberJoined \(LocaleDisplay.civil(time, locale: locale))").fixedSize(horizontal: false, vertical: true) }
            }
        }
        // Mini `foldLeaderboard`: top 3, a hidden-count gap, then the tail (viewer id is not in the snapshot).
        ForEach(Array(ClubDetailRankingPort.fold(current.ranks.map(\.memberId), me: nil).enumerated()), id: \.offset) { _, row in
            switch row {
            case .gap(let hidden):
                Text("club.publicRoster.rankGap \(hidden)", tableName: "ClubPublicRoster").font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("club.publicRoster.rankGap")
            case .member(let rank, let memberID, _):
                if let member = current.ranks.first(where: { $0.memberId == memberID }) {
                    memberLink(id: member.memberId, nickname: member.nickname, avatar: member.avatar) {
                        rankFacts(rank: rank, member: member)
                    }
                }
            }
        }
        } header: {
            Text(verbatim: shown(current.club.name))
        } footer: {
            Text("club.publicRoster.readOnly", tableName: "ClubPublicRoster")
        }
    }
    @ViewBuilder private func rosterEmpty(memberCount: Int) -> some View {
        if isLeaderboard {
            ContentUnavailableView {
                Label {
                    Text(LocalizedStringKey("club.publicRoster.emptyRank." + ClubDetailRankingPort.emptyKey(sort: mode.rawValue)), tableName: "ClubPublicRoster")
                        .accessibilityIdentifier("club.publicRoster.empty")
                } icon: { Image(systemName: "trophy") }
            }
        } else if memberCount > 0 {
            ContentUnavailableView {
                Label { Text("club.membersUnavailable").accessibilityIdentifier("club.publicRoster.empty") } icon: { Image(systemName: "person.2") }
            }
        } else {
            ContentUnavailableView {
                Label { Text("club.emptyMembers").accessibilityIdentifier("club.publicRoster.empty") } icon: { Image(systemName: "person.2") }
            }
        }
    }
    private func rankFacts(rank: Int, member: ClubPublicRosterRank) -> some View {
        let rankLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        return rankLayout {
            Text("#\(rank)").monospacedDigit()
            if mode == .duration {
                Text(verbatim: ClubDetailRankingPort.durationText(minutes: member.metric(mode))).monospacedDigit()
            } else {
                Text(verbatim: member.metric(mode).map { ClubDetailRankingPort.oneDecimal($0) } ?? "—").monospacedDigit()
                Text(LocalizedStringKey("club.publicRoster.unit." + mode.rawValue), tableName: "ClubPublicRoster")
            }
        }.font(.subheadline)
    }
    @ViewBuilder private func memberLink<Detail: View>(id: Int, nickname: String?, avatar: String? = nil, @ViewBuilder detail: () -> Detail) -> some View {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Button { Task { await load(selecting: id) } } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        if trimmed.isEmpty { Text("club.memberNumber \(id)") } else { Text(verbatim: trimmed) }
                        detail().font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    memberPortrait(avatar, name: trimmed.isEmpty ? String(id) : trimmed)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .foregroundStyle(.primary)
        .disabled(loading || !profileMatches || profileTarget != nil)
        .accessibilityIdentifier("club.publicRoster.member.\(id)")
    }
    private func memberPortrait(_ avatar: String?, name: String) -> some View {
        // Round 2 MP asset: club detail members `item.avatar || '/images/d_profile.png'` (detail wxml:295).
        ClubMPAvatar(url: ClubCloud14HTTPS.url(avatar), name: name, size: .md)
            .accessibilityHidden(true)
    }
    private var profileMatches: Bool {
        guard let profile else { return false }
        return profile.reader.isConfigured && profile.reader.identity.accountID == reader.clubIdentity.accountID &&
            profile.reader.identity.epoch == reader.clubIdentity.epoch
    }
    private func current(_ target: ProfileTarget) -> Bool {
        guard let snapshot = accepted, let profile else { return false }
        return target.identity == reader.clubIdentity && target.generation == generation && snapshot.memberIDs.contains(target.memberID) &&
            profileMatches && profile.reader.presentationRevision == target.profileRevision &&
            ObjectIdentifier(profile.reader) == target.profileReader && ObjectIdentifier(profile.squareReader) == target.squareReader &&
            profile.squareReader.scope == target.squareScope
    }
    private func invalidate() {
        generation &+= 1; snapshot = nil; snapshotKey = nil; profileTarget = nil; loading = false; failed = false
    }
    private func load(selecting memberID: Int? = nil) async {
        invalidate()
        guard active, scenePhase == .active, let source, source.authorization != nil else { return }
        let operation = generation, expected = key
        loading = true
        defer { if generation == operation { loading = false } }
        do {
            let value = try await source.read(clubID: clubID, mode: mode, isCurrent: {
                active && scenePhase == .active && generation == operation && key == expected
            })
            guard active, scenePhase == .active, generation == operation, key == expected, !Task.isCancelled else { return }
            snapshot = value; snapshotKey = expected
            if let memberID, value.memberIDs.contains(memberID), profileMatches, let profile {
                profileTarget = .init(memberID: memberID, generation: operation, identity: reader.clubIdentity,
                    profileRevision: profile.reader.presentationRevision, profileReader: ObjectIdentifier(profile.reader),
                    squareReader: ObjectIdentifier(profile.squareReader), squareScope: profile.squareReader.scope)
            }
        } catch {
            guard active, generation == operation, key == expected, !Task.isCancelled else { return }
            snapshot = nil; profileTarget = nil; failed = true
        }
    }
}

private enum ClubCloud14HTTPS {
    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}

#if DEBUG
// C44's actual club-name fixture only. No roster, reader, profile target or request.
#Preview("C44 · public-roster heading · player") {
    Text(verbatim: "城瘾夜行俱乐部").cyText(.cardTitle)
        .fixedSize(horizontal: false, vertical: true)
        .padding(CYSpacing.pageHorizontal).themeDomain(.player)
}
#Preview("C44 · public-roster heading · merchant") {
    Text(verbatim: "城瘾夜行俱乐部").cyText(.cardTitle)
        .fixedSize(horizontal: false, vertical: true)
        .padding(CYSpacing.pageHorizontal).themeDomain(.merchant)
}
#endif
