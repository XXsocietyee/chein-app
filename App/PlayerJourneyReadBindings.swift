import SwiftUI

extension MPParityBindings {
    /// Fills the journey closures on an existing bindings value. Purchase and gift claim stay nil.
    @MainActor func fillingPlayerJourneyReads(source: JourneyLoopSource, token: @escaping () -> String?) -> MPParityBindings {
        var copy = self
        copy.journeyLanding = { link in PlayerJourneyLandingModel(link: link, source: source, token: token) }
        copy.journeySeats = { registrationID in PlayerJourneySeatsModel(registrationID: registrationID, source: source, token: token) }
        copy.journeyReport = { scope in PlayerJourneyReportModel(scope: scope, source: source, token: token) }
        copy.journeySettle = { scope in PlayerJourneySettleModel(scope: scope, source: source, token: token) }
        copy.journeyPromo = { PlayerJourneyPromoModel(source: source, token: token) }
        return copy
    }
}

extension AppSession {
    func mpParityPlayerReads() -> MPParityBindings {
        let base = mpParityPassBindings().fillingVideoBounty(session: self)
        guard let source = composition.playerJourneySource() else { return base }
        return base.fillingPlayerJourneyReads(source: source, token: { [weak self] in self?.token })
    }

    /// Anonymous catalog host for the shipped China composition. A missing host sends nothing.
    func installPublicCatalogHost() {
        guard let host = composition.publicCatalogHost() else {
            PublicCatalogHostWiring.host = nil
            PublicCatalogHostWiring.scope = nil
            PublicCatalogHostWiring.token = nil
            return
        }
        PublicCatalogHostWiring.host = host
        if let token, AuthRequestBuilder.isValidToken(token) {
            PublicCatalogHostWiring.token = token
        } else {
            PublicCatalogHostWiring.token = nil
        }
        if let context = currentRuntimeDependencyContext {
            PublicCatalogHostWiring.scope = try? PWaveSessionScope(accountID: context.session.accountID,
                                                                   epoch: context.session.epoch,
                                                                   namespace: context.session.namespace)
        } else if let namespace = composition.reviewed?.storageScope.service {
            PublicCatalogHostWiring.scope = try? PWaveSessionScope(accountID: 1, epoch: 1, namespace: namespace)
        } else {
            PublicCatalogHostWiring.scope = nil
        }
    }
}

@MainActor @Observable final class PlayerJourneySignInBridge {
    static let shared = PlayerJourneySignInBridge()
    var presented = false
    func request() { presented = true }
}

struct PlayerJourneySignInSheet: ViewModifier {
    @Bindable var bridge: PlayerJourneySignInBridge
    let session: AppSession

    func body(content: Content) -> some View {
        content.sheet(isPresented: $bridge.presented) {
            LoginView(intent: .player).environmentObject(session)
        }
    }
}

@MainActor @Observable final class PlayerJourneyLandingModel: JourneyLandingBinding {
    private(set) var phase: JourneyLandingPhase = .loading
    private let link: JourneyLandingLink
    private let source: JourneyLoopSource
    private let token: () -> String?
    private var activeMode: String?

    init(link: JourneyLandingLink, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.link = link
        self.source = source
        self.token = token
    }

    func load() {
        phase = .loading
        Task { await reload() }
    }

    func selectMode(_ key: String) { activeMode = key }

    /// Landing stays a read. Gift claim and seat claim are not sent from this screen.
    func primary() {}

    private func reload() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            phase = .failed
            return
        }
        do {
            let envelope: JourneyEnvelope
            switch link.kind {
            case .referral:
                envelope = try await source.referral(token: link.token, sessionToken: session)
            case .gift:
                envelope = try await source.gift(token: link.token, sessionToken: session)
            case .seat:
                let choices = (link.activityID != nil || link.topicID != nil)
                    ? try? await source.choices(activityID: link.activityID, topicID: link.topicID, token: session) : nil
                phase = .ready(JourneyLandingContent(headline: .seat, inviter: nil, title: nil, seatNo: nil, facts: [],
                                                    tiles: PlayerJourneyProjection.tiles(choices), activeMode: activeMode,
                                                    primary: .claimSeat))
                return
            }
            let choices = (link.activityID != nil || link.topicID != nil)
                ? try? await source.choices(activityID: link.activityID, topicID: link.topicID, token: session) : nil
            phase = PlayerJourneyProjection.landing(link: link, envelope: envelope, choices: choices, activeMode: activeMode)
        } catch {
            phase = .failed
        }
    }
}

