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
    let shareURL: URL? = nil
    private let scope: JourneyRunScope
    private let source: JourneyLoopSource
    private let token: () -> String?

    init(scope: JourneyRunScope, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.scope = scope
        self.source = source
        self.token = token
        rank.tabs = PlayerJourneyProjection.rankTabs()
        rank.scope = rank.tabs.first
        rank.phase = .loading
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
        guard rank.tabs.contains(scope) else { return }
        rank.scope = scope
        loadRank()
    }

    func selectRankPeriod(_ period: JourneyRankPeriod) {
        rank.period = period
        loadRank()
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
    }

    private func reloadMemory() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            memory = .failed(nil)
            return
        }
        do {
            let envelope = try await source.memory(activityID: scope.activityID, topicID: scope.topicID, runID: scope.runID, token: session)
            memory = PlayerJourneyProjection.memory(envelope)
        } catch {
            memory = .failed(nil)
        }
    }

    private func reloadRank() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session), let selected = rank.scope else {
            rank.phase = .failed(nil)
            return
        }
        do {
            guard let envelope = try await playerJourneyRank(selected: selected, run: scope, period: rank.period, source: source, token: session) else {
                rank.phase = .empty
                return
            }
            rank.phase = PlayerJourneyProjection.rank(envelope)
        } catch {
            rank.phase = .failed(nil)
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
        rank.tabs = PlayerJourneyProjection.rankTabs()
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
        guard let session = token(), AuthRequestBuilder.isValidToken(session), let selected = rank.scope else {
            rank.phase = .failed(nil)
            return
        }
        do {
            guard let envelope = try await playerJourneyRank(selected: selected, run: scope, period: rank.period, source: source, token: session) else {
                rank.phase = .empty
                return
            }
            rank.phase = PlayerJourneyProjection.rank(envelope)
        } catch {
            rank.phase = .failed(nil)
        }
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

/// Quest tab is `/api/rank/list`. Team tab is `/api/orient/team/ranking` when a topic or session id is present.
private func playerJourneyRank(selected: JourneyRankScope, run: JourneyRunScope, period: JourneyRankPeriod,
                               source: JourneyLoopSource, token: String) async throws -> JourneyEnvelope? {
    if selected.kind == .team {
        if let topic = run.topicID, JourneyLoopSource.isID(topic) {
            return try await source.teamRanking(ownerType: 1, ownerID: topic, token: token)
        }
        if let session = run.runID, JourneyLoopSource.isID(session) {
            return try await source.teamRanking(ownerType: 2, ownerID: session, token: token)
        }
        return nil
    }
    return try await source.rank(scope: selected.kind.rawValue, scopeID: run.topicID ?? run.activityID,
                                 period: period.rawValue, token: token)
}

enum PlayerJourneyProjection {
    static func rankTabs() -> [JourneyRankScope] {
        [JourneyRankScope(kind: .quest), JourneyRankScope(kind: .team)]
    }

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

    static func report(_ envelope: JourneyEnvelope, scope: JourneyRunScope) -> JourneyReportPhase {
        if envelope.code == "401" || envelope.httpStatus == 401 { return .auth }
        if envelope.code == "403" || envelope.httpStatus == 403 { return .denied(envelope.message) }
        if envelope.code == "404" || envelope.httpStatus == 404 { return .gone }
        if envelope.unconfirmed || envelope.netFail { return .failed }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return .missing }
        let result = string(object["runState"]).flatMap(JourneyResult.init(rawValue:))
        let finished = result == .legitimate || result == .assisted || result == .ended
        let value = JourneyReport(legacy: string(object["scopeKind"]) == "LEGACY_TOPIC_SCOPE",
                                  result: result, dateLabel: string(object["dateLabel"]),
                                  nodesText: string(object["nodesText"]), elapsedText: string(object["elapsedText"]),
                                  score: int(object["score"]), rank: int(object["rank"]),
                                  rankBasisCount: int(object["rankBasisCount"]), penaltyText: string(object["penaltyText"]),
                                  rewardItems: int(object["rewardItems"]), runID: string(object["runId"]) ?? scope.runID,
                                  topicID: scope.topicID, activityID: scope.activityID, coverURL: string(object["cover"]),
                                  nodes: (object["nodes"] as? [Any] ?? []).compactMap(node),
                                  finished: finished, inProgress: result == .inProgress)
        return .ready(value)
    }

    static func memory(_ envelope: JourneyEnvelope) -> JourneyMemoryPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed(envelope.message) }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return .empty }
        let participants = int(object["participantCount"])
        if participants == nil { return .empty }
        return .ready(JourneyMemory(participants: participants, moments: []))
    }

    static func rank(_ envelope: JourneyEnvelope) -> JourneyRankPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed(envelope.message) }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return .empty }
        let rows = (object["rows"] as? [Any] ?? object["list"] as? [Any] ?? []).compactMap(rankEntry)
        if rows.isEmpty { return .empty }
        let board = JourneyRankBoard(entries: rows, basis: string(object["scoreBasis"]) == "COMPLETED_NODES" ? .completedNodes : nil,
                                     windowText: string(object["windowText"]), unattributedRuns: int(object["unattributedRuns"]),
                                     stats: [], heroRank: int(object["heroRank"]), topPercent: int(object["topPercent"]))
        return .ready(board)
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

    private static func node(_ value: Any) -> JourneyNodeRow? {
        guard let row = value as? [String: Any] else { return nil }
        let id = string(row["id"]) ?? int(row["id"]).map(String.init)
        guard let id else { return nil }
        let mode = string(row["mode"]).flatMap { raw -> JourneyNodeRow.Mode? in
            if raw == "skipped" { return .skipped }
            if raw == "revealed" { return .revealed }
            return nil
        }
        return JourneyNodeRow(id: id, name: string(row["name"]), mode: mode, score: int(row["score"]))
    }

    private static func rankEntry(_ value: Any) -> JourneyRankEntry? {
        guard let row = value as? [String: Any] else { return nil }
        guard let id = string(row["id"]) ?? int(row["id"]).map(String.init) else { return nil }
        let score = int(row["score"]).map(String.init) ?? "—"
        return JourneyRankEntry(id: id, rank: int(row["rank"]), name: string(row["name"]) ?? string(row["nickname"]),
                                avatarURL: url(string(row["avatar"])), scoreText: score, mine: row["mine"] as? Bool ?? false)
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
