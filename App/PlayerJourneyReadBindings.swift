import SwiftUI

extension MPParityBindings {
    /// Fills the journey closures on an existing bindings value. Purchase and gift claim stay nil.
    /// `passReader` / `viewerIsMerchant` feed the settle 完局优惠卡 (JSETTLE-r7-1); without a reader no card shows.
    @MainActor func fillingPlayerJourneyReads(source: JourneyLoopSource, token: @escaping () -> String?,
                                              passReader: @escaping @MainActor () -> PlatformPass? = { nil },
                                              viewerIsMerchant: @escaping @MainActor () -> Bool = { false }) -> MPParityBindings {
        var copy = self
        copy.journeyLanding = { link in PlayerJourneyLandingModel(link: link, source: source, token: token) }
        copy.journeySeats = { registrationID in PlayerJourneySeatsModel(registrationID: registrationID, source: source, token: token) }
        copy.journeyReport = { scope in PlayerJourneyReportModel(scope: scope, source: source, token: token) }
        copy.journeySettle = { scope in
            PlayerJourneySettleModel(scope: scope, source: source, token: token, passReader: passReader, viewerIsMerchant: viewerIsMerchant)
        }
        copy.journeyPromo = { PlayerJourneyPromoModel(source: source, token: token) }
        return copy
    }
}

extension AppSession {
    func mpParityPlayerReads() -> MPParityBindings {
        let base = mpParityPassBindings().fillingVideoBounty(session: self)
        guard let source = composition.playerJourneySource() else { return base }
        return base.fillingPlayerJourneyReads(source: source, token: { [weak self] in self?.token },
                                              passReader: { [weak self] in self?.makePlatformPassReader() },
                                              viewerIsMerchant: { [weak self] in self?.mpViewerIsMerchant ?? false })
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
        content.sheet(isPresented: $bridge.presented) { Group {
            LoginView(intent: .player).environmentObject(session)
        }.cySheet(detents: [.large]) }
    }
}

@MainActor @Observable final class PlayerJourneyLandingModel: JourneyLandingBinding {
    private(set) var phase: JourneyLandingPhase = .loading
    /// 去看看 pushes the referral target (`pages/activity/detail/index` or `pages/topic/index/index`).
    var route: MPParityRoute?
    private let link: JourneyLandingLink
    private let source: JourneyLoopSource
    private let token: () -> String?
    private var activeMode: String?
    private var target: PlayerJourneyProjection.LandingTarget?

    init(link: JourneyLandingLink, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.link = link
        self.source = source
        self.token = token
    }

    func load() {
        phase = .loading
        Task { await reload() }
    }

    func selectMode(_ key: String) {
        activeMode = key
        guard case .ready(var content) = phase, content.tiles.contains(where: { $0.key == key }) else { return }
        content.activeMode = key
        phase = .ready(content)
    }

    /// JLAND-r7-1: 去看看 opens the target. 自己购买 opens the activity or topic. 进入本局 opens play.
    /// Gift and seat claim buttons stay off while `MPCommerceGate.claimsEnabled` is false.
    /// `giftClaim` still throws `moneyOff` and sends nothing. The request id key is `JourneyRequestKey.giftClaim`.
    func primary() {
        guard case .ready(let content) = phase, let primary = content.primary else { return }
        switch primary {
        case .view:
            guard let target else { return }
            route = PlayerJourneyProjection.targetRoute(target)
        case .buyOwn:
            route = PlayerJourneyProjection.buyOwnRoute(activityID: link.activityID, topicID: link.topicID)
        case .enterRun:
            route = PlayerJourneyProjection.enterRunRoute(activityID: link.activityID, topicID: link.topicID)
        case .claimGift, .claimSeat, .checkClaimResult:
            guard MPCommerceGate.claimsEnabled else { return }
            Task { await claim(primary) }
        }
    }

    /// Classifies a claim envelope with `JourneyLandingClaim`. Gift claim throws before any HTTP.
    private func claim(_ primary: JourneyLandingPrimary) async {
        guard MPCommerceGate.claimsEnabled else { return }
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else { return }
        markClaimBusy(true)
        switch primary {
        case .claimGift, .checkClaimResult:
            let requestID = retainedGiftRequest(token: link.token)
            _ = JourneyGiftClaimBody.fields(token: link.token, requestID: requestID)
            do {
                let envelope = try source.giftClaim(token: link.token, requestID: requestID, sessionToken: session)
                applyClaim(JourneyLandingClaim.gift(envelope, targetID: target.map(\.id)))
            } catch {
                // `moneyOff`: the body was not sent. Keep the request id. Do not draw a claimed gift.
                markClaimBusy(false)
            }
        case .claimSeat:
            do {
                let envelope = try await source.seatClaim(token: link.token, sessionToken: session)
                applyClaim(JourneyLandingClaim.seat(envelope, canBuyOwn: link.activityID != nil || link.topicID != nil))
            } catch {
                markClaimBusy(false)
            }
        case .view, .buyOwn, .enterRun:
            markClaimBusy(false)
        }
    }

    private var retainedGiftKey: String?
    private var retainedGiftRequestID: String?