@MainActor @Observable final class PlayerJourneySeatsModel: JourneySeatsBinding {
    private(set) var phase: JourneySeatsPhase = .loading
    private let registrationID: String
    private let source: JourneyLoopSource
    private let token: () -> String?
    private var inviteURL: URL?

    init(registrationID: String, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.registrationID = registrationID
        self.source = source
        self.token = token
    }

    func load() {
        phase = .loading
        Task { await reload() }
    }

    func requestInvite() {
        Task { await invite() }
    }

    func cancelInvitation(_ id: String) {
        Task { await cancel(id) }
    }

    func goToStart() {}

    func editMe() {}

    private func reload() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            phase = .denied(nil)
            return
        }
        do {
            let seats = try await source.seats(registrationID: registrationID, token: session)
            phase = PlayerJourneyProjection.seats(seats, choices: nil, registrationID: registrationID)
            if case .ready(var content) = phase {
                if content.me == nil, let profile = try? await source.playerProfile(token: session) {
                    content.me = PlayerJourneyProjection.person(profile)
                }
                content.inviteShareURL = inviteURL
                phase = .ready(content)
            }
        } catch JourneyRefusal.invalidRequest {
            phase = .missing
        } catch {
            phase = .failed
        }
    }

    private func invite() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else { return }
        do {
            let envelope = try await source.seatInvite(registrationID: registrationID, token: session)
            applyWrite(envelope)
        } catch {
            applyWrite(nil)
        }
    }

    private func cancel(_ id: String) async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else { return }
        do {
            let envelope = try await source.seatCancel(invitationID: id, token: session)
            applyWrite(envelope)
        } catch {
            applyWrite(nil)
        }
    }

    /// A confirmed answer refreshes the lobby. An unknown answer keeps the saved request id and does not draw success.
    private func applyWrite(_ envelope: JourneyEnvelope?) {
        guard var content = phase.content else { return }
        if let envelope, envelope.ok, !envelope.unconfirmed {
            content.actionError = nil
            inviteURL = PlayerJourneyProjection.httpsURL(in: envelope.dataJSON)
            content.inviteShareURL = inviteURL
            phase = .ready(content)
            load()
            return
        }
        content.inviteShareURL = nil
        content.actionError = envelope?.message ?? JourneyEnvelope.networkFailure.message
        phase = .ready(content)
    }
}

@MainActor @Observable final class PlayerJourneyReportModel: JourneyReportBinding {
    private(set) var phase: JourneyReportPhase = .loading
    private(set) var memory: JourneyMemoryPhase = .idle
    private(set) var rank = JourneyRankState()
    private(set) var feedback: JourneyFeedbackState = .editing(nil)
    let shareURL: URL? = nil
    private let scope: JourneyRunScope
    private let source: JourneyLoopSource
    private let token: () -> String?
    /// Kept unchanged while the answer is unknown: the same request id is only re-sent with the same text.
    private var pendingFeedback: PostGameFeedbackDraft?
    private var teamsProbed = false

    init(scope: JourneyRunScope, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.scope = scope
        self.source = source
        self.token = token
        rank.tabs = PlayerJourneyProjection.rankTabs(scope)
        rank.more = PlayerJourneyProjection.rankMore()
        rank.scope = rank.tabs.first ?? rank.more.first
        rank.phase = .loading
    }

    /// U08-02 feedback needs this run's id and a host that sends the write.
    var feedbackAvailable: Bool {
        guard source.sendsRunFeedback, case .ready(let report) = phase, !report.legacy, let run = report.runID else { return false }
        return JourneyLoopSource.isID(run)
    }

    func load() {
        Task { await loadNow() }
    }

    func signIn() { PlayerJourneySignInBridge.shared.request() }

    func loadMemory() {
        memory = .loading
        Task { await reloadMemory() }
    }

    func loadRank() {
        rank.phase = .loading
        Task { await reloadRank() }
    }

    func selectRankScope(_ scope: JourneyRankScope) {
        guard rank.tabs.contains(scope) || rank.more.contains(scope) else { return }
        rank.scope = scope
        loadRank()
    }

