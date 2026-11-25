import SwiftUI

// Pass card sheet (W1-5). Account (tab) -> ticket card -> this sheet: the next usable ticket as a notched pass with a
// 240 pt QR on white, brightness boosted while it is on screen. Everything that is not "show the code" lives in the
// overflow menu: all tickets, ticket details and lifecycle (the existing detail screen), refresh and ticket switching.
// Behaviour is unchanged: the QR is still the approval-gated `VerificationCodeView` payload; without a code factory the
// registration number is shown for staff. Unknown values are an em dash, never 0. Spec: docs/release/receipts/ui-pass-card.md.

/// The ticket the card leads with: first usable (ready) ticket that opens a detail; otherwise the first that is not
/// retired; otherwise the first row. Pure, so fixtures and tests can call it.
enum CYPassCardPick {
    static func index(in tickets: [TicketWalletTicket]) -> Int? {
        if let i = tickets.firstIndex(where: { $0.status == .ready && $0.action == .detail && !$0.isWalletLocked }) { return i }
        if let i = tickets.firstIndex(where: { !CYPassState($0.status).isRetired && $0.action == .detail }) { return i }
        return tickets.isEmpty ? nil : 0
    }
}

@MainActor struct TicketPassSheet: View {
    let reader: any TicketWalletReading
    var onClose: () -> Void
    /// Hands off to the full wallet list (the host closes this sheet first).
    var onOpenWallet: () -> Void
    var lifecycleCoordinator: OrderLifecycleCoordinator? = nil
    var makeTeamCoordinator: (() -> TeamCoordinator)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.ticketWalletPlayProvider) private var playProvider
    @State private var phase: CYPhase<TicketWalletSnapshot, Error> = .idle
    @State private var selectedID: Int?
    @State private var detailID: Int?
    @State private var playDetailID: Int?
    @State private var loadToken = 0
    /// Bumped when the pass flips to verified: the edge glow sweeps the display corners (choreography D).
    @State private var glowTick = 0
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cyDomainPageBackground()
                .navigationTitle(Text(verbatim: c.t("票夹", "Ticket wallet"))) // mini-program signup page title
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onClose) { Text("action.close") }
                            .accessibilityIdentifier("ticketPass.close")
                    }
                    ToolbarItem(placement: .primaryAction) { overflow }
                }
                .navigationDestination(item: $detailID) { id in
                    TicketWalletDetailView(id: id, reader: reader, lifecycleCoordinator: lifecycleCoordinator, makeTeamCoordinator: makeTeamCoordinator)
                }
                .navigationDestination(item: $playDetailID) { id in
                    // PLY-21-3: the detail re-reads the ticket, then starts play; a list row never proves the status.
                    TicketWalletDetailView(id: id, reader: reader, lifecycleCoordinator: lifecycleCoordinator,
                                           makeTeamCoordinator: makeTeamCoordinator, autoStartsPlay: true)
                }
        }
        .task(id: TaskKey(scope: reader.scope, token: loadToken, active: scenePhase == .active)) { await load() }
        .cyEdgeGlow(trigger: glowTick)
        .themeDomain(.player)
        .accessibilityIdentifier("ticketPass.sheet")
    }
    private struct TaskKey: Equatable { let scope: UUID; let token: Int; let active: Bool }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch phase {
        case .idle, .loading:
            VStack(spacing: CYSpacing.lg) {
                CYSkeleton().frame(maxWidth: 300)
            }
            .padding(CYSpacing.pageHorizontal)
            .accessibilityLabel(Text(verbatim: c.t("正在打开票券", "Opening your pass")))
            .accessibilityIdentifier("ticketPass.loading")
        case .loaded(let snapshot):
            if let ticket = current(in: snapshot) {
                ScrollView {
                    VStack(spacing: CYSpacing.lg) {
                        let openable = snapshot.tickets.filter { $0.action == .detail }
                        if openable.count > 1, openable.contains(where: { $0.id == ticket.id }) {
                            // PLY-21-13 (MP signup index.js:655-708): several passes page sideways; the page in view is the
                            // current ticket. The overflow 切换票券 picker stays as the non-gesture path.
                            StackedPassHorizontalPager(passes: openable, selectedID: Binding(
                                get: { ticket.id }, set: { if let id = $0 { selectedID = id } })) { pass in
                                TicketPassCard(ticket: pass, onVerified: { if pass.id == ticket.id { glowTick += 1 } })
                            }
                            .accessibilityIdentifier("ticketPass.pager")
                            let position = (openable.firstIndex(where: { $0.id == ticket.id }) ?? 0) + 1
                            Text("ticketPass.pager.position \(position) \(openable.count)")
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit()
                                .accessibilityIdentifier("ticketPass.pager.position")
                        } else {
                            TicketPassCard(ticket: ticket, onVerified: { glowTick += 1 })
                        }
                        // PLY-21-3 / PLY-21-4: MP signup wxml:103-106 puts 开始游戏 (查看记录 once cleared) under the pass.
                        if playProvider != nil, ticket.status == .ready, ticket.action == .detail, !ticket.isWalletLocked,
                           TicketWalletPlayEntry.entry(ticket: ticket, requestedID: ticket.id) != nil {
                            Button { playDetailID = ticket.id } label: {
                                if ticket.clearedFlag == true { Label { Text(verbatim: c.t("查看记录", "View record")) } icon: { TicketWalletPlayGlyph() } }
                                else { Label { Text("playerJourney.start") } icon: { TicketWalletPlayGlyph() } }
                            }
                            .buttonStyle(.cyPrimary(fullWidth: true))
                            .frame(maxWidth: 360)
                            .accessibilityIdentifier("ticketPass.play")
                        }
                        if let partial = snapshot.partialFailure {
                            Text(verbatim: c.t("部分票券没能读取，下拉或在菜单里刷新", "Some tickets did not load. Refresh from the menu."))
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("ticketPass.partial.\(partial.lane == .route ? "route" : "activity")")
                        }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { loadToken += 1 }
            } else {
                ScrollView { CYStateView(content: emptyContent, onPrimary: onOpenWallet) }
            }
        case .empty:
            ScrollView { CYStateView(content: emptyContent, onPrimary: onOpenWallet) }
        case .failed:
            ScrollView {
                if !reader.isAuthenticated {
                    CYStateView(content: .empty(glyph: "person.crop.circle", title: c.t("登录后查看票券", "Sign in to see your pass"),
                                                body: c.t("登录后，你买到的票会出现在这里。", "Tickets you buy show up here once you're signed in."),
                                                actionTitle: c.t("关闭", "Close")), onPrimary: onClose)
                } else {
                    CYStateView.server(locale: locale) { loadToken += 1 }
                }
            }
        }
    }

    private var emptyContent: CYStateContent {
        .empty(glyph: "ticket", title: c.t("还没有票", "No tickets yet"),
               body: "",
               actionTitle: c.t("查看全部票券", "All tickets"))
    }

    private func current(in snapshot: TicketWalletSnapshot) -> TicketWalletTicket? {
        if let selectedID, let t = snapshot.tickets.first(where: { $0.id == selectedID }) { return t }
        return CYPassCardPick.index(in: snapshot.tickets).map { snapshot.tickets[$0] }
    }

    // MARK: Overflow

    private var overflow: some View {
        Menu {
            if let snapshot = phase.value {
                let openable = snapshot.tickets.filter { $0.action == .detail }
                if openable.count > 1 {
                    Picker(selection: Binding(get: { current(in: snapshot)?.id ?? 0 }, set: { selectedID = $0 })) {
                        ForEach(openable) { t in
                            Text(verbatim: (t.title?.isEmpty == false ? t.title! : "—")).tag(t.id)
                        }
                    } label: { Text(verbatim: c.t("切换票券", "Switch ticket")) }
                }
                if let t = current(in: snapshot), t.action == .detail {
                    Button { detailID = t.id } label: {
                        Label { Text(verbatim: c.t("票券详情与退改", "Ticket details and changes")) } icon: { Image(systemName: "ticket") }
                    }.accessibilityIdentifier("ticketPass.overflow.details")
                }
            }
            Button(action: onOpenWallet) {
                Label { Text(verbatim: c.t("全部票券", "All tickets")) } icon: { Image(systemName: "rectangle.stack") }
            }.accessibilityIdentifier("ticketPass.overflow.all")
            Button { loadToken += 1 } label: {
                Label { Text("ticketWallet.refresh") } icon: { Image(systemName: "arrow.clockwise") }
            }
            .disabled(phase.isLoading)
            .accessibilityIdentifier("ticketPass.overflow.refresh")
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityLabel(Text(verbatim: c.t("更多", "More")))
        .accessibilityIdentifier("ticketPass.overflow")
    }

    // MARK: Load

    private func load() async {
        guard scenePhase == .active else { return }
        guard reader.isAuthenticated, reader.isConfigured else {
            phase = .failed(TicketWalletReadFailure.unavailable, retry: nil); return
        }
        // A refresh over a loaded pass keeps the card on screen, so a status flip (ready to verified) can animate.
        if phase.value == nil { phase = .loading }
        do {
            // MP F13 (PLY-21-1): the pass shows usable tickets only, in walletOrder; a locked (upcoming / refunding)
            // ticket never leads the card.
            let snapshot = try await reader.ticketWallet().walletUsable
            guard !Task.isCancelled else { return }
            phase = snapshot.tickets.isEmpty && snapshot.partialFailure == nil ? .empty : .loaded(snapshot)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error, retry: nil)
        }
    }
}

