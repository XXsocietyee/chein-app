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
                .background(CYColor.bgPage)
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
        .task(id: TaskKey(scope: reader.scope, token: loadToken, active: scenePhase == .active)) {
            // G-09: while the pass is open, re-read on the same lead as the entry code so a merchant
            // scan flips the chip (ready → verified) without a pull or a background trip.
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await load()
                do { try await Task.sleep(for: .seconds(TicketEntryCodeRefresh.leadSeconds)) } catch { return }
            }
        }
        .sensoryFeedback(.success, trigger: glowTick)
        .themeDomain(.player)
        .accessibilityIdentifier("ticketPass.sheet")
    }
    private struct TaskKey: Equatable { let scope: UUID; let token: Int; let active: Bool }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch phase {
        case .idle, .loading:
            ProgressView { Text(verbatim: c.t("正在打开票券", "Opening your pass")) }
            .accessibilityIdentifier("ticketPass.loading")
        case .loaded(let snapshot):
            if let ticket = current(in: snapshot) {
                ScrollView {
                    VStack(spacing: 16) {
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
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                                .accessibilityIdentifier("ticketPass.pager.position")
                        } else {
                            TicketPassCard(ticket: ticket, onVerified: { glowTick += 1 })
                        }
                        // G-056: Apple's Add to Apple Wallet button; hidden until a signed pass is available locally.
                        TicketAppleWalletPassButton(ticketID: ticket.id)
                        // PLY-21-3 / PLY-21-4: MP signup wxml:103-106 puts 开始游戏 (查看记录 once cleared) under the pass.
                        if playProvider != nil, ticket.status == .ready, ticket.action == .detail, !ticket.isWalletLocked,
                           TicketWalletPlayEntry.entry(ticket: ticket, requestedID: ticket.id) != nil {
                            Button { playDetailID = ticket.id } label: {
                                Group {
                                    if ticket.clearedFlag == true { Label { Text(verbatim: c.t("查看记录", "View record")) } icon: { TicketWalletPlayGlyph() } }
                                    else { Label { Text("playerJourney.start") } icon: { TicketWalletPlayGlyph() } }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .frame(maxWidth: 360)
                            .accessibilityIdentifier("ticketPass.play")
                        }
                        if let partial = snapshot.partialFailure {
                            Text(verbatim: c.t("部分票券没能读取，下拉或在菜单里刷新", "Some tickets did not load. Refresh from the menu."))
                                .font(.footnote).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("ticketPass.partial.\(partial.lane == .route ? "route" : "activity")")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .refreshable { loadToken += 1 }
            } else {
                ScrollView { emptyState }.refreshable { loadToken += 1 }
            }
        case .empty:
            ScrollView { emptyState }.refreshable { loadToken += 1 }
        case .failed:
            ScrollView {
                // G-058: system ContentUnavailableView states (Wallet's empty pass list), same copy and identifiers.
                if !reader.isAuthenticated {
                    ContentUnavailableView {
                        Label { Text(verbatim: c.t("登录后查看票券", "Sign in to see your pass")) } icon: { Image(systemName: "person.crop.circle") }
                    } description: {
                        Text(verbatim: c.t("登录后，你买到的票会出现在这里。", "Tickets you buy show up here once you're signed in."))
                    } actions: {
                        Button(action: onClose) { Text(verbatim: c.t("关闭", "Close")) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .accessibilityIdentifier("cy.state.empty.action")
                    }
                    .accessibilityIdentifier("cy.state.empty")
                } else {
                    ContentUnavailableView {
                        Label("cy.kit.server.title", systemImage: "exclamationmark.circle")
                    } description: {
                        Text("cy.kit.server.body")
                    } actions: {
                        Button("cy.kit.offline.retry") { loadToken += 1 }
                            .buttonStyle(.bordered).controlSize(.large)
                            .accessibilityIdentifier("cy.state.server.action")
                    }
                    .accessibilityIdentifier("cy.state.server")
                }
            }
            .refreshable { loadToken += 1 }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label { Text(verbatim: c.t("还没有票", "No tickets yet")) } icon: { Image(systemName: "ticket") }
        } actions: {
            Button(action: onOpenWallet) { Text(verbatim: c.t("查看全部票券", "All tickets")) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("cy.state.empty.action")
        }
        .accessibilityIdentifier("cy.state.empty")
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
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var state: CYPassState { CYPassState(ticket.status) }

    /// Native r2: the Wallet pass layout (system fill, perforation notch), no foil, tilt, flip or tear motion. The verified
    /// status shows on the code tile; the host plays the success haptic.
    var body: some View {
        front
            .onChange(of: ticket.status) { old, new in
                if new == .verified, old != .verified { onVerified?() }
            }
    }

    /// The live pass: the face every state starts on.
    private var front: some View {
        VStack(spacing: 0) {
            header
            // NAT-13 (native-r2): a plain separator like Wallet's pass back; no notched tear shape.
            Divider().padding(.vertical, 11)
            tile.padding(.horizontal).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .opacity(state.isRetired ? 0.74 : 1)
        .cyBrightnessBoost(ticket.status == .ready)
        .privacySensitive()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ticketPass.card")
    }

    /// Cover-art band (same art as the wallet pass), then the title, date and place below it (native r2: no scrim).
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                // R8-MEM-21-3: the MP `wImg` cover, else the shipped route illustration (`cover-route.svg`); no generated art.
                if let url = ticket.walletHTTPSCoverURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Rectangle().fill(.quaternary) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        MPAsset.BannerCover.coverRoute.resizable().scaledToFit().padding(12)
                            .opacity(0.5)
                            .accessibilityHidden(true)
                    }
                    .accessibilityHidden(true)
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 72 : 132)
            .clipped()
            VStack(alignment: .leading, spacing: 4) {
                // PLY-21-5: MP 票夹 cards carry no status (index.wxml:57-58 「卡上不写状态」).
                title.foregroundStyle(.primary).padding(.bottom, 4)
                Group {
                    Label { Text(verbatim: LocaleDisplay.civil(nonEmpty(ticket.participateDate), locale: locale)) } icon: { Image(systemName: "calendar") }
                    Label { Text(verbatim: nonEmpty(ticket.addressName)).lineLimit(2) } icon: { Image(systemName: "mappin.and.ellipse") }
                    // PLY-21-5: MP signup walletCard (index.js:777,784) appends ` · 已核销 x/y 家` and ` · N 大 M 小同享`.
                    if let progress = ticket.exploreProgress {
                        Label { Text("ticketPass.exploreProgress \(progress.redeemed) \(progress.required)") } icon: { Image(systemName: "checkmark.seal") }
                            .accessibilityIdentifier("ticketPass.exploreProgress")
                    }
                    if let party = ticket.party, party.childCount > 0 {
                        Label { Text("ticketPass.party \(party.adultCount) \(party.childCount)") } icon: { Image(systemName: "figure.and.child.holdinghands") }
                            .accessibilityIdentifier("ticketPass.party")
                    }
                }
                .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: some View {
        TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
            .font(.title3.weight(.semibold))
            .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("ticketPass.title")
    }

    /// Unknown reads as an em dash, never blank or 0.
    private func nonEmpty(_ s: String?) -> String { (s?.isEmpty == false) ? s! : "—" }

    @ViewBuilder private var tile: some View {
        VStack(spacing: 12) {
            // MP k4 (j2 F-22): a cleared ticket or a locked (upcoming / refunding) one issues no entry code (PLY-21-4).
            if let codeFactory, ticket.status == .ready, ticket.clearedFlag != true, !ticket.isWalletLocked {
                VerificationCodeView(model: codeFactory(.init(kind: .ticket, id: ticket.id)), embeddedQRSide: Self.qrSide)
                    .id(ticket.id)
            } else {
                whiteTile
            }
            Text(verbatim: hint).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Honest fallback, the same 240 pt white tile: the registration number for a ready ticket without a factory,
    /// otherwise the state glyph. Never a drawn code.
    private var whiteTile: some View {
        let side = Self.qrSide
        return VStack(spacing: 8) {
            if ticket.status == .ready, let n = ticket.registrationNumber, !n.isEmpty {
                Text(verbatim: n).font(.title2.weight(.semibold)).monospaced().foregroundStyle(.black)
                    .minimumScaleFactor(0.5).lineLimit(2).multilineTextAlignment(.center).textSelection(.enabled)
                    .accessibilityLabel(Text(verbatim: c.t("票号", "Ticket number"))).accessibilityValue(Text(verbatim: n))
                    .accessibilityIdentifier("ticketPass.number")
            } else {
                Image(systemName: state.systemImage).font(.largeTitle).foregroundStyle(.black.opacity(0.55)).accessibilityHidden(true)
                Text(LocalizedStringKey("ticketWallet.status." + ticket.status.rawValue)).font(.headline).foregroundStyle(.black.opacity(0.7))
            }
        }
        .padding(12)
        .frame(width: side, height: side)
        .padding(16)
        .background(.white)
        .accessibilityIdentifier("ticketPass.whiteTile")
    }

    private var hint: String {
        switch ticket.status {
        case .ready: return c.t("到场出示，无需截图。", "Show at the venue. No screenshot needed.")
        case .pending: return c.t("完成支付后，这张票就可以出示了。", "Once paid, this pass is ready to present.")
        case .verified: return c.t("这张票已核验使用。", "This pass has been used.")
        case .expired: return c.t("这张票已过期。", "This pass has expired.")
        case .cancelled: return c.t("这张票已取消。", "This pass was canceled.")
        case .unknown: return "—"
        }
    }
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