    func selectRankPeriod(_ period: JourneyRankPeriod) {
        rank.period = period
        loadRank()
    }

    func submitFeedback(category: PostGameFeedbackCategory, nodeID: String?, text: String) {
        guard case .ready(let report) = phase, let run = report.runID else { return }
        if case .sending = feedback { return }
        if case .unconfirmed = feedback { return }
        let draft = PostGameFeedbackDraft(runID: run, nodeID: nodeID, category: category, content: text)
        if let problem = draft.problem {
            feedback = .editing(problem)
            return
        }
        pendingFeedback = draft
        feedback = .sending
        Task { await sendFeedback(draft, reread: false) }
    }

    func recheckFeedback() {
        guard let draft = pendingFeedback, case .unconfirmed = feedback else { return }
        feedback = .sending
        Task { await sendFeedback(draft, reread: true) }
    }

    func resetFeedback() {
        if case .unconfirmed = feedback { return }
        if case .sending = feedback { return }
        pendingFeedback = nil
        feedback = .editing(nil)
    }

    private func loadNow() async {
        phase = .loading
        await reload()
    }

    private func reload() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            phase = .auth
            return
        }
        guard scope.activityID != nil || scope.topicID != nil else {
            phase = .missing
            return
        }
        do {
            let envelope = try await source.report(activityID: scope.activityID, topicID: scope.topicID, runID: scope.runID, token: session)
            phase = PlayerJourneyProjection.report(envelope, scope: scope)
        } catch {
            phase = .failed
        }
        if case .ready(let report) = phase, !report.legacy, !teamsProbed {
            teamsProbed = true
            await probeTeams(session)
        }
    }

    /// The Teams tab only appears when the server returns team rows for this topic or activity.
    private func probeTeams(_ session: String) async {
        guard let envelope = try? await playerJourneyTeams(run: scope, source: source, token: session),
              case .ready = PlayerJourneyProjection.teams(envelope) else { return }
        let teams = JourneyRankScope(kind: .teams)
        if !rank.tabs.contains(teams) { rank.tabs.append(teams) }
        if rank.scope == nil { rank.scope = teams }
    }

    private var runID: String? {
        if case .ready(let report) = phase { return report.runID ?? scope.runID }
        return scope.runID
    }

    private func reloadMemory() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            memory = .failed(nil)
            return
        }
        let run = runID
        do {
            let envelope = try await source.memory(activityID: scope.activityID, topicID: scope.topicID, runID: run, token: session)
            memory = PlayerJourneyProjection.memory(envelope, runID: run)
        } catch {
            memory = .failed(nil)
        }
    }

    private func reloadRank() async {
        guard let selected = rank.scope else {
            rank.phase = .empty
            return
        }
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            rank.phase = .failed(nil)
            return
        }
        let period = rank.period
        let phase = await playerJourneyRank(selected: selected, run: scope, period: period, source: source, token: session)
        guard rank.scope == selected, rank.period == period else { return }
        rank.phase = phase
    }

    private func sendFeedback(_ draft: PostGameFeedbackDraft, reread: Bool) async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            feedback = reread ? .unconfirmed : .refused(nil)
            if !reread { pendingFeedback = nil }
            return
        }
        let envelope: JourneyEnvelope
        do {
            if reread {
                envelope = try await source.rereadRunFeedback(draft, token: session)
            } else {
                envelope = try await SessionOfflineSyncModel.shared.performWriteOptIn(
                    routes: ["/api/play/feedback/submit"]
                ) {
                    try await source.runFeedback(draft, token: session)
                }
            }
        } catch JourneyRefusal.noSavedRequest {
            // Nothing saved under this run: the last answer was final; the receipt cannot be re-read.
            pendingFeedback = nil
            feedback = .refused(nil)
            return
        } catch {
            pendingFeedback = nil
            feedback = .refused(nil)
            return
        }
        guard pendingFeedback == draft else { return }
        switch PostGameFeedbackOutcome.classify(envelope) {
        case .received(let receipt):
            pendingFeedback = nil
            feedback = .received(receipt)
        case .unconfirmed:
            feedback = .unconfirmed
        case .refused(let code, let message):
            pendingFeedback = nil
            feedback = code == "401" ? .refused(nil) : .refused(message)
        }
    }
}