    /// Same id while the key stays, including an unconfirmed answer. A finished refusal drops it.
    private func retainedGiftRequest(token: String) -> String {
        let key = JourneyRequestKey.giftClaim(token)
        if retainedGiftKey == key, let retainedGiftRequestID, JourneyLoopSource.isRequestID(retainedGiftRequestID) {
            return retainedGiftRequestID
        }
        let made = "g." + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))
        retainedGiftKey = key
        retainedGiftRequestID = made
        return made
    }

    private func markClaimBusy(_ busy: Bool) {
        guard case .ready(var content) = phase else { return }
        content.busy = busy
        phase = .ready(content)
    }

    private func applyClaim(_ follow: JourneyLandingClaim.FollowUp) {
        guard case .ready(var content) = phase else { return }
        content.busy = false
        switch follow {
        case .unconfirmed:
            content.primary = .checkClaimResult
            content.actionError = nil
        case .refused(let message, let buyOwn):
            retainedGiftRequestID = nil
            retainedGiftKey = nil
            content.actionError = message
            content.primary = buyOwn ? .buyOwn : nil
        case .giftClaimed(let canView):
            retainedGiftRequestID = nil
            retainedGiftKey = nil
            content.headline = .giftClaimed
            content.claimDone = true
            content.actionError = nil
            content.primary = canView ? .view : nil
        case .seatClaimed(let seatNo):
            content.headline = .seatClaimed
            content.seatNo = seatNo
            content.claimDone = true
            content.actionError = nil
            content.primary = .enterRun
        }
        phase = .ready(content)
    }

    /// JLAND-2: the referral and gift reads are anonymous on the server (`@Anonymous`), as in the mini-program,
    /// so a signed-out invitee still sees the landing. Choices need a session and are skipped without one.
    private func reload() async {
        let session = token().flatMap { AuthRequestBuilder.isValidToken($0) ? $0 : nil }
        do {
            let envelope: JourneyEnvelope
            switch link.kind {
            case .referral:
                envelope = try await source.referral(token: link.token, sessionToken: session)
            case .gift:
                envelope = try await source.gift(token: link.token, sessionToken: session)
            case .seat:
                // Seat codes have no anonymous read: the page only says what it is; the claim is the server's call.
                var choices: JourneyEnvelope?
                if let session, link.activityID != nil || link.topicID != nil {
                    choices = try? await source.choices(activityID: link.activityID,
                                                        topicID: link.activityID == nil ? link.topicID : nil, token: session)
                }
                let tiles = PlayerJourneyProjection.tiles(choices)
                phase = .ready(JourneyLandingContent(headline: .seat, inviter: nil, title: nil, seatNo: nil, facts: [],
                                                    tiles: tiles, activeMode: PlayerJourneyProjection.activeMode(activeMode, tiles),
                                                    primary: .claimSeat))
                return
            }
            target = PlayerJourneyProjection.landingTarget(kind: link.kind, envelope: envelope)
            // JLAND-3: a referral reads its modes for the read's own target, not the link's aid / tid.
            var choices: JourneyEnvelope?
            if link.kind == .referral, let session, let target = self.target {
                choices = try? await source.choices(activityID: target.isActivity ? target.id : nil,
                                                    topicID: target.isActivity ? nil : target.id, token: session)
            }
            phase = PlayerJourneyProjection.landing(link: link, envelope: envelope, choices: choices, activeMode: activeMode)
        } catch {
            phase = .failed
        }
    }
}

@MainActor @Observable final class PlayerJourneySeatsModel: JourneySeatsBinding {
    private(set) var phase: JourneySeatsPhase = .loading
    /// 去起点 pushes play; 编辑 pushes the own-profile editor (`pages/gerenziliao/gerenziliao`).
    var route: MPParityRoute?
    private let registrationID: String
    private let source: JourneyLoopSource
    private let token: () -> String?
    private var inviteURL: URL?
    /// JSEAT-r7-1: `invitationId` + `token`, not only the URL. `afterRead` drops it once that seat is no longer INVITED.
    private var heldInvite: JourneyHeldSeatInvite?
    private var lastSeats: JourneyEnvelope?
    private var facts: PlayerJourneyProjection.SeatsFacts?
    /// JSEAT-5 extras: topic head, play-mode tiles and the buyer's own name / avatar. A failed read hides only its block.
    private var head: PlayerJourneyProjection.TopicHead?
    private var tiles: [JourneyModeTile] = []
    private var me: JourneyPerson?
    private var extrasRead = false

    init(registrationID: String, source: JourneyLoopSource, token: @escaping () -> String?) {
        self.registrationID = registrationID
        self.source = source
        self.token = token
    }

    func load() {
        if phase.content == nil { phase = .loading }
        Task { await reload() }
    }

    func requestInvite() {
        Task { await invite() }
    }

    func cancelInvitation(_ id: String) {
        Task { await cancel(id) }
    }

    /// JSEAT-3, mini-program `lobby-view.playUrl`: the original activity / topic plus this registration. Play still
    /// checks admission with the server.
    func goToStart() {
        guard let facts = self.facts, let next = PlayerJourneyProjection.playRoute(facts) else { return }
        route = next
    }

    func editMe() {
        Task { _ = await AccountPublishContractLane.profileEditor() }
        route = MPParityRoute(miniProgramPath: "pages/gerenziliao/gerenziliao", query: [:])
    }

    private func reload() async {
        let session = token().flatMap { AuthRequestBuilder.isValidToken($0) ? $0 : nil }
        // JSEAT-6: no valid token is `.auth` (登录). 403 stays `.denied`. Every other non-OK is `.failed`.
        guard let session else {
            phase = seatsPhase(JourneySeatsSessionGate.phase(hasValidSession: false, envelope: nil), envelope: nil)
            return
        }
        do {
            let seats = try await source.seats(registrationID: registrationID, token: session)
            let gate = JourneySeatsSessionGate.phase(hasValidSession: true, envelope: seats)
            guard gate == .ready else {
                phase = seatsPhase(gate, envelope: seats)
                return
            }
            lastSeats = seats
            facts = PlayerJourneyProjection.seatsFacts(seats)
            heldInvite = JourneyHeldSeatInviteRule.afterRead(hold: heldInvite, seats: PlayerJourneyProjection.heldSeatRows(seats))
            if heldInvite == nil { inviteURL = nil }
            render(actionError: nil)
            if case .ready = phase, !extrasRead, let facts = self.facts {
                extrasRead = true
                await loadExtras(facts, session: session)
                render(actionError: phase.content?.actionError)
            }
        } catch JourneyRefusal.invalidRequest {
            phase = .missing
        } catch {
            phase = .failed
        }
    }

    private func seatsPhase(_ gate: JourneySeatsSessionGate.Phase, envelope: JourneyEnvelope?) -> JourneySeatsPhase {
        switch gate {
        case .auth: return .auth
        case .denied: return .denied(envelope?.message)
        case .failed: return .failed
        case .ready: return .failed
        }
    }

