import SwiftUI

// Mini-program `subpackageJourney/pages/landing` (referral / gift / seat invite landing, P1 + P4 + P5),
// `pages/seats` (opening lobby, P5) and `pages/promo` (invites and earnings, P2).
// Opening a link is read-only. Gift and seat claims stay OFF (`MPCommerceGate.claimsEnabled`); promo is read-only and
// never offers a withdrawal. Facts come from the bindings; unknown counts render as an em dash.

// MARK: - Shared: play-mode tiles (join-view)

enum JourneyScopeText: String, Equatable {
    case perMember = "PER_MEMBER", perTeam = "PER_TEAM", sharedWorld = "SHARED_WORLD"
    var label: LocalizedStringKey {
        switch self {
        case .perMember: "mp.journey.scope.perMember"
        case .perTeam: "mp.journey.scope.perTeam"
        case .sharedWorld: "mp.journey.scope.sharedWorld"
        }
    }
}

struct JourneyModeRule: Identifiable, Equatable {
    enum Kind: String { case hint, progress, score, team }
    let kind: Kind
    /// Scope for hint / progress / score; nil for the team row.
    let scope: JourneyScopeText?
    /// "3/5" for the team row.
    let teamText: String?
    let on: Bool
    var id: String { kind.rawValue }

    var title: LocalizedStringKey {
        switch kind {
        case .hint: "mp.journey.rule.hint"
        case .progress: "mp.journey.rule.progress"
        case .score: "mp.journey.rule.score"
        case .team: "mp.journey.rule.team"
        }
    }
}

struct JourneyModeTile: Identifiable, Equatable {
    enum Name: Equatable { case together, compete, solo }
    enum Sub: Equatable { case teamScore, rankAfter }
    let key: String
    let name: Name
    let sub: Sub?
    /// Unavailable reason sentence ("team mode is off for this theme", "update the app"...).
    let reason: String?
    let available: Bool
    let rules: [JourneyModeRule]
    var id: String { key }

    var nameText: Text {
        switch name {
        case .together: Text("mp.journey.mode.together")
        case .compete: Text("mp.journey.mode.compete")
        case .solo: Text("mp.journey.mode.solo")
        }
    }
    var symbol: String {
        switch name {
        case .together: "person.3.fill"
        case .compete: "flag.checkered"
        case .solo: "figure.walk"
        }
    }
    var subText: Text? {
        if let reason { return Text(verbatim: reason) }
        switch sub {
        case .teamScore: return Text("mp.journey.mode.sub.teamScore")
        case .rankAfter: return Text("mp.journey.mode.sub.rankAfter")
        case nil: return nil
        }
    }
}

/// "How to play" tiles. More than one tile is a radio group that only switches the rules below (nothing is written).
struct JourneyModeTilesView: View {
    let tiles: [JourneyModeTile]
    @Binding var active: String?
    var showsRules = true
    /// Lobby tiles (seats page) are informational only: no radio, no selection.
    var selectable = true
    @Namespace private var ring
    @QuestifyReduceMotion private var reduceMotion