@MainActor @Observable final class PlayerJourneySettleModel: JourneySettleBinding {
    private(set) var phase: JourneySettlePhase = .loading
    private(set) var rank = JourneyRankState()
    private(set) var rate: JourneyRateState = .idle
    let shareURL: URL? = nil
    private(set) var topicName: String?
    private let scope: JourneyRunScope
    private let source: JourneyLoopSource
    private let token: () -> String?

    init(scope: JourneyRunScope, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.scope = scope
        self.source = source
        self.token = token
        topicName = scope.topicName
        // Settle preset: only the whole-board tab (mini-program rank-board `preset="settle"`), no "more".
        rank.tabs = PlayerJourneyProjection.rankTabs(scope).filter { $0.kind == .quest }
        rank.scope = rank.tabs.first
        rank.phase = .loading
    }

    func load() {
        phase = .loading
        Task { await reload() }
    }

    func signIn() { PlayerJourneySignInBridge.shared.request() }

    func loadRank() {
        rank.phase = .loading
        Task { await reloadRank() }
    }

    func selectRankScope(_ scope: JourneyRankScope) {
        guard rank.tabs.contains(scope) else { return }
        rank.scope = scope
        loadRank()
    }

    func selectRankPeriod(_ period: JourneyRankPeriod) {
        rank.period = period
        loadRank()
    }

    func submitRating(stars: Int, text: String) {
        rate = .busy
        Task { await sendRating(stars: stars, text: text) }
    }

    func leave() {}

    private func reload() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            phase = .auth
            return
        }
        guard scope.activityID != nil || scope.topicID != nil else {
            phase = .missing
            return
        }
        do {
            let envelope = try await source.report(activityID: scope.activityID, topicID: scope.topicID, runID: scope.runID, token: session)
            switch PlayerJourneyProjection.report(envelope, scope: scope) {
            case .loading: phase = .failed(gone: false)
            case .missing: phase = .missing
            case .auth: phase = .auth
            case .gone: phase = .failed(gone: true)
            case .denied, .failed: phase = .failed(gone: false)
            case .ready(let value):
                phase = value.finished ? .ready(value) : .notFinished
            }
        } catch {
            phase = .failed(gone: false)
        }
    }

    private func reloadRank() async {
        guard let selected = rank.scope else {
            rank.phase = .empty
            return
        }
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            rank.phase = .failed(nil)
            return
        }
        let period = rank.period
        let phase = await playerJourneyRank(selected: selected, run: scope, period: period, source: source, token: session)
        guard rank.scope == selected, rank.period == period else { return }
        rank.phase = phase
    }

    private func sendRating(stars: Int, text: String) async {
        let owner: (Int, String)?
        if let topic = scope.topicID, JourneyLoopSource.isID(topic) {
            owner = (1, topic)
        } else if let run = scope.runID, JourneyLoopSource.isID(run) {
            owner = (2, run)
        } else {
            owner = nil
        }
        guard let owner, (1...5).contains(stars), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            rate = .error("—")
            return
        }
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            rate = .error("—")
            return
        }
        do {
            let envelope = try await source.rate(ownerType: owner.0, ownerID: owner.1, rating: stars, contents: text, token: session)
            if envelope.ok, !envelope.unconfirmed {
                rate = .thanks
            } else {
                rate = .error(envelope.message ?? JourneyEnvelope.networkFailure.message ?? "—")
            }
        } catch {
            rate = .error(JourneyEnvelope.networkFailure.message ?? "—")
        }
    }
}

private extension JourneySeatsPhase {
    var content: JourneySeatsContent? {
        if case .ready(let value) = self { return value }
        return nil
    }
}