    private func loadExtras(_ facts: PlayerJourneyProjection.SeatsFacts, session: String) async {
        if let topic = facts.topicID {
            if let info = try? await source.topicInfo(id: topic, token: session) {
                head = PlayerJourneyProjection.topicHead(info)
            }
            let activity = facts.ownerType == 2 ? facts.ownerID : nil
            if let choices = try? await source.choices(activityID: activity, topicID: activity == nil ? topic : nil, token: session) {
                tiles = PlayerJourneyProjection.tiles(choices)
            }
        }
        if let profile = try? await source.playerProfile(token: session) {
            me = PlayerJourneyProjection.person(profile)
        }
    }

    private func render(actionError: String?) {
        guard let lastSeats = self.lastSeats else { return }
        let next = PlayerJourneyProjection.seats(lastSeats, choices: nil, registrationID: registrationID, me: me)
        guard case .ready(var content) = next else {
            phase = next
            return
        }
        content.headName = head?.name
        content.headCoverURL = head?.coverURL
        content.tiles = tiles
        heldInvite = JourneyHeldSeatInviteRule.afterRead(hold: heldInvite, seats: PlayerJourneyProjection.inviteSeats(lastSeats))
        if heldInvite == nil { inviteURL = nil }
        content.inviteShareURL = inviteURL
        content.actionError = actionError
        phase = .ready(content)
    }

    private func invite() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else { return }
        do {
            let envelope = try await source.seatInvite(registrationID: registrationID, token: session)
            applyWrite(envelope, invite: true)
        } catch {
            applyWrite(nil, invite: true)
        }
    }

    private func cancel(_ id: String) async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else { return }
        do {
            let envelope = try await source.seatCancel(invitationID: id, token: session)
            applyWrite(envelope, invite: false)
        } catch {
            applyWrite(nil, invite: false)
        }
    }

    /// A confirmed answer refreshes the lobby. An unknown answer keeps the saved request id and does not draw success.
    /// JSEAT-4: the invite answer carries `token`; the shared link is the seat landing built from it (`k=s&t=` + aid / tid).
    private func applyWrite(_ envelope: JourneyEnvelope?, invite: Bool) {
        guard var content = phase.content else { return }
        if let envelope, envelope.ok, !envelope.unconfirmed {
            if invite {
                heldInvite = PlayerJourneyProjection.seatInviteHold(envelope)
                inviteURL = heldInvite == nil ? nil : facts.flatMap { PlayerJourneyProjection.seatInviteURL(envelope, facts: $0) }
                guard heldInvite != nil, inviteURL != nil else {
                    heldInvite = nil
                    inviteURL = nil
                    content.inviteShareURL = nil
                    // MP seats index.js:125: an OK answer without a token reads 邀请失败.
                    content.actionError = appLocalized("mp.seats.invite.failed", locale: .current)
                    phase = .ready(content)
                    return
                }
            }
            content.actionError = nil
            content.inviteShareURL = inviteURL
            phase = .ready(content)
            load()
            return
        }
        if invite { inviteURL = nil; heldInvite = nil }
        content.inviteShareURL = inviteURL
        // JSEAT-7: an unknown answer (sent, result not read back) says so instead of a network error.
        if let envelope, envelope.unconfirmed {
            content.actionError = appLocalized("mp.seats.unconfirmed", locale: .current)
        } else if let envelope {
            // MP seats index.js:125 / :143: the server message, else 邀请失败 / 撤销失败.
            let message = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            content.actionError = message.isEmpty
                ? appLocalized(invite ? "mp.seats.invite.failed" : "mp.seats.cancel.failed", locale: .current) : message
        } else {
            content.actionError = JourneyEnvelope.networkFailure.message
        }
        phase = .ready(content)
    }
}