    private var activeTile: JourneyModeTile? { tiles.first { $0.key == active } }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            MPSectionHeader(title: "mp.journey.howToPlay")
            HStack(spacing: CYSpacing.md) {
                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    tileView(tile, multi: selectable && tiles.count > 1).cyStaggerAppear(index)
                }
            }
            if showsRules, let tile = activeTile, !tile.rules.isEmpty {
                // N-JOURNEY-1 (r10): system GroupBox + LabeledContent rule rows (MP subpackageJourney/pages/landing rules).
                GroupBox {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        ForEach(tile.rules) { rule in
                            LabeledContent {
                                if let scope = rule.scope { Text(scope.label) } else { Text(verbatim: MPText.orDash(rule.teamText)) }
                            } label: {
                                Label {
                                    Text(rule.title)
                                } icon: {
                                    Image(systemName: rule.on ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(rule.on ? Color.accentColor : Color.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .id(tile.key)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cyAnimation(value: active)
    }

    private func tileView(_ tile: JourneyModeTile, multi: Bool) -> some View {
        let on = tile.key == active
        return Button {
            guard multi, tile.key != active else { return }
            active = tile.key
        } label: {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack {
                    Image(systemName: tile.symbol).font(CYTypography.cardTitle)
                    Spacer()
                    if multi {
                        ZStack {
                            Circle().strokeBorder(CYColor.borderStrong, lineWidth: 2).frame(width: 22, height: 22)
                            if on { Circle().fill(CYColor.selection).frame(width: 12, height: 12).matchedGeometryEffect(id: "dot", in: ring) }
                        }
                        .accessibilityHidden(true)
                    }
                }
                tile.nameText.cyText(.sectionTitle)
                if let sub = tile.subText { sub.cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            }
            .foregroundStyle(tile.available ? CYColor.textPrimary : CYColor.textTertiary)
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(CYNight.ink1, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                .strokeBorder(on && multi ? CYColor.selection : CYColor.borderSubtle, lineWidth: on && multi ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!multi)
        .accessibilityAddTraits(multi && on ? [.isSelected] : [])
        .accessibilityIdentifier("journey.mode.\(tile.key)")
        .cyHaptic(.impactLight, trigger: on)
    }
}

// MARK: - Landing

/// Landing link (`k` r / g / s, `t` token, `aid`, `tid`).
struct JourneyLandingLink: Hashable {
    enum Kind: String { case referral = "r", gift = "g", seat = "s" }
    let kind: Kind
    let token: String
    let activityID: String?
    let topicID: String?

    init?(query: [String: String]) {
        guard let raw = query["k"], let kind = Kind(rawValue: raw), let token = query["t"], !token.isEmpty else { return nil }
        self.kind = kind
        self.token = token
        self.activityID = query["aid"].flatMap { $0.isEmpty ? nil : $0 }
        self.topicID = query["tid"].flatMap { $0.isEmpty ? nil : $0 }
    }
}

struct JourneyPerson: Equatable {
    let name: String
    let avatarURL: URL?
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }
}

struct JourneyFact: Identifiable, Equatable {
    enum Kind: String { case inviteValid, signupClosed, claimBy, seat }
    let kind: Kind
    /// Formatted Beijing time for `inviteValid` / `claimBy`; unused for `signupClosed`.
    let value: String
    var id: String { kind.rawValue }
    var title: LocalizedStringKey {
        switch kind {
        case .inviteValid: "mp.landing.fact.invite"
        case .signupClosed: "mp.landing.fact.signup"
        case .claimBy: "mp.landing.fact.claim"
        case .seat: "mp.landing.fact.seat"
        }
    }
    /// Mini-program fact values: "… 前有效", "… 前领取", "已关闭".
    var valueText: Text {
        switch kind {
        case .inviteValid: Text("mp.seats.validUntil \(value)")
        case .claimBy: Text("mp.landing.fact.claimBy \(value)")
        case .signupClosed: Text("mp.landing.fact.closed")
        case .seat: Text(verbatim: value)
        }
    }
}

enum JourneyLandingHeadline: Equatable {
    case referral, gift, seat, seatClaimed, giftClaimed
    var text: Text {
        switch self {
        case .referral: Text("mp.landing.headline.referral")
        case .gift: Text("mp.landing.headline.gift")
        case .seat: Text("mp.landing.headline.seat")
        case .seatClaimed: Text("mp.landing.headline.seatClaimed")
        case .giftClaimed: Text("mp.landing.headline.giftClaimed")
        }
    }
}

enum JourneyLandingPrimary: Equatable {
    case view, claimGift, claimSeat, checkClaimResult, buyOwn, enterRun
    var isClaim: Bool { self == .claimGift || self == .claimSeat || self == .checkClaimResult }
    var title: LocalizedStringKey {
        switch self {
        case .view: "mp.landing.view"
        case .claimGift: "mp.landing.claim"
        case .claimSeat: "mp.landing.claimSeat"
        case .checkClaimResult: "mp.landing.checkResult"
        case .buyOwn: "mp.landing.buyOwn"
        case .enterRun: "mp.landing.enterRun"
        }
    }
}

struct JourneyLandingContent: Equatable {
    var headline: JourneyLandingHeadline
    var inviter: JourneyPerson?
    var title: String?
    var seatNo: String?
    var facts: [JourneyFact]
    var tiles: [JourneyModeTile]
    var activeMode: String?
    var primary: JourneyLandingPrimary?
    var busy = false
    var claimDone = false
    var actionError: String?
}

enum JourneyLandingPhase: Equatable {
    case loading
    case missing
    case failed
    /// Server state sentence (expired / revoked / already claimed). `success` draws the calm "claimed" art.
    case invalid(reason: String, success: Bool)
    case ready(JourneyLandingContent)
}

/// Logic stub for Cursor: `/api/referral/landing/referral|gift`, `/api/play/player-journey/choices`; claims stay unbound.
@MainActor protocol JourneyLandingBinding: AnyObject, Observable {
    var phase: JourneyLandingPhase { get }
    /// Page the primary opens (去看看 → activity / topic). The host pushes it and clears it on back.
    var route: MPParityRoute? { get set }
    func load()
    func selectMode(_ key: String)
    func primary()
}

@MainActor struct JourneyLandingHost: View {
    let binding: any JourneyLandingBinding
    var onBrowse: (() -> Void)? = nil
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        JourneyLandingView(phase: binding.phase, onRetry: { binding.load() }, onSelectMode: { binding.selectMode($0) }, onPrimary: { binding.primary() },
                           // JLAND-10: MP 先逛逛 = switchTab home; without a root tab switch it still closes the landing.
                           onBrowse: onBrowse ?? (rootTabSwitch.isAvailable ? { dismiss(); rootTabSwitch(.home) } : { dismiss() }))
            .task { binding.load() }
            // JLAND-r7-1: account switch re-reads stay here (landing onShow after the sign-in sheet closes).
            .onChange(of: PlayerJourneySignInBridge.shared.presented) { was, now in if was && !now { binding.load() } }
            .mpParityRouteDestination(Binding(get: { binding.route }, set: { binding.route = $0 }))
    }
}

struct JourneyLandingView: View {
    @Environment(\.dismiss) private var backFromMissing
    /// MP missing link: navigateBack (the sheet / push closes).
    private func missingBack() { backFromMissing() }
    let phase: JourneyLandingPhase
    let onRetry: () -> Void
    let onSelectMode: (String) -> Void
    let onPrimary: () -> Void
    /// "Browse first": back to Home without claiming. Nil hides it.
    let onBrowse: (() -> Void)?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("journeyLanding.loading")
            case .missing:
                CYEmptyState(systemImage: "link", "mp.common.linkExpired", messageIdentifier: "journeyLanding.missing",
                             actionTitle: "action.back", actionIdentifier: "journeyLanding.back", action: { missingBack() }).frame(maxHeight: .infinity)
            case .failed:
                CYErrorState("mp.landing.error", onRetry: onRetry).frame(maxHeight: .infinity).accessibilityIdentifier("journeyLanding.error")
            case .invalid(let reason, let success):
                CYStateLayout(kind: success ? .notices : .generic, title: Text(verbatim: reason))
                    .frame(maxHeight: .infinity).accessibilityIdentifier("journeyLanding.invalid")
            case .ready(let content):
                ready(content)
            }
        }
        // N-JOURNEY-1 (r10): the system grouped page, no lantern glow (MP subpackageJourney/pages/landing).
        .background { MPNightGround() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ready(_ content: JourneyLandingContent) -> some View {
        ScrollView {
            VStack(spacing: CYSpacing.lg) {
                content.headline.text.cyText(.pageTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
                JourneyDuoView(inviter: content.inviter, seatNo: content.seatNo)
                if let name = content.inviter?.name { Text(verbatim: name).cyText(.label).foregroundStyle(CYColor.textSecondary) }
                if let title = content.title {
                    // JLAND-9: a long route name wraps to two centred lines instead of overflowing the pill.
                    Text(verbatim: title).font(.headline).foregroundStyle(CYColor.textPrimary)
                        .multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                if !content.tiles.isEmpty {
                    JourneyModeTilesView(tiles: content.tiles, active: Binding(get: { content.activeMode }, set: { if let key = $0 { onSelectMode(key) } }))
                }
                if !content.facts.isEmpty {
                    // N-JOURNEY-1 (r10): system GroupBox + LabeledContent rows instead of MPCard/MPRow.
                    GroupBox {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            ForEach(content.facts) { fact in
                                LabeledContent { fact.valueText.monospacedDigit() } label: { Text(fact.title) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            if content.primary != nil || content.actionError != nil {
                MPBottomBar {
                    if let primary = content.primary {
                        if primary.isClaim && !MPCommerceGate.claimsEnabled {
                            MPGatedNote(text: Text("mp.gate.claim"), identifier: "journeyLanding.claimOff")
                        } else {
                            CYMorphButton(primary.title, state: content.claimDone ? .done : (content.busy ? .working : .idle), action: onPrimary)
                                .identifier("journeyLanding.primary")
                        }
                    }
                    if let error = content.actionError { MPInlineError(text: Text(verbatim: error)) }
                    if let onBrowse {
                        Button("mp.landing.browse", action: onBrowse).cyText(.label).foregroundStyle(CYColor.textSecondary)
                            .frame(minHeight: CYSpacing.minTouchTarget).accessibilityIdentifier("journeyLanding.browse")
                    }
                }
            }
        }
    }
}

private extension JourneyLandingPhase {
    var isReady: Bool { if case .ready = self { return true } else { return false } }
}

/// Inviter ↔ you, with three lights travelling the link; your side turns into the seat number once claimed.
struct JourneyDuoView: View {
    let inviter: JourneyPerson?
    let seatNo: String?
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            seat(ringDelay: 0) {
                if let inviter { MPAvatar(url: inviter.avatarURL, initial: inviter.initial, size: 72) }
                else { Image(systemName: "person.2.fill").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textSecondary) }
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(CYColor.borderSubtle).frame(height: 2)
                        ForEach(0..<3, id: \.self) { index in
                            let phase = reduceMotion ? Double(index + 1) / 4 : ((t / 1.8) + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                            Circle().fill(CYNight.lantern).frame(width: 6, height: 6)
                                .offset(x: geo.size.width * phase - 3)
                                .opacity(reduceMotion ? 0.8 : sin(phase * .pi))
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 20)
            seat(ringDelay: 1.2) {
                if let seatNo {
                    Text(verbatim: seatNo).cyText(.dataXL).foregroundStyle(CYNight.ink0).monospacedDigit()
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "plus").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textSecondary)
                }
            }
            .background { if seatNo != nil { Circle().fill(CYNight.lantern).frame(width: 72, height: 72) } }
            .cyAnimation(.spring(response: 0.4, dampingFraction: 0.55), value: seatNo)
        }
        .padding(.horizontal, CYSpacing.xl)
        .accessibilityHidden(true)
    }

    private func seat<Content: View>(ringDelay: Double, @ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Circle().strokeBorder(CYColor.borderStrong, lineWidth: 1.5).frame(width: 88, height: 88)
            // jl-ring: each end breathes outward every 2.4 s, the two ends half a beat apart. Reduce Motion: no ring.
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let p = ((context.date.timeIntervalSinceReferenceDate + ringDelay) / 2.4).truncatingRemainder(dividingBy: 1)
                    Circle().strokeBorder(CYNight.lantern.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 88, height: 88).scaleEffect(1 + p * 0.4).opacity(1 - p)
                }
                .allowsHitTesting(false)
            }
            Circle().fill(CYNight.ink2).frame(width: 72, height: 72)
            content()
        }
        .frame(width: 88, height: 88)
    }
}

// MARK: - Seats (opening lobby)

enum JourneySeatKind: String, Equatable {
    case me, verified, reserved, open, expired, invited, claimed
    var label: LocalizedStringKey {
        switch self {
        case .me: "mp.seats.state.me"
        case .verified: "mp.seats.state.verified"
        case .reserved: "mp.seats.state.reserved"
        case .open: "mp.seats.state.open"
        case .expired: "mp.seats.state.expired"
        case .invited: "mp.seats.state.invited"
        case .claimed: "mp.seats.state.claimed"
        }
    }
}

struct JourneySeatCircle: Identifiable, Equatable {
    let no: Int
    let kind: JourneySeatKind
    let avatarURL: URL?
    /// Only for the buyer; claimed seats show the seat number (recipient identity is not sent).
    let initial: String?
    let tappable: Bool
    var id: Int { no }
}

struct JourneyTransferSeat: Identifiable, Equatable {
    let no: Int
    var id: Int { no }
}

struct JourneyInvitedRow: Identifiable, Equatable {
    let invitationID: String
    let no: Int
    let kind: JourneySeatKind
    let expiresText: String?
    let canCancel: Bool
    /// JSEAT-r8-1: a phone-transferred seat (INVITED / CLAIMED) shows 称呼 + the server-masked number (MP `who`).
    var who: String? = nil
    var id: String { invitationID }
}

struct JourneySeatsContent: Equatable {
    var headName: String?
    var headCoverURL: String?
    var me: JourneyPerson?
    /// One-person tickets hide the party block.
    var showsParty: Bool
    var occupied: Int?
    var seatCount: Int?
    var circles: [JourneySeatCircle]
    var canInvite: Bool
    var openCount: Int
    var invited: [JourneyInvitedRow]
    /// Mode tiles show only for two or more seats.
    var multi: Bool
    var tiles: [JourneyModeTile]
    var canGoToStart: Bool
    var actionError: String?
    /// Share link for the invite card once the server issued a seat token; nil hides "send to a friend".
    var inviteShareURL: URL?
    /// 怎么玩 facts (Figma `204:15032`): stops and estimated minutes. The seats read does not return them today, so
    /// they stay nil there and the card is hidden rather than printing "—".
    var stopCount: Int? = nil
    var estimatedMinutes: Int? = nil
    /// JSEAT-r8-1: open seats (not seat 1) the buyer may transfer by phone (`seatPhoneTransferSupported`, MP `canTransfer`).
    var transferable: [Int] = []
}

enum JourneySeatsPhase: Equatable {
    case loading
    case missing
    /// JSEAT-6: no valid token is `.auth`. 403 stays `.denied`. A 401 that still had a session is `.failed`.
    case auth
    case denied(String?)
    case failed
    case ready(JourneySeatsContent)
}

/// Logic stub for Cursor: `/api/play/player-journey/seats`, choices, `/api/user/info`; invite / cancel writes are not in Core yet.
@MainActor protocol JourneySeatsBinding: AnyObject, Observable {
    var phase: JourneySeatsPhase { get }
    /// Page 去起点 / 编辑 opens. The host pushes it and clears it on back.
    var route: MPParityRoute? { get set }
    func load()
    func requestInvite()
    func cancelInvitation(_ id: String)
    func goToStart()
    func editMe()
    /// JSEAT-r8-1b (MP seats index.js:161-180): 转赠第 N 席 by phone. nil hides 转赠给同伴.
    var transferSeat: ((Int, String, String) async -> JourneySeatTransferOutcome)? { get }
}

@MainActor struct JourneySeatsHost: View {
    let binding: any JourneySeatsBinding
    /// JSEAT-r8-1b: the sheet's request id is ignored; Core keeps the MP retained id per form (JourneyLoopSource.swift:265).
    private var transferHandler: ((Int, String, String, String) async -> JourneySeatTransferOutcome)? {
        guard let transfer = binding.transferSeat else { return nil }
        return { seatNo, name, phone, _ in await transfer(seatNo, name, phone) }
    }
    var body: some View {
        JourneySeatsView(phase: binding.phase, onRetry: { binding.load() }, onInvite: { binding.requestInvite() },
                         onCancel: { binding.cancelInvitation($0) }, onStart: { binding.goToStart() }, onEditMe: { binding.editMe() },
                         onSignIn: { PlayerJourneySignInBridge.shared.request() }, onTransfer: transferHandler)
            .task { binding.load() }
            // JSEAT-6: re-read once the shared sign-in sheet closes (MP onShow re-reads after login).
            .onChange(of: PlayerJourneySignInBridge.shared.presented) { was, now in if was && !now { binding.load() } }
            .mpParityRouteDestination(Binding(get: { binding.route }, set: { binding.route = $0 }))
    }
}

struct JourneySeatsView: View {
    @Environment(\.dismiss) private var backFromMissing
    /// MP missing link: navigateBack (the sheet / push closes).
    private func missingBack() { backFromMissing() }
    let phase: JourneySeatsPhase
    let onRetry: () -> Void
    let onInvite: () -> Void
    let onCancel: (String) -> Void
    let onStart: () -> Void
    let onEditMe: () -> Void
    var onSignIn: () -> Void = {}
    /// JSEAT-r8-1: `POST /api/play/seat-invitations/transfer-phone` (seat no, 称呼, phone, request id). nil hides 转赠给同伴.
    var onTransfer: ((Int, String, String, String) async -> JourneySeatTransferOutcome)? = nil
    @State private var inviteShown = false
    @State private var cancelTarget: JourneyInvitedRow?
    @State private var transferSeat: JourneyTransferSeat?
    /// N-JOURNEY-2 (r10): the start asks once in a system dialog instead of a hold gesture.
    @State private var confirmStart = false

    var body: some View {
        Group {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("journeySeats.loading")
            case .missing:
                CYEmptyState(systemImage: "link", "mp.common.linkExpired", messageIdentifier: "journeySeats.missing",
                             actionTitle: "action.back", actionIdentifier: "journeySeats.back", action: { missingBack() }).frame(maxHeight: .infinity)
            case .auth:
                CYEmptyState(systemImage: "person.crop.circle", "mp.seats.auth", messageIdentifier: "journeySeats.auth",
                             actionTitle: "mp.common.signIn", actionIdentifier: "journeySeats.signIn", action: onSignIn)
                    .frame(maxHeight: .infinity)
            case .denied(let message):
                CYStateLayout(kind: .generic, title: message.map { Text(verbatim: $0) } ?? Text("mp.seats.denied"))
                    .frame(maxHeight: .infinity).accessibilityIdentifier("journeySeats.denied")
            case .failed:
                CYErrorState("mp.seats.error", retryTitle: "mp.common.reload", onRetry: onRetry).frame(maxHeight: .infinity)
                    .accessibilityIdentifier("journeySeats.error")
            case .ready(let content):
                ready(content)
            }
        }
        .cyPushedChrome(domain: .player)
        // JSEAT-8: MP subpackageJourney/pages/seats/index.wxml:3-4 — the bar title is 开局大厅.
        .navigationTitle(Text("mp.seats.title"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let target = cancelTarget {
                PlayAreaSeatCancelModal(seatNo: target.no, onConfirm: {
                    onCancel(target.invitationID)
                    cancelTarget = nil
                }, onCancel: { cancelTarget = nil })
            }
        }
        .cyDomainScreen(.player)
    }

    private func ready(_ content: JourneySeatsContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                // JSEAT-8: 开局大厅 is the navigation title; no eyebrow or large in-content title. The topic name stays as a headline.
                if let name = content.headName {
                    Text(verbatim: name).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                // The cover strip only when the read has a cover: a grey stand-in block would be a placeholder.
                if content.headCoverURL != nil {
                    CYCachedAsyncImage(content.headCoverURL, role: .cover)
                        .frame(height: 112)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                        .accessibilityHidden(true)
                }
                if content.showsParty { party(content) }
                JourneyLobbyHowToCard(stops: content.stopCount, minutes: content.estimatedMinutes)
                if let me = content.me, !me.name.isEmpty {
                    // N-JOURNEY-2 (r10): a system GroupBox row with a disclosure chevron.
                    GroupBox {
                        Button(action: onEditMe) {
                            LabeledContent {
                                HStack(spacing: CYSpacing.xs) {
                                    Text("mp.seats.edit")
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).accessibilityHidden(true)
                                }
                            } label: { Text("mp.seats.playAs \(me.name)") }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .accessibilityIdentifier("journeySeats.editMe")
                }

                if content.multi && !content.tiles.isEmpty {
                    JourneyModeTilesView(tiles: content.tiles, active: .constant(nil), showsRules: false, selectable: false)
                }
                if content.showsParty && (!content.invited.isEmpty || content.actionError != nil || (onTransfer != nil && !content.transferable.isEmpty)) {
                    if let error = content.actionError { MPInlineError(text: Text(verbatim: error)) }
                    if !content.invited.isEmpty {
                        GroupBox { VStack(alignment: .leading, spacing: CYSpacing.sm) { ForEach(content.invited) { row in
                            HStack(spacing: CYSpacing.md) {
                                Text(verbatim: String(row.no)).cyText(.cardTitle).monospacedDigit().frame(width: 28)
                                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                    // JSEAT-r8-1 (MP `item.who || item.label`, then label as the sub line).
                                    if let who = row.who {
                                        Text(verbatim: who).cyText(.bodyMedium)
                                        Text(row.kind.label).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    } else {
                                        Text(row.kind.label).cyText(.bodyMedium)
                                        if let expires = row.expiresText { Text("mp.seats.validUntil \(expires)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                                    }
                                }
                                Spacer()
                                if row.canCancel {
                                    // verify-r1 2.4 / MC-20 pattern: 撤回 lives in the row's ⋯ menu, not as a small red word.
                                    Menu {
                                        Button("mp.seats.cancel", role: .destructive) { cancelTarget = row }
                                            .accessibilityIdentifier("journeySeats.cancel.\(row.no)")
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .cyText(.bodyMedium)
                                            .foregroundStyle(CYColor.textSecondary)
                                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                                            .contentShape(Rectangle())
                                    }
                                    .accessibilityLabel(Text("mp.seats.rowMore"))
                                    .accessibilityIdentifier("journeySeats.more.\(row.no)")
                                }
                            }
                        } } }
                    }
                    if onTransfer != nil && !content.transferable.isEmpty {
                        GroupBox { VStack(alignment: .leading, spacing: CYSpacing.sm) { ForEach(content.transferable.map(JourneyTransferSeat.init)) { seat in
                            HStack(spacing: CYSpacing.md) {
                                Text(verbatim: String(seat.no)).cyText(.cardTitle).monospacedDigit().frame(width: 28)
                                Text("mp.seats.transferable").cyText(.bodyMedium)
                                Spacer()
                                Button("mp.seats.transfer.open") { transferSeat = seat }
                                    .frame(minHeight: CYSpacing.minTouchTarget)
                                    .accessibilityLabel(Text("mp.seats.transfer.a11y \(seat.no)"))
                                    .accessibilityIdentifier("journeySeats.transfer.\(seat.no)")
                            }
                        } } }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .refreshable { onRetry() }
        .safeAreaInset(edge: .bottom) {
            if content.canGoToStart {
                // Design hand-off r1 PL-03 / PL-42: the lobby starts with a 0.8 s hold on the one primary.
                // verify-r1 2.4 / N-13: the button says the gesture it needs; the caption reassures. VoiceOver keeps 去起点.
                // N-JOURNEY-2 (r10): one `.borderedProminent` 去起点 (MP subpackageJourney/pages/seats/index.wxml goStart)
                // and a system confirmation dialog in place of the hold gesture; the caption is the dialog message.
                MPBottomBar {
                    Button { confirmStart = true } label: {
                        Label("mp.seats.goStart", systemImage: "flag.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("journeySeats.start")
                }
            }
        }
        .confirmationDialog(Text("mp.seats.goStart"), isPresented: $confirmStart, titleVisibility: .visible) {
            Button("mp.seats.goStart") { onStart() }
        } message: {
            Text("mp.seats.holdCaption")
        }
        .cySheet(isPresented: $inviteShown) { JourneyInviteSheet(content: content) }
        .cySheet(item: $transferSeat) { seat in
            if let onTransfer {
                JourneySeatTransferSheet(seatNo: seat.no, submit: { name, phone, id in await onTransfer(seat.no, name, phone, id) },
                                         onDone: onRetry)
            }
        }
    }

    private func party(_ content: JourneySeatsContent) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                // JSEAT-9: MP seats.wxss `.lb-party__h` is body size, bold; the count `.lb-party__n` is body, secondary.
                Text("mp.seats.party").cyText(.bodyMedium).accessibilityAddTraits(.isHeader)
                Text(verbatim: content.occupied.map { o in "\(o)/\(MPText.orDash(content.seatCount))" } ?? MPText.orDash(content.seatCount))
                    .cyText(.body).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                Spacer()
                if content.openCount > 0 {
                    CYStatusTag("mp.seats.waiting", state: .neutral).accessibilityIdentifier("journeySeats.waiting")
                }
                if content.canInvite || !content.invited.isEmpty {
                    Button("mp.seats.invite") { openInvite(content) }
                        .cyText(.body).frame(minHeight: CYSpacing.minTouchTarget)
                        .disabled(!content.canInvite)
                        .accessibilityIdentifier("journeySeats.invite")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.lg) {
                    ForEach(content.circles) { circle in
                        // verify-r1 2.4: a seat you cannot tap is not a disabled button. A disabled plain button dims
                        // its whole label, which is what made the 房主 badge and the 我 seat unreadable.
                        Group {
                            if circle.tappable {
                                Button { openInvite(content) } label: { seatCircle(circle) }
                                    .buttonStyle(.plain)
                            } else {
                                seatCircle(circle)
                                    .accessibilityElement(children: .ignore)
                            }
                        }
                        .accessibilityLabel(Text("mp.seats.seatLabel \(circle.no)") + Text(verbatim: " ") + Text(circle.kind.label))
                        .accessibilityIdentifier("journeySeats.seat.\(circle.no)")
                    }
                }
                .padding(.vertical, CYSpacing.xs)
                // The "me" ring draws 3 pt outside its 56 pt circle; inset the row so the first seat is not clipped.
                .padding(.horizontal, CYSpacing.xs)
            }
        }
    }

    private func seatCircle(_ circle: JourneySeatCircle) -> some View {
        VStack(spacing: CYSpacing.xs) {
            ZStack(alignment: .bottom) {
                if circle.kind == .open {
                    Circle().strokeBorder(CYColor.borderStrong, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])).frame(width: 56, height: 56)
                    Image(systemName: "plus").accessibilityHidden(true).foregroundStyle(CYColor.textSecondary).frame(width: 56, height: 56)
                } else if circle.kind == .invited {
                    Circle().strokeBorder(CYColor.textPrimary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])).frame(width: 56, height: 56)
                        .overlay(Text(verbatim: String(circle.no)).cyText(.cardTitle).monospacedDigit())
                } else if circle.kind == .me {
                    MPAvatar(url: circle.avatarURL, initial: circle.initial ?? "", size: 56)
                        .overlay(Circle().strokeBorder(CYColor.textPrimary, lineWidth: 2).padding(-3))
                } else {
                    Circle().fill(CYColor.bgElevated).frame(width: 56, height: 56)
                        .overlay(Text(verbatim: String(circle.no)).cyText(.cardTitle).monospacedDigit())
                }
                if circle.kind == .me {
                    // verify-r1 2.4: 房主 was brown text on a brown fill. Neutral tag with a crown: ink on a light chip.
                    Label { Text("mp.seats.host") } icon: { Image(systemName: "crown.fill") }
                        .labelStyle(.titleAndIcon)
                        .cyText(.micro, weight: .semibold)
                        .foregroundStyle(CYDomainPalette(.player).actionPrimaryFg)
                        .padding(.horizontal, CYSpacing.xs).padding(.vertical, 2)
                        .background(CYDomainPalette(.player).actionPrimaryBg, in: Capsule()).offset(y: CYSpacing.sm)
                }
            }
            // polish-d-r1: every seat reserves the 房主 badge's overhang, so the badge never sits on the label and
            // all labels stay on one baseline.
            .padding(.bottom, CYSpacing.md)
            // JSEAT-11: only the expired circle dims; its 已过期 label keeps textSecondary contrast.
            .opacity(circle.kind == .expired ? 0.45 : 1)
            Text(circle.kind.label).cyText(.caption).foregroundStyle(CYColor.textSecondary)
        }
        .frame(minWidth: CYSpacing.minTouchTarget)
    }

    private func openInvite(_ content: JourneySeatsContent) {
        guard content.canInvite else { return }
        if content.inviteShareURL == nil { onInvite() }
        inviteShown = true
    }
}

/// 怎么玩 (Figma `204:15032`): N 站 · 约 N 分钟 · 需要到场. Rows with unknown facts are left out; with neither fact known the
/// card is not drawn (the arrival row alone would not explain the play).
struct JourneyLobbyHowToCard: View {
    let stops: Int?
    let minutes: Int?
    var body: some View {
        if stops != nil || minutes != nil {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let stops { row("point.topleft.down.to.point.bottomright.curvepath", Text("mp.seats.howTo.stops \(stops)"), Text("mp.seats.howTo.stopsNote")) }
                if let minutes { row("clock", Text("mp.seats.howTo.minutes \(minutes)"), Text("mp.seats.howTo.minutesNote")) }
                row("mappin", Text("mp.seats.howTo.arrive"), Text("mp.seats.howTo.arriveNote"))
            }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("journeySeats.howTo")
        }
    }
    private func row(_ symbol: String, _ title: Text, _ note: Text) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: symbol).cyText(.body).foregroundStyle(CYColor.textSecondary).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title.cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                note.cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Unified invite card (cover, inviter, seats left) with a system share for the seat link.
private struct JourneyInviteSheet: View {
    let content: JourneySeatsContent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    /// seats-save (r10): the invite card rendered once for the system share sheet (Save Image lives there).
    @State private var inviteImage: Image?

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            inviteCard
            if let url = content.inviteShareURL {
                ShareLink(item: url, subject: Text("mp.seats.invite.fallbackTitle")) {
                    Label("mp.seats.invite.send", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.cyPrimary)
                .accessibilityIdentifier("journeySeats.invite.send")
            } else if let error = content.actionError {
                MPInlineError(text: Text(verbatim: error))
            } else {
                ProgressView().frame(minHeight: CYSpacing.minTouchTarget)
            }
            // seats-save (r10): MP seats 保存邀请图 (subpackageJourney/pages/seats/index.wxml) via ImageRenderer + ShareLink.
            if let inviteImage {
                ShareLink(item: inviteImage, preview: SharePreview(Text("mp.seats.invite.fallbackTitle"), image: inviteImage)) {
                    Label("gap.team.saveInviteImage", systemImage: "photo").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
                .accessibilityIdentifier("journeySeats.invite.saveImage")
            }
            Button("action.close") { dismiss() }.frame(minHeight: CYSpacing.minTouchTarget)
        }
        .padding(CYSpacing.pageHorizontal)
        .task(id: content) { await renderInviteImage() }
        // JSEAT-10: large Dynamic Type can grow the card past half height.
        .cySheet(detents: [.medium, .large])
        .cyPlayerSheetGlass()
    }

    @MainActor private func renderInviteImage() {
        let renderer = ImageRenderer(content: inviteCard.environment(\.locale, locale).frame(width: 340))
        renderer.scale = 3
        inviteImage = renderer.cgImage.map { Image(decorative: $0, scale: 3) }
    }

    private var inviteCard: some View {
            VStack(spacing: CYSpacing.md) {
                Image(systemName: "envelope.open.fill").font(CYTypography.display).foregroundStyle(CYNight.lanternHot)
                    .background { Circle().fill(CYNight.glow(radius: 40)).frame(width: 140, height: 140) }
                    .accessibilityHidden(true)
                (content.headName.map { Text(verbatim: $0) } ?? Text("mp.seats.invite.fallbackTitle")).cyText(.sectionTitle)
                if let me = content.me?.name, !me.isEmpty { Text("mp.seats.invite.from \(me)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                Text("mp.seats.invite.left \(content.openCount)").cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary)
            }
            .padding(CYSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
    }
}

// MARK: - Promo (invites and earnings)

struct JourneyPromoBucket: Identifiable, Equatable {
    enum Kind: String { case pending, confirmed, paid, reversed }
    let kind: Kind
    /// Formatted amount; nil with `multiCurrency` reads "not summed across currencies", otherwise an em dash.
    let amountText: String?
    let multiCurrency: Bool
    let count: Int?
    var id: String { kind.rawValue }
    var title: LocalizedStringKey {
        switch kind {
        case .pending: "mp.promo.bucket.pending"
        case .confirmed: "mp.promo.bucket.confirmed"
        case .paid: "mp.promo.bucket.paid"
        case .reversed: "mp.promo.bucket.reversed"
        }
    }
}

struct JourneyPromoCampaign: Identifiable, Equatable {
    let id: String
    let title: String?
    let attributed: Int?
    let paid: Int?
    let refunded: Int?
}

struct JourneyPromoLink: Identifiable, Equatable {
    let id: String
    let title: String?
    let active: Bool
    let expiresText: String?
}

struct JourneyPromoContent: Equatable {
    var buckets: [JourneyPromoBucket]
    var heldOrders: Int?
    var campaigns: [JourneyPromoCampaign]
    var links: [JourneyPromoLink]
    /// Mini-program `hasRecords`: allocations or deals. Links alone still show "no verifiable records".
    var hasRecords: Bool { !buckets.isEmpty || !campaigns.isEmpty }
}

enum JourneyPromoPhase: Equatable {
    case loading
    case auth
    case failed
    case ready(JourneyPromoContent)
}

/// Logic stub for Cursor: Core `PWaveP2AffiliateCenter` (read only). No payout channel is ever offered here.
@MainActor protocol JourneyPromoBinding: AnyObject, Observable {
    var phase: JourneyPromoPhase { get }
    func load()
    func signIn()
}

@MainActor struct JourneyPromoHost: View {
    let binding: any JourneyPromoBinding
    var body: some View {
        JourneyPromoView(phase: binding.phase, onRetry: { binding.load() }, onSignIn: { binding.signIn() }).task { binding.load() }
            // Reload once the shared sign-in sheet closes (MP onShow re-reads after login).
            .onChange(of: PlayerJourneySignInBridge.shared.presented) { was, now in if was && !now { binding.load() } }
    }
}

struct JourneyPromoView: View {
    let phase: JourneyPromoPhase
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        // JPROMO-6: the whole-page states fill the screen (centred, native state layout); only the content scrolls.
        Group {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("journeyPromo.loading")
            case .auth:
                CYEmptyState(systemImage: "person.crop.circle", "mp.promo.auth", messageIdentifier: "journeyPromo.auth",
                             actionTitle: "mp.common.signIn", actionIdentifier: "journeyPromo.signIn", action: onSignIn)
                    .frame(maxHeight: .infinity)
            case .failed:
                CYErrorState("mp.promo.error", retryTitle: "mp.common.reload", onRetry: onRetry).frame(maxHeight: .infinity)
                    .accessibilityIdentifier("journeyPromo.error")
            case .ready(let content):
                // N-JOURNEY-1 (r10): an inset-grouped List; each MP card is a Section (MP subpackageJourney/pages/promo).
                List { ready(content) }
                    .listStyle(.insetGrouped)
                    .refreshable { onRetry() }
            }
        }
        .cyPageTitle("mp.promo.title")
        .cyDomainScreen(.player)
    }

    /// MP promo wxml:19: a count the server did not send reads 未知, not a dash.
    static func countOrUnknown(_ value: Int?) -> String {
        value.map(String.init) ?? appLocalized("mp.promo.unknown", locale: .current)
    }

    @ViewBuilder private func ready(_ content: JourneyPromoContent) -> some View {
        if !content.buckets.isEmpty || content.heldOrders != nil {
            Section {
                ForEach(content.buckets) { bucket in
                    LabeledContent {
                        (bucket.amountText.map { Text(verbatim: $0) } ?? (bucket.multiCurrency ? Text("mp.promo.multiCurrency") : Text(verbatim: MPText.unknown)))
                            .monospacedDigit()
                    } label: {
                        Text(bucket.title)
                        if let count = bucket.count { Text("mp.promo.count \(count)") }
                    }
                }
                if let held = content.heldOrders {
                    LabeledContent { Text("mp.promo.heldCount \(held)") } label: { Text("mp.promo.held") }
                }
            } footer: {
                MPGatedNote(text: Text("mp.gate.payout"), identifier: "journeyPromo.payoutOff")
            }
        }
        if !content.campaigns.isEmpty {
            Section("mp.promo.deals") {
                ForEach(content.campaigns) { campaign in
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        campaign.title.map { Text(verbatim: $0) } ?? Text("mp.promo.topic")
                        (Text("mp.promo.deal.line \(Self.countOrUnknown(campaign.attributed)) \(Self.countOrUnknown(campaign.paid))")
                            + (campaign.refunded.flatMap { $0 > 0 ? $0 : nil }.map { Text(verbatim: " · ") + Text("mp.promo.deal.refunded \($0)") } ?? Text(verbatim: "")))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        if !content.links.isEmpty {
            Section("mp.promo.links") {
                ForEach(content.links) { link in
                    LabeledContent {
                        link.active ? Text("mp.promo.link.active") : Text("mp.promo.link.inactive")
                    } label: {
                        link.title.map { Text(verbatim: $0) } ?? Text("mp.promo.topic")
                        if let expires = link.expiresText { Text("mp.promo.link.expires \(expires)") }
                    }
                }
            }
        }
        if !content.hasRecords {
            CYEmptyState(systemImage: "tray", "mp.promo.empty", messageIdentifier: "journeyPromo.empty")
        }
    }
}