/// The pass itself: header (title, date, place), tear line with notches, 240 pt code tile on white, status chip.
@MainActor struct TicketPassCard: View {
    let ticket: TicketWalletTicket
    /// Fired when the status flips to verified while the card is on screen; the host sweeps the display-edge glow.
    var onVerified: (() -> Void)? = nil
    static let qrSide: CGFloat = 240
    @Environment(\.verificationCodeFactory) private var codeFactory
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @QuestifyReduceMotion private var reduceMotion
    @State private var topHeight: CGFloat = 0
    @State private var cardSize: CGSize = .zero
    @State private var appeared = false
    @State private var sheen = 0
    @State private var dimTile = false
    @State private var faceAngle = 0.0
    @State private var tear: CGFloat = 0
    @State private var drop: CGFloat = 0
    @State private var verifyRun: Task<Void, Never>?
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var state: CYPassState { CYPassState(ticket.status) }
    private let tearBand: CGFloat = 22
    private var shape: CYTicketPassShape {
        CYTicketPassShape(notchY: topHeight > 0 ? topHeight + tearBand / 2 : -1, radius: CYRadius.hero, notch: 11, perforation: 3, perforationGap: 7)
    }

    var body: some View {
        front
            .accessibilityHidden(faceAngle >= 90)
            .modifier(CYPassFlip(angle: faceAngle, crossfade: reduceMotion, back: verifiedBack))
            .cyPassTilt()
            .scaleEffect(appeared || reduceMotion ? 1 : 0.94, anchor: .top)
            .offset(y: appeared || reduceMotion ? 0 : 28)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(CYMotion.resolve(CYMotion.entrance, reduceMotion: reduceMotion)) { appeared = true }
                if ticket.status == .ready {
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); sheen += 1 }
                }
            }
            .onChange(of: ticket.status) { old, new in
                if new == .verified, old != .verified { runVerified() }
            }
            .onDisappear { verifyRun?.cancel() }
    }

    /// The live pass: the face every state starts on.
    private var front: some View {
        VStack(spacing: 0) {
            header.background(GeometryReader { Color.clear.preference(key: TicketPassTopHeightKey.self, value: $0.size.height) })
            Color.clear.frame(height: tearBand).accessibilityHidden(true)
            tile.opacity(dimTile ? 0.6 : 1).padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.xl)
        }
        .onPreferenceChange(TicketPassTopHeightKey.self) { topHeight = $0 }
        .frame(maxWidth: .infinity)
        .background(CYColor.bgElevated)
        .cyFoilSheen(trigger: sheen)
        .clipShape(shape, style: FillStyle(eoFill: true))
        .cyPassFoilEdge(shape, active: ticket.status == .ready)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .opacity(state.isRetired ? 0.74 : 1)
        .cyBrightnessBoost(ticket.status == .ready)
        .background(GeometryReader { g in Color.clear.onAppear { cardSize = g.size }.onChange(of: g.size) { _, new in cardSize = new } })
        .privacySensitive()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ticketPass.card")
    }

    /// The green "You're in" face, torn along the perforation once the flip lands. Hidden until a flip happens.
    @ViewBuilder private var verifiedBack: some View {
        if cardSize.width > 1, topHeight > 0 {
            let notchY = topHeight + tearBand / 2
            CYPassTear(
                face: CYPassVerifiedFace(title: ticket.title ?? "", number: ticket.registrationNumber, size: cardSize, notchY: notchY, shape: shape),
                size: cardSize, notchY: notchY, tear: tear, drop: drop)
        }
    }

    /// Choreography D from the moment the status flips (ms): 0 tile dims and the host fires the edge glow; 300 flip
    /// (0.5 s); 800 the perforation tears (3 pt gap, 24 pt slide, impactLight); 1700 the stub drops toward the tab bar.
    private func runVerified() {
        verifyRun?.cancel()
        verifyRun = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.15)) { dimTile = true }
            onVerified?()
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                withAnimation(CYMotion.reduced) { faceAngle = 180 }
                return
            }
            withAnimation(.easeInOut(duration: 0.5)) { faceAngle = 180 }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            CYHaptics.impactLight.play()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { tear = 1 }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.5)) { drop = 1 }
        }
    }

    /// Cover-art band with the status chip top-right and the title on a scrim (same art as the wallet pass), then date
    /// and place. At accessibility sizes the band shrinks and the chip and title move below it so nothing clips.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                E1CoverArt(seed: ticket.title ?? "ticket", symbol: "ticket", debugLabel: false, symbolPoint: CGPoint(x: 0.84, y: 0.62))
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                if !typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack(spacing: 0) { Spacer(minLength: 0); CYPassStatusChip(state: state, text: LocalizedStringKey("ticketWallet.status." + ticket.status.rawValue)) }
                        Spacer(minLength: 0)
                        title.foregroundStyle(.white).lineLimit(2)
                    }
                    .padding(CYSpacing.lg)
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 72 : 132)
            .clipped()
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if typeSize.isAccessibilitySize {
                    CYPassStatusChip(state: state, text: LocalizedStringKey("ticketWallet.status." + ticket.status.rawValue)).padding(.bottom, CYSpacing.xs)
                    title.foregroundStyle(CYColor.textPrimary).padding(.bottom, CYSpacing.xs)
                }
                Label { Text(verbatim: nonEmpty(ticket.participateDate)) } icon: { Image(systemName: "calendar") }
                Label { Text(verbatim: nonEmpty(ticket.addressName)).lineLimit(2) } icon: { Image(systemName: "mappin.and.ellipse") }
            }
            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: some View {
        TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
            .cyText(.sectionTitle)
            .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("ticketPass.title")
    }

    /// Unknown reads as an em dash, never blank or 0.
    private func nonEmpty(_ s: String?) -> String { (s?.isEmpty == false) ? s! : "—" }

    @ViewBuilder private var tile: some View {
        VStack(spacing: CYSpacing.md) {
            // MP k4 (j2 F-22): a cleared ticket or a locked (upcoming / refunding) one issues no entry code (PLY-21-4).
            if let codeFactory, ticket.status == .ready, ticket.clearedFlag != true, !ticket.isWalletLocked {
                VerificationCodeView(model: codeFactory(.init(kind: .ticket, id: ticket.id)), embeddedQRSide: Self.qrSide)
                    .id(ticket.id)
            } else {
                whiteTile
            }
            Text(verbatim: hint).cyText(.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Honest fallback, the same 240 pt white tile: the registration number for a ready ticket without a factory,
    /// otherwise the state glyph. Never a drawn code.
    private var whiteTile: some View {
        let side = Self.qrSide
        return VStack(spacing: CYSpacing.sm) {
            if ticket.status == .ready, let n = ticket.registrationNumber, !n.isEmpty {
                Text(verbatim: n).cyText(.sectionTitle).monospaced().foregroundStyle(.black)
                    .minimumScaleFactor(0.5).lineLimit(2).multilineTextAlignment(.center).textSelection(.enabled)
                    .accessibilityLabel(Text(verbatim: c.t("票号", "Ticket number"))).accessibilityValue(Text(verbatim: n))
                    .accessibilityIdentifier("ticketPass.number")
            } else {
                Image(systemName: state.systemImage).font(CYTypography.display).foregroundStyle(.black.opacity(0.55)).accessibilityHidden(true)
                Text(LocalizedStringKey("ticketWallet.status." + ticket.status.rawValue)).cyText(.cardTitle).foregroundStyle(.black.opacity(0.7))
            }
        }
        .padding(CYSpacing.md)
        .frame(width: side, height: side)
        .padding(CYSpacing.lg)
        .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityIdentifier("ticketPass.whiteTile")
    }

    private var hint: String {
        switch ticket.status {
        case .ready: return c.t("到场出示，无需截图。", "Show at the venue. No screenshot needed.")
        case .pending: return c.t("完成支付后，这张票就可以出示了。", "Once paid, this pass is ready to present.")
        case .verified: return c.t("这张票已核验使用。", "This pass has been used.")
        case .expired: return c.t("这张票已过期。", "This pass has expired.")
        case .cancelled: return c.t("这张票已取消。", "This pass was cancelled.")
        case .unknown: return "—"
        }
    }
}

private struct TicketPassTopHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}


/// MP signup wxml:105 `wl-start__play`: the shipped `icon_play.svg` in front of 开始游戏 / 查看记录.
/// The imageset is a template, so it takes the button's foreground colour.
struct TicketWalletPlayGlyph: View {
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 14
    var body: some View {
        MPAsset.FeatureIcon.iconPlay.renderingMode(.template).resizable().scaledToFit()
            .frame(width: side, height: side).accessibilityHidden(true)
    }
}