/// U08-05 / §23.4. Quest and world are `/api/rank/list` (quest needs the topic id; activity ids are not quest ids).
/// Teams is `/api/orient/team/ranking` with owner type 1 topic / 2 activity. A member board inside one team
/// (`team`, 队内) is offered for a team run per channels contract §5.
private func playerJourneyRank(selected: JourneyRankScope, run: JourneyRunScope, period: JourneyRankPeriod,
                               source: JourneyLoopSource, token: String) async -> JourneyRankPhase {
    do {
        switch selected.kind {
        case .teams:
            guard let envelope = try await playerJourneyTeams(run: run, source: source, token: token) else { return .empty }
            return PlayerJourneyProjection.teams(envelope)
        case .quest:
            guard let topic = run.topicID, JourneyLoopSource.isID(topic) else { return .empty }
            let envelope = try await source.rank(scope: "quest", scopeID: topic, period: period.rawValue, token: token)
            return PlayerJourneyProjection.rank(envelope, scope: "quest", scopeID: topic, period: period.rawValue)
        case .world:
            let envelope = try await source.rank(scope: "world", scopeID: nil, period: period.rawValue, token: token)
            return PlayerJourneyProjection.rank(envelope, scope: "world", scopeID: nil, period: period.rawValue)
        case .team:
            // In-team board (队内, channels contract §5): the same rank list scoped to this run's play team.
            // A non-member gets the server refusal message, not an empty board.
            guard let team = run.teamID, JourneyLoopSource.isID(team) else { return .empty }
            let envelope = try await source.rank(scope: "team", scopeID: team, period: period.rawValue, token: token)
            return PlayerJourneyProjection.rank(envelope, scope: "team", scopeID: team, period: period.rawValue)
        case .city, .country, .club:
            return .empty
        }
    } catch {
        return .failed(nil)
    }
}

private func playerJourneyTeams(run: JourneyRunScope, source: JourneyLoopSource, token: String) async throws -> JourneyEnvelope? {
    if let activity = run.activityID, JourneyLoopSource.isID(activity) {
        return try await source.teamRanking(ownerType: 2, ownerID: activity, token: token)
    }
    if let topic = run.topicID, JourneyLoopSource.isID(topic) {
        return try await source.teamRanking(ownerType: 1, ownerID: topic, token: token)
    }
    return nil
}

enum PlayerJourneyProjection {
    /// Whole board for this topic. City, country and club need frozen codes or a club id the run scope does not carry.
    static func rankTabs(_ run: JourneyRunScope) -> [JourneyRankScope] {
        var tabs: [JourneyRankScope] = []
        if let topic = run.topicID, JourneyLoopSource.isID(topic) { tabs.append(JourneyRankScope(kind: .quest)) }
        // In-team board (队内) only for a team run (channels contract §5).
        if let team = run.teamID, JourneyLoopSource.isID(team) { tabs.append(JourneyRankScope(kind: .team)) }
        return tabs
    }

    static func rankMore() -> [JourneyRankScope] { [JourneyRankScope(kind: .world)] }

