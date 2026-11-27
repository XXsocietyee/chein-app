import SwiftUI

/// S6/S7 team lobby for one orienteering session (Find My people list + Settings › Family).
///
/// - 加入队伍: the same `GET /api/orient/team/lobby` read as `OrientLobbyTeamsView`; full teams stay hidden (MP B3)
///   and a row opens the same team on the nearby map, where 申请加入 uses the existing apply request.
/// - 我的队伍: the existing `TeamCoordinator` reads (`/api/team/my`, `/api/team/info`). Writes (移出, 公开招募)
///   go through the existing review sheet and command lease. Nothing here sends a new request.
@MainActor struct CityOrientationTeamLobbyView: View {
    let ownerType: Int
    let ownerID: Int
    var scopeTitle: String? = nil
    @EnvironmentObject private var session: AppSession
    @State private var role: Role = .join
    @State private var phase: Phase = .loading
    @State private var query = ""
    enum Role: Hashable { case join, mine }
    private enum Phase { case loading, signedOut, failed, loaded([OrientSessionTeam]) }

    var body: some View {
        Group {
            switch role {
            case .join: joinList
            case .mine:
                CityOrientationMyTeamList(ownerType: ownerType, ownerID: ownerID,
                                          makeCoordinator: { session.makeTeamCoordinator() },
                                          onBrowse: { role = .join })
                    .id(session.teamViewIdentity)
            }
        }
        .navigationTitle(Text("orientLobby.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("nativeR2.city.lobby.role", selection: $role) {
                    Text("nativeR2.city.lobby.join").tag(Role.join)
                    Text("nativeR2.city.lobby.mine").tag(Role.mine)
                }
                .cyAdaptiveSegmented()
                .accessibilityIdentifier("nativeR2.city.lobby.role")
            }
        }
        .accessibilityIdentifier("orientLobby.screen")
    }

    // MARK: 加入队伍 (session lobby)

    private var joinList: some View {
        List {
            if let scopeTitle, !scopeTitle.isEmpty {
                Section {
                    Text(verbatim: scopeTitle).foregroundStyle(.secondary)
                        .accessibilityIdentifier("orientLobby.scope")
                }
            }
            switch phase {
            case .loading:
                Section {
                    ForEach(0..<3, id: \.self) { _ in
                        LabeledContent("orientLobby.loading", value: "0/0")
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityLabel(Text("orientLobby.loading"))
            case .signedOut:
                ContentUnavailableView("orientLobby.signIn", systemImage: "person.crop.circle")
                    .accessibilityIdentifier("orientLobby.signIn")
            case .failed:
                ContentUnavailableView {
                    Label("orientLobby.failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("action.retry") { Task { await load() } }
                }
                .accessibilityIdentifier("orientLobby.failed")
            case .loaded(let teams):
                let open = filtered(teams)
                if open.isEmpty {
                    ContentUnavailableView {
                        Label("orientLobby.empty", systemImage: "person.3")
                    } actions: {
                        Button("nativeR2.city.lobby.mine") { role = .mine }
                    }
                    .accessibilityIdentifier("orientLobby.empty")
                } else {
                    Section {
                        ForEach(open, id: \.teamID) { team in
                            NavigationLink {
                                SessionRoamNearbyTeamsView(focusTeamID: NearbyTeamID(team.teamID))
                            } label: { row(team) }
                            .accessibilityIdentifier("orientLobby.team.\(team.teamID)")
                        }
                    } footer: {
                        Text("nativeR2.city.lobby.joinFooter")
                    }
                }
            }
        }
        .searchable(text: $query, prompt: Text("nativeR2.city.lobby.search"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func filtered(_ teams: [OrientSessionTeam]) -> [OrientSessionTeam] {
        let open = teams.filter { team in
            guard let max = team.maxMembers, max > 0, let joined = team.joinedCount else { return true }
            return joined < max
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return open }
        return open.filter { ($0.name ?? $0.title ?? "").localizedCaseInsensitiveContains(needle) }
    }

    private func row(_ team: OrientSessionTeam) -> some View {
        LabeledContent {
            Text("orientLobby.apply").foregroundStyle(.tint)
        } label: {
            if let name = team.name ?? team.title, !name.isEmpty { Text(verbatim: name) } else { Text("orientLobby.unnamed \(team.teamID)") }
            HStack(spacing: 4) {
                if let leader = team.leaderName, !leader.isEmpty { Text("orientLobby.leader \(leader)") } else { Text("orientLobby.leaderUnknown") }
                Text(verbatim: "· " + membersText(team)).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func membersText(_ team: OrientSessionTeam) -> String {
        let joined = team.joinedCount.map(String.init) ?? "—"
        guard let max = team.maxMembers, max > 0 else { return joined }
        return "\(joined)/\(max)"
    }

    /// Same read and failure mapping as `OrientLobbyTeamsView.load()`.
    private func load() async {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { phase = .failed; return }
        guard let token = session.token else { phase = .signedOut; return }
        if case .loaded = phase {} else { phase = .loading }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        do { phase = .loaded(try await service.lobby(ownerType: ownerType, ownerID: ownerID, token: token)) }
        catch is CancellationError { return }
        catch APIError.unauthorized { phase = .signedOut }
        catch { phase = .failed }
    }
}

/// 我的队伍 for this session: members with their role, captain tools, the public-recruiting switch and the invite.
@MainActor struct CityOrientationMyTeamList: View {
    let ownerType: Int
    let ownerID: Int
    let onBrowse: () -> Void
    @StateObject private var model: TeamScreenModel
    @State private var loadedTeamID: Int?
    @State private var readDone = false

    init(ownerType: Int, ownerID: Int, makeCoordinator: @escaping () -> TeamCoordinator, onBrowse: @escaping () -> Void) {
        self.ownerType = ownerType; self.ownerID = ownerID; self.onBrowse = onBrowse
        _model = StateObject(wrappedValue: TeamScreenModel(makeCoordinator()))
    }

    private var myTeam: OwnedTeam? {
        let key = TeamOwnerKey(type: ownerType, id: ownerID)
        return model.coordinator.currentTeams.first { $0.ownerKey == key && $0.status != .disbanded && $0.status != .ended }
    }
    private var detail: TeamDetail? {
        guard let detail = model.coordinator.detail, detail.team.id == loadedTeamID else { return nil }
        return detail
    }

    var body: some View {
        List {
            TeamNotice(coordinator: model.coordinator)
            if !model.coordinator.authenticated {
                ContentUnavailableView("orientLobby.signIn", systemImage: "person.crop.circle")
                    .accessibilityIdentifier("nativeR2.city.lobby.signedOut")
            } else if let detail {
                content(detail)
            } else if model.running || !readDone {
                Section {
                    ForEach(0..<3, id: \.self) { _ in Label("team.loading", systemImage: "person.crop.circle") }
                }
                .redacted(reason: .placeholder)
            } else {
                ContentUnavailableView {
                    Label("nativeR2.city.lobby.noTeam", systemImage: "person.3")
                } description: {
                    Text("nativeR2.city.lobby.noTeamDetail")
                } actions: {
                    Button("nativeR2.city.lobby.join", action: onBrowse)
                }
                .accessibilityIdentifier("nativeR2.city.lobby.noTeam")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .toolbar {
            if let detail, let code = inviteCode(detail) {
                ToolbarItem(placement: .bottomBar) {
                    ShareLink(item: code) {
                        Label("nativeR2.city.lobby.invite", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("nativeR2.city.lobby.invite")
                }
            }
        }
        .cySheet(item: model.reviewBinding) { review in TeamReviewSheet(model: model, review: review) }
        .onDisappear { model.leave() }
    }

    @ViewBuilder private func content(_ detail: TeamDetail) -> some View {
        Section {
            LabeledContent("nativeR2.city.lobby.status") { Text(LocalizedStringKey(detail.team.status.key)) }
            if let max = detail.team.maxMembers, max > 0 {
                LabeledContent("nativeR2.city.lobby.members") {
                    Text(verbatim: "\(detail.members.count)/\(max)").monospacedDigit()
                }
                Gauge(value: Double(min(detail.members.count, max)), in: 0...Double(max)) {
                    Text("nativeR2.city.lobby.members")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .accessibilityIdentifier("nativeR2.city.lobby.seats")
            }
            if let code = inviteCode(detail) {
                LabeledContent("nativeR2.city.lobby.code") { Text(verbatim: code).monospaced().textSelection(.enabled) }
            }
        } header: {
            Text(verbatim: detail.team.title)
        }
        Section("nativeR2.city.lobby.membersHeader") {
            ForEach(detail.members) { member in
                LabeledContent {
                    Text(member.isCaptain ? "team.member.captain" : member.role == 0 ? "team.member.player" : "team.member.unknownRole")
                } label: {
                    Label {
                        if member.name.isEmpty { Text("playx.player.unnamed") } else { Text(verbatim: member.name) }
                    } icon: {
                        Image(systemName: member.isCaptain ? "crown" : "person.crop.circle")
                    }
                }
                .swipeActions(edge: .trailing) {
                    let remove = TeamAction.remove(teamID: detail.team.id, memberID: member.id)
                    if remove.isAllowed(detail: detail), !model.actionLocked {
                        Button("team.remove", role: .destructive) { model.prepare(remove) }
                    }
                }
                .accessibilityIdentifier("nativeR2.city.lobby.member.\(member.id)")
            }
        }
        if detail.leader == true, detail.team.status == .recruiting, detail.team.joinMode != .unknown {
            Section {
                Toggle("nativeR2.city.lobby.public", isOn: publicBinding(detail))
                    .disabled(model.actionLocked)
                    .accessibilityIdentifier("nativeR2.city.lobby.public")
            } footer: {
                Text("nativeR2.city.lobby.publicFooter")
            }
        }
    }

    /// The switch shows the confirmed mode; flipping it opens the existing review, never a direct write.
    private func publicBinding(_ detail: TeamDetail) -> Binding<Bool> {
        Binding(
            get: { (model.coordinator.confirmedJoinMode ?? detail.team.joinMode) == .publicApplication },
            set: { isPublic in
                let action = TeamAction.changeJoinMode(teamID: detail.team.id, mode: isPublic ? .publicApplication : .invitation)
                if action.isAllowed(detail: detail) { model.prepare(action) }
            })
    }

    private func inviteCode(_ detail: TeamDetail) -> String? {
        guard detail.joined == true, detail.team.status == .recruiting,
              let code = detail.team.inviteCode, TeamLookup.validInvite(code) else { return nil }
        return code
    }

    private func load() async {
        await model.run { await model.coordinator.loadTeams() }
        if let team = myTeam {
            loadedTeamID = team.id
            await model.run { await model.coordinator.loadDetail(.id(team.id), requireMembership: true) }
        } else {
            loadedTeamID = nil
        }
        readDone = true
    }
}