@MainActor @Observable final class PlayerJourneyReportModel: JourneyReportBinding {
    private(set) var phase: JourneyReportPhase = .loading
    private(set) var memory: JourneyMemoryPhase = .idle
    private(set) var rank = JourneyRankState()
    private(set) var feedback: JourneyFeedbackState = .editing(nil)
    /// JREPORT-1: set once the report is ready (topic link; the referral token stays a money write, see `PlayerJourneyShare`).
    private(set) var shareURL: URL?
    /// `var`: JREPORT-3 fills `teamID` from choices after the report is ready.
    private var scope: JourneyRunScope
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
        rank.more = PlayerJourneyProjection.rankMore(scope)
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
            phase = PlayerJourneyProjection.report(envelope, scope: scope, surface: .report)
        } catch {
            phase = .failed
        }
        if case .ready(let report) = phase {
            shareURL = PlayerJourneyShare.url(report: report, scope: scope, source: source, token: session)
            let rankBefore = rank.scope
            var rankMenu = rank
            await installJourneyRankMenu(&rankMenu, scope: scope, source: source, session: session, settle: false)
            rank = rankMenu
            if rank.scope != rankBefore { loadRank() }
        }
        if case .ready(let report) = phase, !report.legacy, !teamsProbed {
            teamsProbed = true
            await loadTeamFromChoices(session)
            await probeTeams(session)
        }
    }

    /// JREPORT-3 (MP report `_loadTeam`): a link without `teamId` reads choices; the first `teamCapacity.teamId`
    /// (Core `JourneyRankBoardContract.teamID`) opens 队内. A failed read changes nothing.
    private func loadTeamFromChoices(_ session: String) async {
        guard scope.teamID == nil, scope.activityID != nil || scope.topicID != nil,
              let envelope = try? await source.choices(activityID: scope.activityID,
                                                       topicID: scope.activityID == nil ? scope.topicID : nil, token: session),
              envelope.ok, let team = JourneyRankBoardContract.teamID(choicesJSON: envelope.dataJSON) else { return }
        scope.teamID = team
        let tabs = PlayerJourneyProjection.rankTabs(scope)
        let extra = rank.tabs.filter { !tabs.contains($0) }
        rank.tabs = tabs + extra
        if rank.scope == nil { rank.scope = rank.tabs.first }
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
    /// One settle-rating intent. Cleared only after a confirmed write so a retry reuses it.
    private var rateRequestID: String?
    /// L09-059: the accepted rating, and the last draft sent (a different draft drops the kept request id).
    @ObservationIgnored private var rated = false
    @ObservationIgnored private var lastRateDraft: (stars: Int, text: String)?
    /// JSETTLE-1: set once the run is ready, so the share step always has 分享 (topic link fallback).
    private(set) var shareURL: URL?
    private(set) var topicName: String?
    /// JSETTLE-r7-1 (MP settle `_loadOffer`, finish-offer.js): one read per page; nil hides the card.
    private(set) var finishOffer: JourneyFinishOffer?
    private var offerAsked = false
    private let scope: JourneyRunScope
    private let source: JourneyLoopSource
    private let token: () -> String?
    private let passReader: @MainActor () -> PlatformPass?
    private let viewerIsMerchant: @MainActor () -> Bool

    init(scope: JourneyRunScope, source: JourneyLoopSource, token: @escaping () -> String?,
         passReader: @escaping @MainActor () -> PlatformPass? = { nil },
         viewerIsMerchant: @escaping @MainActor () -> Bool = { false }) {
        self.scope = scope
        self.source = source
        self.token = token
        self.passReader = passReader
        self.viewerIsMerchant = viewerIsMerchant
        topicName = scope.topicName
        // Settle preset (mini-program rank-board `preset="settle"`): 全体 + 队内, no "more" (JSETTLE-5).
        rank.tabs = PlayerJourneyProjection.rankTabs(scope).filter { $0.kind == .quest || $0.kind == .team }
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
            switch PlayerJourneyProjection.report(envelope, scope: scope, surface: .settle) {
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
        guard case .ready(let report) = phase else { return }
        shareURL = PlayerJourneyShare.url(report: report, scope: scope, source: source, token: session)
        let rankBefore = rank.scope
        var rankMenu = rank
        await installJourneyRankMenu(&rankMenu, scope: scope, source: source, session: session, settle: true)
        rank = rankMenu
        if rank.scope != rankBefore { loadRank() }
        await loadFinishOffer(topicID: report.topicID ?? scope.topicID, session: session)
        // JSETTLE-3: a link without `topicName` reads it, so the overview and card do not fall back to 本局.
        if topicName == nil, let topic = report.topicID ?? scope.topicID, JourneyLoopSource.isID(topic),
           let info = try? await source.topicInfo(id: topic, token: session),
           let name = PlayerJourneyProjection.topicHead(info)?.name, topicName == nil {
            topicName = name
        }
    }

    /// JSETTLE-r7-1: GET `/api/platform-pass` + GET `/api/marketing/product/list` (both read-only), resolved by Core
    /// `JourneyFinishOfferResolver`. A merchant viewer asks nothing; a failed read counts as "none" (MP `facts`).
    private func loadFinishOffer(topicID: String?, session: String) async {
        guard !offerAsked, !viewerIsMerchant(), let reader = passReader() else { return }
        offerAsked = true
        async let overviewRead = try? reader.overview(token: session, viewerIsMerchant: false)
        async let productsRead = try? reader.productList(token: session)
        let overview = await overviewRead
        let products = await productsRead ?? []
        let pass = overview.map { ov -> JourneyFinishOfferPassInput in
            let month = ov.plans.first { $0.code == "MONTH" && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.priceFen > 0 }
            return JourneyFinishOfferPassInput(enabled: ov.enabled, holdingActive: ov.holding.active, libraryCount: ov.libraryCount ?? 0,
                                               monthPlanTitle: month?.title, monthPlanPriceFen: month?.priceFen)
        }
        let rows = products.compactMap { p -> JourneyFinishOfferProductInput? in
            guard let id = Int(p.id) else { return nil }
            return JourneyFinishOfferProductInput(productID: id, productKind: p.productKind, productName: p.name,
                                                  cashPrice: p.cashPrice, pointsPrice: p.pointsPrice.map { Int($0) },
                                                  coveredTopicIDs: p.topicIDs.compactMap { Int($0) })
        }
        finishOffer = JourneyFinishOfferResolver.resolve(isMerchantView: false, pass: pass, products: rows,
                                                         currentTopicID: topicID.flatMap { Int($0) })
    }

    private var readyReport: JourneyReport? {
        if case .ready(let report) = phase { return report }
        return nil
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
        // MP settle L09-059: once this run's rating is accepted, 提交 again shows thanks and sends nothing;
        // a changed draft after a failed submit is a new intent and gets a new request_id.
        if rated { rate = .thanks; return }
        if let last = lastRateDraft, last.stars != stars || last.text != text { rateRequestID = nil }
        lastRateDraft = (stars, text)
        // JSETTLE-2, mini-program settle `submitRate`: owner type 2 + the activity id when the run has an activity,
        // else owner type 1 + the topic id. A run id is never an owner.
        guard let owner = PlayerJourneyProjection.ratingOwner(report: readyReport, scope: scope) else {
            rate = .error(appLocalized("mp.settle.rate.unavailable", locale: .current))
            return
        }
        guard (1...5).contains(stars), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            rate = .error(MPText.unknown)
            return
        }
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            rate = .error(MPText.unknown)
            return
        }
        let requestID = ratingRequestID()
        do {
            let envelope = try await source.rate(ownerType: owner.type, ownerID: owner.id, rating: stars, contents: text, requestID: requestID, token: session)
            if envelope.ok, !envelope.unconfirmed {
                rateRequestID = nil
                rated = true
                rate = .thanks
            } else if envelope.netFail {
                rate = .error(appLocalized("mp.settle.rate.netKept", locale: .current))
            } else {
                // MP settle index.js:212: the server text, else 评价暂时无法提交.
                let message = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                rate = .error(message.isEmpty ? appLocalized("mp.settle.rate.failed", locale: .current) : message)
            }
        } catch {
            rate = .error(appLocalized("mp.settle.rate.netKept", locale: .current))
        }
    }

    private func ratingRequestID() -> String {
        if let saved = rateRequestID, JourneyLoopSource.isCommentRequestID(saved) { return saved }
        let made = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        rateRequestID = made
        return made
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
/// JREPORT-3: choices `teamId` wins over the link. Settle keeps 全体 + 队内 and no 更多.
private func installJourneyRankMenu(_ rank: inout JourneyRankState, scope: JourneyRunScope, source: JourneyLoopSource,
                                    session: String, settle: Bool) async {
    let activity = scope.activityID.flatMap { JourneyLoopSource.isID($0) ? $0 : nil }
    let topic = scope.topicID.flatMap { JourneyLoopSource.isID($0) ? $0 : nil }
    let choices: JourneyEnvelope?
    if activity != nil || topic != nil {
        choices = try? await source.choices(activityID: activity, topicID: activity == nil ? topic : nil, token: session)
    } else {
        choices = nil
    }
    let team = JourneyRankBoardContract.teamID(choicesJSON: choices?.dataJSON) ?? scope.teamID
    let menu = PlayerJourneyProjection.rankMenu(scope, teamID: team)
    let keepTeams = !settle && rank.tabs.contains { $0.kind == .teams }
    var tabs = settle ? menu.tabs.filter { $0.kind == .quest || $0.kind == .team } : menu.tabs
    if keepTeams, !tabs.contains(where: { $0.kind == .teams }) { tabs.append(JourneyRankScope(kind: .teams)) }
    rank.tabs = tabs
    rank.more = settle ? [] : menu.more
    let shown = rank.tabs + rank.more
    if let current = rank.scope, let match = shown.first(where: { $0.kind == current.kind }) {
        rank.scope = match
    } else {
        rank.scope = shown.first
    }
}

private func playerJourneyRank(selected: JourneyRankScope, run: JourneyRunScope, period: JourneyRankPeriod,
                               source: JourneyLoopSource, token: String) async -> JourneyRankPhase {
    do {
        switch selected.kind {
        case .teams:
            guard let envelope = try await playerJourneyTeams(run: run, source: source, token: token) else { return .empty }
            return PlayerJourneyProjection.teams(envelope)
        case .world:
            let envelope = try await source.rank(scope: "world", scopeID: nil, period: period.rawValue, token: token)
            return PlayerJourneyProjection.rank(envelope, scope: "world", scopeID: nil, period: period.rawValue)
        case .quest, .team, .city, .country, .club:
            // JREPORT-3: `scope` + `scopeId` + `period` only. City, country and club use the menu's scope id.
            guard JourneyLoopSource.isID(selected.scopeID) else { return .empty }
            let name = selected.kind.rawValue
            let envelope = try await source.rank(scope: name, scopeID: selected.scopeID, period: period.rawValue, token: token)
            return PlayerJourneyProjection.rank(envelope, scope: name, scopeID: selected.scopeID, period: period.rawValue)
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
    /// JREPORT-3: 本关 / 队内 from `JourneyRankBoardContract.menu`. The team id prefers the choices read.
    static func rankTabs(_ run: JourneyRunScope, teamID: String? = nil) -> [JourneyRankScope] {
        rankMenu(run, teamID: teamID).tabs
    }

    static func rankMore(_ run: JourneyRunScope, teamID: String? = nil) -> [JourneyRankScope] {
        rankMenu(run, teamID: teamID).more
    }

    static func rankMenu(_ run: JourneyRunScope, teamID: String? = nil) -> (tabs: [JourneyRankScope], more: [JourneyRankScope]) {
        let menu = JourneyRankBoardContract.menu(topicID: run.topicID, cityCode: run.cityCode, countryCode: run.countryCode,
                                                 clubID: run.clubID, teamID: teamID ?? run.teamID)
        return (menu.tabs.map { JourneyRankScope($0) }, menu.more.map { JourneyRankScope($0) })
    }

    static func buyOwnRoute(activityID: String?, topicID: String?) -> MPParityRoute? {
        if let activityID, JourneyLoopSource.isID(activityID) {
            return MPParityRoute(miniProgramPath: "pages/activity/detail/index", query: ["id": activityID])
        }
        if let topicID, JourneyLoopSource.isID(topicID) {
            return MPParityRoute(miniProgramPath: "pages/topic/index/index", query: ["id": topicID])
        }
        return nil
    }

    static func enterRunRoute(activityID: String?, topicID: String?) -> MPParityRoute? {
        var query: [String: String] = [:]
        if let activityID, JourneyLoopSource.isID(activityID) { query["activityId"] = activityID }
        if let topicID, JourneyLoopSource.isID(topicID) { query["topicId"] = topicID }
        guard !query.isEmpty else { return nil }
        return MPParityRoute(miniProgramPath: "pages/play/index", query: query)
    }

    static func landing(link: JourneyLandingLink, envelope: JourneyEnvelope, choices: JourneyEnvelope?, activeMode: String?) -> JourneyLandingPhase {
        if envelope.unconfirmed || envelope.netFail { return .failed }
        if envelope.code == "401" || envelope.httpStatus == 401 { return .failed }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else {
            if envelope.code == "404" || envelope.httpStatus == 404 { return .missing }
            return .failed
        }
        // JLAND-4: field paths per `journey-view.js` `referralView` / `giftView`.
        let state = string(object["state"])
        guard state == "VALID" else {
            return .invalid(reason: landingStateText(kind: link.kind, state: state), success: link.kind == .gift && state == "CLAIMED")
        }
        switch link.kind {
        case .referral:
            let inviter = object["inviter"] as? [String: Any]
            let person = string(inviter?["nickname"]).map { JourneyPerson(name: $0, avatarURL: url(string(inviter?["avatar"]))) }
            let target = object["target"] as? [String: Any]
            var facts: [JourneyFact] = []
            if let expires = timeText(object["expiresAt"]) { facts.append(JourneyFact(kind: .inviteValid, value: expires)) }
            if string(object["registrationState"]) == "CLOSED" { facts.append(JourneyFact(kind: .signupClosed, value: "")) }
            // JLAND-1: 去看看 only when the server allows viewing the target and the target id is real.
            let canView = string(object["nextAction"]) == "VIEW_TARGET" && landingTarget(kind: .referral, envelope: envelope) != nil
            let modes = tiles(choices)
            return .ready(JourneyLandingContent(headline: .referral, inviter: person, title: string(target?["title"]), seatNo: nil,
                                                facts: facts, tiles: modes, activeMode: self.activeMode(activeMode, modes),
                                                primary: canView ? .view : nil))
        case .gift:
            let product = object["product"] as? [String: Any]
            var facts: [JourneyFact] = []
            if let claimBy = timeText(object["claimExpiresAt"]) { facts.append(JourneyFact(kind: .claimBy, value: claimBy)) }
            return .ready(JourneyLandingContent(headline: .gift, inviter: nil,
                                                title: string(product?["topicTitle"]) ?? string(product?["productName"]), seatNo: nil,
                                                facts: facts, tiles: [], activeMode: nil,
                                                primary: string(object["nextAction"]) == "CLAIM_GIFT" ? .claimGift : nil))
        case .seat:
            let modes = tiles(choices)
            return .ready(JourneyLandingContent(headline: .seat, inviter: nil, title: nil, seatNo: nil, facts: [], tiles: modes,
                                                activeMode: self.activeMode(activeMode, modes), primary: .claimSeat))
        }
    }

    /// Referral `target {type, id}` (type 2 = activity, else topic); gift `product.topicId` (a topic).
    struct LandingTarget: Equatable {
        let isActivity: Bool
        let id: String
    }

    static func landingTarget(kind: JourneyLandingLink.Kind, envelope: JourneyEnvelope) -> LandingTarget? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON), string(object["state"]) == "VALID" else { return nil }
        switch kind {
        case .referral:
            guard let target = object["target"] as? [String: Any], let id = idText(target["id"]) else { return nil }
            return LandingTarget(isActivity: int(target["type"]) == 2, id: id)
        case .gift:
            guard let product = object["product"] as? [String: Any], let id = idText(product["topicId"]) else { return nil }
            return LandingTarget(isActivity: false, id: id)
        case .seat:
            return nil
        }
    }

    /// Mini-program `_goTarget`: activity detail for type 2, else the topic page.
    static func targetRoute(_ target: LandingTarget) -> MPParityRoute? {
        MPParityRoute(miniProgramPath: target.isActivity ? "pages/activity/detail/index" : "pages/topic/index/index", query: ["id": target.id])
    }

    /// JLAND-5: plain-language state sentence per kind, never the raw server code.
    static func landingStateText(kind: JourneyLandingLink.Kind, state: String?) -> String {
        if kind == .gift {
            switch state {
            case "TOKEN_EXPIRED": return appLocalized("mp.landing.state.giftLinkExpired", locale: .current)
            case "CLAIMED": return appLocalized("mp.landing.state.giftClaimed", locale: .current)
            case "GIFT_EXPIRED": return appLocalized("mp.landing.state.giftExpired", locale: .current)
            case "GIFT_REVOKED": return appLocalized("mp.landing.state.giftRevoked", locale: .current)
            case "PRODUCT_UNAVAILABLE": return appLocalized("mp.landing.state.giftProductUnavailable", locale: .current)
            default: return appLocalized("mp.landing.state.giftInvalid", locale: .current)
            }
        }
        switch state {
        case "TOKEN_EXPIRED": return appLocalized("mp.landing.state.inviteExpired", locale: .current)
        case "TOKEN_REVOKED": return appLocalized("mp.landing.state.inviteRevoked", locale: .current)
        case "TARGET_UNAVAILABLE": return appLocalized("mp.landing.state.targetUnavailable", locale: .current)
        case "INVITER_UNAVAILABLE": return appLocalized("mp.landing.state.inviterUnavailable", locale: .current)
        default: return appLocalized("mp.landing.state.inviteInvalid", locale: .current)
        }
    }

    /// Selected mode, else the first available tile, else the first tile (`join-view.modeTiles` `active`).
    static func activeMode(_ selected: String?, _ tiles: [JourneyModeTile]) -> String? {
        if let selected, tiles.contains(where: { $0.key == selected }) { return selected }
        return (tiles.first(where: \.available) ?? tiles.first)?.key
    }

    /// Facts the lobby needs beyond the drawn content (mini-program `seatsView` owner / topic / registration).
    struct SeatsFacts: Equatable {
        let registrationID: String?
        let topicID: String?
        let ownerType: Int?
        let ownerID: String?
    }

    static func seatsFacts(_ envelope: JourneyEnvelope) -> SeatsFacts? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return nil }
        return SeatsFacts(registrationID: idText(object["registrationId"]), topicID: idText(object["topicId"]),
                          ownerType: int(object["ownerType"]), ownerID: idText(object["ownerId"]))
    }

    /// Mini-program `lobby-view.playUrl`: needs the topic; an activity ticket (owner type 2) also carries the activity.
    static func playRoute(_ facts: SeatsFacts) -> MPParityRoute? {
        guard let topic = facts.topicID else { return nil }
        var query = ["topicId": topic]
        if facts.ownerType == 2, let activity = facts.ownerID { query["activityId"] = activity }
        if let registration = facts.registrationID { query["registrationId"] = registration }
        return MPParityRoute(miniProgramPath: "pages/play/index", query: query)
    }

    /// JSEAT-4: the seat invite answer's `token` as the landing link (`k=s&t=`, `aid` for an activity ticket, `tid`).
    static func seatInviteURL(_ envelope: JourneyEnvelope, facts: SeatsFacts) -> URL? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON), let token = string(object["token"]) else { return nil }
        let activity = facts.ownerType == 2 ? facts.ownerID.flatMap(Int.init) : nil
        let intake = JourneyLinkIntake(kind: .seat, token: token, activityID: activity, topicID: facts.topicID.flatMap(Int.init))
        return PublicContentShareLink.journeyLanding(intake)
    }

    /// JSEAT-r7-1: both `invitationId` and `token`, or no hold.
    static func seatInviteHold(_ envelope: JourneyEnvelope) -> JourneyHeldSeatInvite? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return nil }
        return JourneyHeldSeatInviteRule.hold(invitationID: idText(object["invitationId"]), token: string(object["token"]))
    }

    static func inviteSeats(_ envelope: JourneyEnvelope) -> [JourneyHeldSeatInviteRule.Seat] {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return [] }
        let rows = object["seats"] as? [Any] ?? []
        return rows.compactMap { item in
            guard let row = item as? [String: Any], let id = idText(row["invitationId"]), let state = string(row["state"]) else { return nil }
            return JourneyHeldSeatInviteRule.Seat(invitationID: id, state: state)
        }
    }

    static func seatInviteToken(_ envelope: JourneyEnvelope) -> String? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return nil }
        return string(object["token"])
    }

    /// JSEAT-r7-1: each seat row's `invitationId` + upper-case `state`, for `JourneyHeldSeatInviteRule.afterRead`.
    static func heldSeatRows(_ envelope: JourneyEnvelope) -> [JourneyHeldSeatInviteRule.Seat] {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return [] }
        return (object["seats"] as? [Any] ?? []).compactMap { item in
            guard let row = item as? [String: Any], let id = idText(row["invitationId"]), let state = string(row["state"]) else { return nil }
            return JourneyHeldSeatInviteRule.Seat(invitationID: id, state: state)
        }
    }

    /// `/api/topic/info-to-user`: name and the first cover image. A relative cover path is not drawn (no host to resolve it).
    struct TopicHead: Equatable {
        let name: String
        let coverURL: String?
    }

    static func topicHead(_ envelope: JourneyEnvelope) -> TopicHead? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON), let name = string(object["name"]) else { return nil }
        let first = (string(object["imgUrl"]) ?? string(object["imgArr"]))?
            .split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return TopicHead(name: name, coverURL: url(first)?.absoluteString)
    }

    /// JSEAT-1 / JSEAT-2: port of `journey-view.seatsView` + `lobby-view.lobbyView`. Seat states arrive upper-case.
    static func seats(_ envelope: JourneyEnvelope, choices: JourneyEnvelope?, registrationID: String, me: JourneyPerson? = nil) -> JourneySeatsPhase {
        _ = registrationID
        if envelope.code == "401" || envelope.httpStatus == 401 { return .auth }
        if envelope.code == "403" || envelope.httpStatus == 403 { return .denied(envelope.message) }
        if envelope.unconfirmed || envelope.netFail { return .failed }
        if envelope.code == "404" || envelope.httpStatus == 404 { return .missing }
        guard envelope.ok, let object = jsonObject(envelope.dataJSON) else { return .failed }
        let free = int(object["freeSeats"])
        let canInvite = object["buyerIsCaller"] as? Bool == true && object["readOnly"] as? Bool == false && (free ?? 0) > 0
        let cancelSupported = object["seatCancelSupported"] as? Bool == true
        let rows = (object["seats"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
        var circles: [JourneySeatCircle] = []
        var invited: [JourneyInvitedRow] = []
        for row in rows {
            guard let no = int(row["seatNo"]), let kind = seatKind(string(row["state"])) else { continue }
            circles.append(JourneySeatCircle(no: no, kind: kind, avatarURL: kind == .me ? me?.avatarURL : nil,
                                             initial: kind == .me ? me.flatMap { $0.initial.isEmpty ? nil : $0.initial } : nil,
                                             tappable: kind == .open && canInvite))
            // The invited list: waiting seats and taken (claimed / checked-in / reserved) seats, never the buyer's own.
            guard kind == .invited || kind == .claimed || kind == .verified || kind == .reserved else { continue }
            let invitation = idText(row["invitationId"])
            invited.append(JourneyInvitedRow(invitationID: invitation ?? "seat-\(no)", no: no, kind: kind,
                                             expiresText: kind == .invited ? timeText(row["invitationExpiresAt"]) : nil,
                                             canCancel: kind == .invited && cancelSupported && invitation != nil))
        }
        let count = int(object["seatCount"])
        let taken = circles.filter { [.me, .verified, .claimed, .reserved].contains($0.kind) }.count
        let content = JourneySeatsContent(headName: nil, headCoverURL: nil,
                                          me: me,
                                          showsParty: (count ?? 0) > 1,
                                          occupied: count == nil ? nil : taken, seatCount: count, circles: circles,
                                          canInvite: canInvite,
                                          openCount: circles.filter { $0.kind == .open }.count, invited: invited,
                                          multi: (count ?? 0) > 1,
                                          tiles: tiles(choices), canGoToStart: idText(object["topicId"]) != nil,
                                          actionError: nil, inviteShareURL: nil)
        return .ready(content)
    }

    private static func seatKind(_ state: String?) -> JourneySeatKind? {
        switch state {
        case "BUYER": return .me
        case "VERIFIED": return .verified
        case "RESERVED": return .reserved
        case "AVAILABLE": return .open
        case "EXPIRED": return .expired
        case "INVITED": return .invited
        case "CLAIMED": return .claimed
        default: return nil
        }
    }

    /// JSETTLE-2: owner type 2 + activity id when the run has an activity, else 1 + topic id; nil when neither is an id.
    static func ratingOwner(report: JourneyReport?, scope: JourneyRunScope) -> (type: Int, id: String)? {
        if let activity = report?.activityID ?? scope.activityID, JourneyLoopSource.isID(activity) { return (2, activity) }
        if let topic = report?.topicID ?? scope.topicID, JourneyLoopSource.isID(topic) { return (1, topic) }
        return nil
    }

    /// U08-01: real `PlayerRunReportVO` fields through `PostGameRunReport` (mini-program `reportView`).
    /// An explicit run that comes back as another run is not shown as this one.
    /// JREPORT-5: `JourneyReportRead.reject`. A 404 without a gone reason is `.failed`, not a dead link.
    /// An undecodable OK body is `.failed`. `runDisagrees` is gone on both surfaces.
    static func report(_ envelope: JourneyEnvelope, scope: JourneyRunScope, surface: JourneyReportRead.Surface = .report) -> JourneyReportPhase {
        if let disposition = JourneyReportRead.reject(envelope, surface: surface), case .auth = disposition { return .auth }
        let fact = PostGameRunReport.decode(envelope.dataJSON)
        if JourneyReportRead.runDisagrees(asked: scope.runID, answered: fact?.runID) { return .gone }
        if let disposition = JourneyReportRead.reject(envelope, surface: surface) {
            switch disposition {
            case .auth: return .auth
            case .gone: return .gone
            case .denied(let message): return .denied(message)
            case .failed: return .failed
            }
        }
        guard let fact else { return .failed }
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
                                                     score: node.score, photoURL: node.photoURL)
                                  },
                                  finished: fact.finished, inProgress: fact.inProgress,
                                  assistedCount: fact.assistedCount, startModeText: fact.startModeText)
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

    /// JLAND-3: port of `join-view.modeTiles` over `journey-view.choicesView`. Keys are the server's
    /// `SHARED_TEAM` / `INDEPENDENT`; `competition` makes an independent mode 各自比. An unavailable or missing run
    /// config draws no block at all.
    static func tiles(_ envelope: JourneyEnvelope?) -> [JourneyModeTile] {
        guard let envelope, envelope.ok, let object = jsonObject(envelope.dataJSON) else { return [] }
        let config = string(object["configState"])
        guard config != "UNAVAILABLE", config != "RUN_CONFIG_SNAPSHOT_MISSING",
              let rows = (object["choices"] as? [Any])?.compactMap({ $0 as? [String: Any] }), !rows.isEmpty else { return [] }
        return rows.enumerated().map { index, row -> JourneyModeTile in
            let key = string(row["key"]) ?? "mode-\(index)"
            let team = key == "SHARED_TEAM"
            let compete = !team && row["competition"] as? Bool == true
            let scoreScope = string(row["scoreScope"]).flatMap(JourneyScopeText.init(rawValue:))
            let sub: JourneyModeTile.Sub? = team && scoreScope == .perTeam ? .teamScore : (compete ? .rankAfter : nil)
            var rules: [JourneyModeRule] = []
            let scoped: [(JourneyModeRule.Kind, String)] = [(.hint, "hintScope"), (.progress, "progressScope"), (.score, "scoreScope")]
            for (kind, field) in scoped {
                guard let scope = string(row[field]).flatMap(JourneyScopeText.init(rawValue:)) else { continue }
                rules.append(JourneyModeRule(kind: kind, scope: scope, teamText: nil, on: scope != .perMember))
            }
            if team, let capacity = row["teamCapacity"] as? [String: Any],
               let joined = int(capacity["joinedCount"]), let max = int(capacity["maxMembers"]) {
                rules.append(JourneyModeRule(kind: .team, scope: nil, teamText: "\(joined)/\(max)", on: true))
            }
            let available = row["available"] as? Bool == true
            return JourneyModeTile(key: key, name: team ? .together : (compete ? .compete : .solo), sub: sub,
                                   reason: available ? nil : unavailableText(string(row["unavailableReason"])),
                                   available: available, rules: rules)
        }
    }

    private static func unavailableText(_ reason: String?) -> String {
        switch reason {
        case "TEAM_MODE_DISABLED": return appLocalized("mp.journey.unavailable.teamOff", locale: .current)
        case "RUN_CONFIG_SNAPSHOT_MISSING": return appLocalized("mp.journey.unavailable.noSnapshot", locale: .current)
        default: return appLocalized("mp.journey.unavailable.generic", locale: .current)
        }
    }

    /// Positive id from a JSON number or a canonical digit string.
    private static func idText(_ value: Any?) -> String? {
        if let number = int(value) { return number > 0 ? String(number) : nil }
        guard let text = value as? String, JourneyLoopSource.isID(text) else { return nil }
        return text
    }

    /// Mini-program `dateText(value, true)`: Beijing `yyyy.MM.dd HH:mm` from epoch millis, `yyyy-MM-dd HH:mm[:ss]`
    /// (Beijing) or ISO 8601. Unreadable values hide the fact instead of printing the raw server text.
    static func timeText(_ value: Any?) -> String? {
        let date: Date?
        if let millis = int(value) {
            date = Date(timeIntervalSince1970: Double(millis) / 1000)
        } else if let text = string(value) {
            let plain = DateFormatter()
            plain.locale = Locale(identifier: "en_US_POSIX")
            plain.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
            var parsed: Date?
            for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss"] where parsed == nil {
                plain.dateFormat = format
                parsed = plain.date(from: text)
            }
            if parsed == nil {
                let iso = ISO8601DateFormatter()
                parsed = iso.date(from: text)
                if parsed == nil {
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    parsed = iso.date(from: text)
                }
            }
            date = parsed
        } else {
            date = nil
        }
        guard let date else { return nil }
        return PostGameText.beijingDay(date) + " " + PostGameText.beijingClock(date)
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

    /// An issued referral answer's `token` as the landing link (mini-program settle `landingPath`: `k=r&t=` only).
    static func referralLandingURL(_ envelope: JourneyEnvelope) -> URL? {
        guard envelope.ok, let object = jsonObject(envelope.dataJSON), let token = string(object["token"]) else { return nil }
        return PublicContentShareLink.journeyLanding(JourneyLinkIntake(kind: .referral, token: token, activityID: nil, topicID: nil))
    }
}

/// JSETTLE-1 / JREPORT-1: one share link for the report and the settle share step (mini-program `onShareAppMessage`).
/// The issued referral link (`/api/marketing/referral/token`, `k=r&t=`) is a money write that stays off
/// (`JourneyLoopSource.issueReferral` refuses with `moneyOff`); until it is turned on the share falls back to the
/// public topic link, exactly as the mini-program does when the issue fails.
@MainActor enum PlayerJourneyShare {
    static func url(report: JourneyReport, scope: JourneyRunScope, source: JourneyLoopSource, token: String?) -> URL? {
        let activity = (report.activityID ?? scope.activityID).flatMap { JourneyLoopSource.isID($0) ? $0 : nil }
        let topic = (report.topicID ?? scope.topicID).flatMap { JourneyLoopSource.isID($0) ? $0 : nil }
        if let token, let target = activity ?? topic,
           let issued = try? source.issueReferral(targetType: activity != nil ? 2 : 1, targetID: target, token: token),
           let landing = PlayerJourneyProjection.referralLandingURL(issued) {
            return landing
        }
        guard let topic, let id = Int(topic) else { return nil }
        return PublicContentShareLink.topic(id: id)
    }
}