    static func landing(link: JourneyLandingLink, envelope: JourneyEnvelope, choices: JourneyEnvelope?, activeMode: String?) -> JourneyLandingPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed }
        if envelope.code == "401" || envelope.httpStatus == 401 { return .failed }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else {
            if envelope.code == "404" || envelope.httpStatus == 404 { return .missing }
            return .failed
        }
        let state = string(object["state"])
        if let state, state != "VALID" {
            return .invalid(reason: envelope.message ?? state, success: state == "CLAIMED")
        }
        let inviter = object["inviter"] as? [String: Any]
        let person = string(inviter?["nickname"]).map { JourneyPerson(name: $0, avatarURL: url(string(inviter?["avatar"]))) }
        let primary: JourneyLandingPrimary?
        switch link.kind {
        case .referral: primary = .view
        case .gift: primary = .claimGift
        case .seat: primary = .claimSeat
        }
        var facts: [JourneyFact] = []
        if let expires = string(object["expiresAt"]), expires != "UNKNOWN" {
            facts.append(JourneyFact(kind: .inviteValid, value: expires))
        }
        let content = JourneyLandingContent(headline: link.kind == .gift ? .gift : (link.kind == .seat ? .seat : .referral),
                                            inviter: person, title: string(object["title"]), seatNo: string(object["seatNo"]),
                                            facts: facts, tiles: tiles(choices), activeMode: activeMode, primary: primary)
        return .ready(content)
    }

    static func seats(_ envelope: JourneyEnvelope, choices: JourneyEnvelope?, registrationID: String) -> JourneySeatsPhase {
        _ = registrationID
        if envelope.code == "401" || envelope.httpStatus == 401 || envelope.code == "403" || envelope.httpStatus == 403 {
            return .denied(envelope.message)
        }
        if envelope.unconfirmed || envelope.netFail { return .failed }
        if envelope.code == "404" || envelope.httpStatus == 404 { return .missing }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return .failed }
        let circles = (object["seats"] as? [Any] ?? []).compactMap(circle)
        let invited = (object["invitations"] as? [Any] ?? []).compactMap(invitedRow)
        let count = int(object["seatCount"])
        let occupied = int(object["occupied"])
        let open = int(object["openCount"]) ?? circles.filter { $0.kind == .open }.count
        let content = JourneySeatsContent(headName: string(object["title"]) ?? string(object["name"]),
                                          headCoverURL: string(object["cover"]),
                                          me: string(object["playerName"]).map { JourneyPerson(name: $0, avatarURL: nil) },
                                          showsParty: (count ?? circles.count) > 1,
                                          occupied: occupied, seatCount: count, circles: circles,
                                          canInvite: object["canInvite"] as? Bool ?? false,
                                          openCount: open, invited: invited, multi: (count ?? 0) >= 2,
                                          tiles: tiles(choices), canGoToStart: object["canStart"] as? Bool ?? false,
                                          actionError: nil, inviteShareURL: nil)
        return .ready(content)
    }

    /// U08-01: real `PlayerRunReportVO` fields through `PostGameRunReport` (mini-program `reportView`).
    /// An explicit run that comes back as another run is not shown as this one.
    static func report(_ envelope: JourneyEnvelope, scope: JourneyRunScope) -> JourneyReportPhase {
        if envelope.code == "401" || envelope.httpStatus == 401 { return .auth }
        if envelope.code == "403" || envelope.httpStatus == 403 { return .denied(envelope.message) }
        if envelope.code == "404" || envelope.httpStatus == 404 { return .gone }
        if envelope.unconfirmed || envelope.netFail { return .failed }
        guard envelope.ok, let fact = PostGameRunReport.decode(envelope.dataJSON) else { return .missing }
        if let asked = scope.runID, let answered = fact.runID, asked != answered { return .gone }
        let value = JourneyReport(legacy: fact.legacyScope,
                                  result: fact.completion.flatMap { JourneyResult(rawValue: $0.rawValue) },
                                  dateLabel: fact.dateText, nodesText: fact.nodesText, elapsedText: fact.elapsedText,
                                  score: fact.score, rank: fact.rank, rankBasisCount: fact.rankScore,
                                  penaltyText: fact.penalties.map { "-\($0)" }, rewardItems: fact.backpackItems,
                                  runID: fact.runID ?? scope.runID, topicID: fact.topicID ?? scope.topicID,
                                  activityID: fact.activityID ?? scope.activityID, coverURL: nil,
                                  nodes: fact.nodes.map { node in
                                      JourneyNodeRow(id: node.id, name: node.name,
                                                     mode: node.mode.map { mode -> JourneyNodeRow.Mode in mode == .skipped ? .skipped : .revealed },
                                                     score: node.score)
                                  },
                                  finished: fact.finished, inProgress: fact.inProgress)
        return .ready(value)
    }

    /// U08-01 / P8: own stops and own photos only; companions' photos need the server's consent fact.
    static func memory(_ envelope: JourneyEnvelope, runID: String?) -> JourneyMemoryPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed(envelope.message) }
        guard envelope.ok else { return .failed(envelope.message) }
        guard let fact = PostGameRunMemory.decode(envelope.dataJSON) else { return .empty }
        if let runID, let answered = fact.runID, answered != runID { return .failed(nil) }
        if fact.isEmpty { return .empty }
        let moments = fact.moments.map { moment in
            JourneyMoment(id: moment.id, dayText: moment.dayText, name: moment.name, timeText: moment.timeText,
                          text: moment.text, pictureURL: moment.pictureURL)
        }
        return .ready(JourneyMemory(participants: fact.companions, moments: moments, peerPhotosHidden: !fact.peerPhotosAvailable))
    }

    /// §23.4 scoped board. A board for another scope, id or period is not shown as the selected one.
    static func rank(_ envelope: JourneyEnvelope, scope: String, scopeID: String?, period: String) -> JourneyRankPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed(envelope.message) }
        guard envelope.ok else { return .failed(envelope.message) }
        return board(PostGameRankBoard.decodeScoped(envelope.dataJSON, scope: scope, scopeID: scopeID, period: period))
    }

    /// Team-to-team board. Not a member board inside one team.
    static func teams(_ envelope: JourneyEnvelope) -> JourneyRankPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed(envelope.message) }
        guard envelope.ok else { return .failed(envelope.message) }
        return board(PostGameRankBoard.decodeTeams(envelope.dataJSON))
    }

    private static func board(_ decoded: PostGameRankBoard.Decoded) -> JourneyRankPhase {
        switch decoded {
        case .empty: return .empty
        case .mismatch, .malformed: return .failed(nil)
        case .board(let fact):
            let entries = fact.entries.map { entry -> JourneyRankEntry in
                let score: String
                switch (entry.score, entry.total) {
                case (let done?, let total?): score = "\(done)/\(total)"
                case (let done?, nil): score = String(done)
                default: score = MPText.unknown
                }
                return JourneyRankEntry(id: entry.id, rank: entry.rank, name: entry.name, avatarURL: entry.avatarURL,
                                        scoreText: score, mine: entry.mine)
            }
            var stats: [JourneyRankStat] = []
            if fact.basis == .teamTasks, let mine = entries.first(where: \.mine) {
                stats.append(JourneyRankStat(kind: .teamDone, value: mine.scoreText))
                let active = fact.entries.first { $0.mine }?.active
                stats.append(JourneyRankStat(kind: .activeMembers, value: active.map(String.init) ?? MPText.unknown))
            }
            let basis: JourneyRankBoard.Basis? = switch fact.basis {
            case .completedNodes?: .completedNodes
            case .teamTasks?: .wholeTeam
            case nil: nil
            }
            return .ready(JourneyRankBoard(entries: entries, basis: basis, windowText: fact.windowText,
                                           unattributedRuns: fact.unattributedRuns, unverifiedRuns: fact.unverifiedRuns,
                                           stats: stats, heroRank: fact.myRank, topPercent: fact.topPercent))
        }
    }

    static func person(_ envelope: JourneyEnvelope) -> JourneyPerson? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON), let name = string(object["nickname"]) else { return nil }
        return JourneyPerson(name: name, avatarURL: url(string(object["avatar"])))
    }

    static func httpsURL(in data: Data?) -> URL? {
        guard let object = jsonObject(data) else { return nil }
        return url(string(object["shareUrl"]) ?? string(object["url"]))
    }

    static func tiles(_ envelope: JourneyEnvelope?) -> [JourneyModeTile] {
        guard let envelope, envelope.ok, let object = jsonObject(envelope.dataJSON),
              let rows = object["choices"] as? [Any] else { return [] }
        return rows.compactMap { item in
            guard let row = item as? [String: Any], let key = string(row["key"]) ?? string(row["mode"]) else { return nil }
            let name: JourneyModeTile.Name
            switch key {
            case "together": name = .together
            case "compete": name = .compete
            case "solo": name = .solo
            default: return nil
            }
            return JourneyModeTile(key: key, name: name, sub: nil, reason: string(row["reason"]),
                                   available: row["available"] as? Bool ?? false, rules: [])
        }
    }

    private static func circle(_ value: Any) -> JourneySeatCircle? {
        guard let row = value as? [String: Any], let no = int(row["no"]) ?? int(row["seatNo"]) else { return nil }
        let kind = string(row["state"]).flatMap(JourneySeatKind.init(rawValue:)) ?? .reserved
        return JourneySeatCircle(no: no, kind: kind, avatarURL: url(string(row["avatar"])), initial: string(row["initial"]),
                                 tappable: kind == .open)
    }

    private static func invitedRow(_ value: Any) -> JourneyInvitedRow? {
        guard let row = value as? [String: Any], let id = string(row["invitationId"]) ?? string(row["id"]),
              let no = int(row["no"]) ?? int(row["seatNo"]) else { return nil }
        let kind = string(row["state"]).flatMap(JourneySeatKind.init(rawValue:)) ?? .invited
        return JourneyInvitedRow(invitationID: id, no: no, kind: kind, expiresText: string(row["expiresAt"]),
                                 canCancel: row["canCancel"] as? Bool ?? false)
    }

    private static func jsonObject(_ data: Data?) -> [String: Any]? {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private static func int(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        let double = number.doubleValue
        guard double.rounded() == double, abs(double) <= Double(Int.max) else { return nil }
        return number.intValue
    }

    private static func string(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "UNKNOWN" ? nil : text
    }

    private static func url(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}
