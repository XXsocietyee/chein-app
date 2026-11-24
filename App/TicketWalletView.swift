import SwiftUI

/// Retain the reader in the session host. Host must observe session changes and use .id(reader.scope).
@MainActor struct TicketWalletView: View {
    let reader: any TicketWalletReading
    var onClose: (() -> Void)? = nil
    var onSignIn: (() -> Void)? = nil
    var makeTeamCoordinator: (() -> TeamCoordinator)? = nil
    var orderLifecycleCoordinator: OrderLifecycleCoordinator? = nil
    /// Source nav「+」去探索主题 (r3 票夹, hengyin 57815ec71). Hidden until the host wires it.
    var onExplore: (() -> Void)? = nil
    /// Topic page opens the wallet on this topic's ticket (`topicId` query). Nil keeps the first row.
    var focusTopicID: Int? = nil
    /// MP `signup/index?focusId=` (exact registration id): open that ticket. Not in the usable list → the
    /// registration read decides; still nothing → 未定位到原报名凭证 + 重试 (index.js:158-219).
    var focusRegistrationID: Int? = nil
    /// Pushed inside a host stack (deep link, topic, participation): no own NavigationStack (PLY-21-9).
    var isPushed = false
    @Environment(\.ticketWalletPendingOrderProvider) private var pendingOrderProvider
    @Environment(\.ticketWalletCompletionReader) private var completionReader
    @State private var walletFilter = TicketWalletFilter.all
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = TicketWalletScreenModel<TicketWalletSnapshot>()
    @State private var isVisible = false
    @State private var carouselTicketID: Int?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var refreshOnActive = false
    @State private var pendingOrderEntry = TicketWalletPendingOrderEntry()
    @State private var pendingOrderReadOwner: TicketWalletPendingOrderOwner?
    @State private var didFocusTopic = false
    @State private var focusPhase = TicketWalletFocusPhase.idle
    private var key: TicketWalletLoadKey { TicketWalletLoadKey(reader: reader) }
    var body: some View {
        let offeredPresentation = model.presentation
        let offeredPendingPresentation = pendingOrderEntry.presentationID
        // The reader wraps the stack, not the stack's root: as the root it made SwiftUI build a second list
        // whose disappearance cancelled the first load (TicketWalletFlowTests, 2026-11-14).
        ScrollViewReader { proxy in
        TicketWalletStack(embedded: !isPushed) {
            List {
                if !reader.isAuthenticated {
                    TicketWalletIssueView(issue: .login)
                    if let onSignIn {
                        CYPillButton("ticketWallet.signIn", action: onSignIn)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("ticketWallet.signIn")
                    }
                } else if !reader.isConfigured { TicketWalletIssueView(issue: .notConfigured) }
                else if model.isLoading || model.loadedOwner != key { CYSkeleton().listRowBackground(Color.clear).accessibilityLabel(Text("mpfresh.ticketWallet.loading", tableName: "MpFresh")) }
                else if let issue = model.issue(owner: key) {
                    // Source failure title 票夹没能打开 precedes the specific reason.
                    Text("ticketWallet.parity.error.title").cyText(.sectionTitle)
                        .accessibilityIdentifier("ticketWallet.errorTitle")
                    TicketWalletIssueView(issue: issue, retry: { schedule(model.presentation ?? model.beginPresentation(owner: key)) })
                } else if let snapshot = model.value(owner: key) {
                    focusSection
                    if snapshot.tickets.isEmpty {
                        // A partial empty response never claims the whole wallet is empty. MP empty is「还没有票」, no sub line.
                        ContentUnavailableView {
                            Label {
                                Text(LocalizedStringKey(snapshot.partialFailure == nil ? "ticketWallet.empty" : "ticketWallet.partialEmpty"))
                                    .accessibilityIdentifier("ticketWallet.empty")
                            } icon: { Image(systemName: "ticket") }
                        }
                        .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.md)
                        .listRowBackground(Color.clear)
                    }
                    let shown = filtered(snapshot.tickets)
                    if !snapshot.tickets.isEmpty && shown.isEmpty {
                        // Source filter 即将开始 / 已通关 with no match: say so instead of an empty wallet.
                        Text(LocalizedStringKey(walletFilter.emptyKey), tableName: "MpFresh")
                            .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.lg)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("ticketWallet.filterEmpty")
                    }
                    ticketCarousel(shown)
                    // Source preserves both lanes and row order, including repeated server IDs.
                    ForEach(Array(snapshot.tickets.enumerated()).filter { shown.contains($0.element) }, id: \.offset) { rowIndex, ticket in
                        if ticket.action == .detail && !ticket.isWalletLocked {
                            NavigationLink {
                                TicketWalletDetailView(id: ticket.id, reader: reader, lifecycleCoordinator: orderLifecycleCoordinator, makeTeamCoordinator: makeTeamCoordinator)
                            } label: { TicketWalletRow(ticket: ticket) }
                            .buttonStyle(QuestifyCardButtonStyle())
                            .questifyHidesLinkIndicator()
                            .accessibilityIdentifier("ticketWallet.row.\(ticket.id)")
                            .questifyCardListRow()
                            .id(rowIndex)
                        } else if let provider = pendingOrderProvider, pendingOrderReadOwner == provider.owner,
                                  pendingOrderEntry.canOpen(ticket: ticket, reader: reader, provider: provider) {
                            Button {
                                guard let offeredPresentation, !model.isLoading,
                                      model.accepts(offeredPresentation, currentOwner: key),
                                      pendingOrderReadOwner == provider.owner,
                                      let current = model.value(owner: key) else { return }
                                pendingOrderEntry.activate(ticket: ticket, rowIndex: rowIndex, snapshot: current,
                                    reader: reader, provider: provider, presentationID: offeredPendingPresentation)
                            } label: { TicketWalletRow(ticket: ticket, showsPendingOrderAction: true) }
                            .buttonStyle(QuestifyCardButtonStyle())
                            .accessibilityIdentifier("ticketWallet.pendingOrder.open.\(ticket.id)")
                            .questifyCardListRow()
                            .id(rowIndex)
                        } else {
                            TicketWalletRow(ticket: ticket)
                                .accessibilityIdentifier("ticketWallet.row.\(ticket.id)")
                                .questifyCardListRow()
                                .id(rowIndex)
                        }
                    }
                }
                if reader.isAuthenticated, let makeTeamCoordinator {
                    Section {
                        NavigationLink {
                            TeamHomeView(coordinator: makeTeamCoordinator(), makeCoordinator: makeTeamCoordinator)
                                .cyPushedChrome(domain: .player)
                        } label: {
                            Label("team.title", systemImage: "person.3")
                        }
                        .accessibilityIdentifier("ticketWallet.teams")
                    }
                }
                // MP F-R2U-01: one lane failing leaves the other lane's tickets on screen with a quiet note, no red block.
                if let partial = model.value(owner: key)?.partialFailure {
                    Text(LocalizedStringKey(partial.lane == .route ? "ticketWallet.partial.route" : "ticketWallet.partial.activity"))
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        .accessibilityIdentifier("ticketWallet.partialFailure")
                }
            }
            .listStyle(.insetGrouped)
            .cyDomainScreen(.player)
            .listSectionSpacing(20)
            .cyPageTitle("ticketWallet.title")
            .cyHideTabBar()
            .toolbar {
                if let onClose { ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) } }
                if completionReader != nil, reader.isAuthenticated, model.value(owner: key)?.tickets.isEmpty == false {
                    ToolbarItem(placement: .principal) { filterMenu }
                }
                if let onExplore {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: onExplore) { Label { Text("mpfresh.ticketWallet.explore", tableName: "MpFresh") } icon: { Image(systemName: "plus") } }
                            .accessibilityIdentifier("ticketWallet.explore")
                    }
                }
            }
            .onChange(of: key) { _, _ in replacePresentation() }
            .onChange(of: pendingOrderProvider?.owner) { _, _ in replacePresentation() }
            .navigationDestination(item: $carouselTicketID) { id in
                TicketWalletDetailView(id: id, reader: reader, lifecycleCoordinator: orderLifecycleCoordinator, makeTeamCoordinator: makeTeamCoordinator)
                    .cyPushedChrome(domain: .player)
            }
            .navigationDestination(item: $pendingOrderEntry.target) { target in
                if let provider = pendingOrderProvider, pendingOrderReadOwner == provider.owner,
                   !model.isLoading, let snapshot = model.value(owner: key),
                   pendingOrderEntry.matches(target, snapshot: snapshot, reader: reader, provider: provider),
                   let destination = provider.destination(target: target, reader: reader) {
                    destination.id(provider.owner)
                        .cyPushedChrome(domain: .player)
                }
            }
            .refreshable {
                let current = model.presentation ?? model.beginPresentation(owner: key)
                if let current, model.accepts(current, currentOwner: key) { retirePendingOrder() }
                await model.refresh(presentation: current, currentOwner: key) { await load(presentation: $0) }
            }
            .onAppear { isVisible = true; refreshOnActive = false; pendingOrderEntry.appear(); replacePresentation() }
            .onDisappear { isVisible = false; model.endPresentation(); pendingOrderEntry.disappear() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { refreshOnActive = true; model.endPresentation() }
                if phase == .background { pendingOrderEntry.disappear() }
                else if phase == .active && isVisible && (refreshOnActive || model.presentation == nil) {
                    refreshOnActive = false
                    pendingOrderEntry.appear()
                    replacePresentation()
                }
            }
            .accessibilityIdentifier("ticketWallet.list")
            .appSwitcherPrivacyShield()
            .onAppear { focusTopic(proxy) }
            .onChange(of: model.value(owner: key)?.tickets.map(\.id)) { _, _ in focusTopic(proxy); focusRegistration(proxy) }
            .onChange(of: model.isLoading) { _, loading in if !loading { focusRegistration(proxy) } }
            .task { await followFocusedRegistration() }
        }
        }
    }
    /// PLY-21-2: open the focused registration once. In the usable list → scroll to it and open its detail (the detail
    /// re-reads `registration/info` by id). Not in the usable list → `ticketDetail` decides; a miss stays
    /// 未定位到原报名凭证 + 重试 (MP index.js:158-219).
    private func focusRegistration(_ proxy: ScrollViewProxy) {
        guard let focusRegistrationID, focusPhase == .idle, let tickets = model.value(owner: key)?.tickets else { return }
        guard let index = tickets.firstIndex(where: { $0.id == focusRegistrationID }) else { focusPhase = .resolving; return }
        focusPhase = .found
        proxy.scrollTo(index, anchor: .center)
        if !tickets[index].isWalletLocked { carouselTicketID = focusRegistrationID }
    }
    /// Waits until the usable list misses `focusId`, then reads that registration. One read at a time.
    private func followFocusedRegistration() async {
        guard focusRegistrationID != nil else { return }
        while !Task.isCancelled {
            if focusPhase == .found { return }
            if focusPhase == .resolving, let id = focusRegistrationID {
                await readFocusedRegistration(id)
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    private func readFocusedRegistration(_ id: Int) async {
        do {
            let ticket = try await reader.ticketDetail(id: id)
            guard !Task.isCancelled, focusPhase == .resolving, focusRegistrationID == id else { return }
            guard ticket.id == id else { focusPhase = .missing; return }
            focusPhase = .found
            carouselTicketID = id
        } catch is CancellationError {
            return
        } catch {
            guard focusPhase == .resolving, focusRegistrationID == id else { return }
            focusPhase = .missing
        }
    }
    @ViewBuilder private var focusSection: some View {
        if focusPhase == .resolving {
            ProgressView()
                .accessibilityLabel(Text("ticketWallet.loading"))
                .frame(maxWidth: .infinity, minHeight: 44)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("ticketWallet.focus.resolving")
        } else if focusPhase == .missing {
            CYStateView(content: .empty(glyph: "ticket", title: appLocalized("ticketWallet.focus.missing", locale: locale),
                                        body: "", actionTitle: appLocalized("ticketWallet.focus.retry", locale: locale)),
                        onPrimary: { focusPhase = .idle; schedule(model.presentation ?? model.beginPresentation(owner: key)) },
                        compact: true)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("ticketWallet.focus.missing")
        }
    }
    private func focusTopic(_ proxy: ScrollViewProxy) {
        guard !didFocusTopic, let focusTopicID, let tickets = model.value(owner: key)?.tickets,
              let index = TicketWalletTopicFocus.index(in: tickets, topicID: focusTopicID) else { return }
        didFocusTopic = true
        proxy.scrollTo(index, anchor: .center)
    }
    private func replacePresentation() {
        retirePendingOrder()
        guard isVisible, scenePhase == .active else {
            // Launch can make the list appear while the scene is still inactive; load once it turns active.
            if isVisible { refreshOnActive = true }
            model.endPresentation(preservingValues: false); return
        }
        schedule(model.beginPresentation(owner: key))
    }
    private func retirePendingOrder() {
        pendingOrderEntry.retire(); pendingOrderReadOwner = nil
    }
    private func schedule(_ permit: TicketWalletReadPresentation?) {
        if let permit, model.accepts(permit, currentOwner: key) { retirePendingOrder() }
        model.schedule(presentation: permit, currentOwner: key) { await load(presentation: $0) }
    }
    private func load(presentation: TicketWalletReadPresentation) async {
        guard isVisible, scenePhase == .active, !Task.isCancelled,
              model.accepts(presentation, currentOwner: key) else { return }
        retirePendingOrder()
        let captured = key
        let provider = pendingOrderProvider
        // MP F13: the wallet holds usable tickets only, in walletOrder (PLY-21-1). Unpaid ones live in 我的订单.
        await model.load(presentation: presentation, currentOwner: { key }) { try await reader.ticketWallet().walletUsable }
        if !Task.isCancelled, model.accepts(presentation, currentOwner: key), captured == key,
           let provider, provider.owner == pendingOrderProvider?.owner, provider.matches(reader: reader),
           model.value(owner: captured) != nil {
            pendingOrderReadOwner = provider.owner
        }
    }
}

extension TicketWalletView {
    /// Source「票夹 ▾」pop-over (全部 / 即将开始 / 已通关, split by server topicCompleted; hengyin 91aab64b4).
    fileprivate var filterMenu: some View {
        Menu {
            Picker(selection: $walletFilter) {
                ForEach(TicketWalletFilter.allCases, id: \.self) { filter in
                    Text(LocalizedStringKey(filter.titleKey), tableName: "MpFresh").tag(filter)
                }
            } label: { EmptyView() }
        } label: {
            HStack(spacing: CYSpacing.xs) {
                Text(LocalizedStringKey(walletFilter.navKey), tableName: "MpFresh").font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).accessibilityHidden(true)
            }
            .foregroundStyle(CYColor.textPrimary)
        }
        .accessibilityLabel(Text("mpfresh.ticketWallet.filter.a11y \(Text(LocalizedStringKey(walletFilter.titleKey), tableName: "MpFresh"))", tableName: "MpFresh"))
        .accessibilityIdentifier("ticketWallet.filter")
    }
    fileprivate func filtered(_ tickets: [TicketWalletTicket]) -> [TicketWalletTicket] {
        guard walletFilter != .all, let completionReader else { return tickets }
        return tickets.filter { ticket in
            // Unknown completion stays in 全部 only; it is never guessed into either bucket.
            guard let done = completionReader.topicCompleted(ticket) else { return false }
            return walletFilter == .completed ? done : !done
        }
    }
    /// Glass carousel entry over the openable tickets (detail action only, same destination as the rows below). Two or more tickets;
    /// accessibility Dynamic Type sizes skip it and keep the vertical rows.
    @ViewBuilder fileprivate func ticketCarousel(_ tickets: [TicketWalletTicket]) -> some View {
        let openable = Array(tickets.enumerated()).filter { $0.element.action == .detail }.prefix(12)
        if openable.count >= 2 && !dynamicTypeSize.isAccessibilitySize {
            let slides = openable.map { offset, ticket in
                CYCarouselSlide(id: "\(offset)-\(ticket.id)", seed: "ticket-\(ticket.id)",
                                title: ticket.title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? appLocalized("ticketWallet.untitled", locale: locale),
                                date: ticket.participateDate, place: ticket.addressName, badge: statusTitle(ticket.status),
                                kind: .ticket, dimmed: ticket.status == .cancelled || ticket.status == .expired)
            }
            Section {
                CYCarouselRail(phase: .loaded(Array(slides)), railLabel: "carousel.tickets", onOpen: { key in
                    if let match = openable.first(where: { "\($0.offset)-\($0.element.id)" == key }) { carouselTicketID = match.element.id }
                }) { EmptyView() }
                    .questifyCardListRow()
            }
        }
    }
    private func statusTitle(_ status: TicketWalletStatus) -> String {
        switch status {
        case .ready: return appLocalized("ticketWallet.status.ready", locale: locale)
        case .pending: return appLocalized("ticketWallet.status.pending", locale: locale)
        case .verified: return appLocalized("ticketWallet.status.verified", locale: locale)
        case .cancelled: return appLocalized("ticketWallet.status.cancelled", locale: locale)
        case .expired: return appLocalized("ticketWallet.status.expired", locale: locale)
        case .unknown: return appLocalized("ticketWallet.status.unknown", locale: locale)
        }
    }
}

/// A sheet-hosted wallet owns its stack; a pushed wallet uses the host's (no nested bar, working back).
private struct TicketWalletStack<Content: View>: View {
    let embedded: Bool
    @ViewBuilder var content: Content
    var body: some View {
        if embedded { NavigationStack { content } } else { content }
    }
}

enum TicketWalletFocusPhase: Equatable { case idle, resolving, found, missing }

extension TicketWalletTicket {
    /// MP `wLocked`: an upcoming or refunding ticket stays in the wallet but does not open (no code, no start).
    var isWalletLocked: Bool { isUpcoming || isRefunding }
}

/// Ticket stub outline: rounded card with a semicircular notch cut from both sides at `notchY` (the perforation line).
struct TicketStubShape: Shape {
    var notchY: CGFloat
    var radius: CGFloat = 22
    var notch: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        if notchY < 0 { return p }
        let y = min(max(notchY, radius + notch), rect.height - radius - notch)
        p.addEllipse(in: CGRect(x: rect.minX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        p.addEllipse(in: CGRect(x: rect.maxX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        return p
    }
}
private struct TicketTopHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct TicketWalletRow: View {
    let ticket: TicketWalletTicket
    var showsPendingOrderAction = false
    @Environment(\.ticketWalletCompletionReader) private var completionReader
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var topHeight: CGFloat = 140
    /// R7-MEM-21-3: activity image, else topic image. The illustration stays only when that URL is absent.
    /// PLY-21-15: token colours only, one tint per id so neighbouring cards still differ.
    private var httpsCover: URL? {
        guard let raw = ticket.coverURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, raw.utf8.count <= 512,
              !raw.contains("\\"),
              !raw.contains(where: \.isWhitespace),
              let url = URL(string: raw),
              url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil else { return nil }
        return url
    }
    private var art: [Color] {
        let tints: [Color] = [CYColor.brandStrong, CYColor.gameAccent, CYColor.rare, CYColor.coverFallback]
        return tints[abs(ticket.id) % tints.count]
    }
    private var coverIllustration: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: art, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "ticket.fill").resizable().scaledToFit().frame(width: 120, height: 120).rotationEffect(.degrees(-14))
                .foregroundStyle(.white.opacity(0.07)).offset(x: 90, y: -10).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .accessibilityHidden(true)
    }
    private var hasStub: Bool {
        (ticket.participateDate?.isEmpty == false) || (ticket.addressName?.isEmpty == false) || ticket.needsScheduleSync
            || ticket.action != .detail || ticket.walletTypeKey != nil || showsPendingOrderAction
    }
    var body: some View {
        let dimmed = ticket.status == .cancelled || ticket.status == .expired || ticket.isWalletLocked
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let url = httpsCover {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            CYColor.bgSurfaceStrong
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .clipped()
                    .accessibilityHidden(true)
                    LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else {
                    coverIllustration
                }
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    // Owner rule (MP 2026-10-28): no status on the card. Only the MP tag: M月D日开始 / 退款中 / 已通关 / 未通关.
                    TicketWalletCardTag(ticket: ticket)
                    TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                        .cyText(.sectionTitle).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if ticket.clearedFlag == nil { completionCaption }
                }
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(alignment: .topTrailing) {
                // MP signup wxml:64 `wc__go`: round tinted badge with the shipped `icon_go.svg` arrow. Decorative; the card is the control.
                MPAsset.FeatureIcon.iconGo.resizable().scaledToFit().frame(width: 14, height: 14)
                    .frame(width: 31, height: 31)
                    .background(Circle().fill(tint))
                    .padding(CYSpacing.md)
                    .accessibilityHidden(true)
            }
            .background(GeometryReader { Color.clear.preference(key: TicketTopHeightKey.self, value: $0.size.height) })
            .overlay(alignment: .bottom) { Rectangle().fill(.clear).frame(height: 0) }
            if hasStub {
            // Perforation
            Line().stroke(CYColor.textPrimary.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .frame(height: 1).padding(.horizontal, 22)
            HStack(alignment: .center, spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xs + 2) {
                    if let date = ticket.participateDate, !date.isEmpty {
                        QuestifyMetadataLine(label: "ticketWallet.participateDate", value: date, systemImage: "calendar")
                    }
                    if let place = ticket.addressName, !place.isEmpty {
                        QuestifyMetadataLine(label: "ticketWallet.place", value: place, systemImage: "mappin.and.ellipse")
                    }
                    if ticket.needsScheduleSync {
                        Label { Text("ticketWallet.p2.notice.scheduleSync").fixedSize(horizontal: false, vertical: true) }
                            icon: { Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true) }
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("ticketWallet.scheduleSync.\(ticket.id)")
                    }
                    if ticket.action != .detail {
                        Label { Text(LocalizedStringKey(ticket.sourceNoticeKey)).fixedSize(horizontal: false, vertical: true) }
                            icon: { Image(systemName: "info.circle").accessibilityHidden(true) }
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("ticketWallet.sourceNotice.\(ticket.id)")
                    }
                    if let type = ticket.walletTypeKey {
                        // MP card sub-line: 类型 · 剩 N 天 / 今天过期 (signup/index.js walletCard). Unknown date → type only.
                        TicketWalletSubline(ticket: ticket, typeKey: type)
                            .accessibilityIdentifier("ticketWallet.subline.\(ticket.id)")
                    }
                    if showsPendingOrderAction {
                        Label { Text("ticketPendingOrder.open", tableName: "TicketPendingOrder") } icon: { Image(systemName: "list.bullet.rectangle") }
                            .cyText(.label, weight: .semibold).foregroundStyle(CYColor.textPrimary)
                    }
                }
                Spacer(minLength: 0)
                // PLY-21-15: no decorative QR glyph; the code is only on the pass.
            }
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated)
            }
        }
        .onPreferenceChange(TicketTopHeightKey.self) { topHeight = $0 }
        .clipShape(TicketStubShape(notchY: hasStub ? topHeight : -1), style: FillStyle(eoFill: true))
        .opacity(dimmed ? 0.62 : 1)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    /// Completed shows 已通关. Absent hides that line. A non-boolean shows an em dash.
    @ViewBuilder private var completionCaption: some View {
        if let completionReader, completionReader.topicCompleted(ticket) == true {
            Text("mpfresh.ticketWallet.filter.completed", tableName: "MpFresh")
                .cyText(.bodyMedium).foregroundStyle(.white.opacity(0.92))
                .accessibilityIdentifier("ticketWallet.topicCompleted.\(ticket.id)")
        } else if let completionReader, completionReader.topicCompleted(ticket) == nil, ticket.topicCompletion == .unknown {
            Text("mpfresh.ticketWallet.completion.unknown", tableName: "MpFresh")
                .cyText(.bodyMedium).foregroundStyle(.white.opacity(0.92))
                .accessibilityLabel(Text("mpfresh.ticketWallet.completion.unknownLabel", tableName: "MpFresh"))
                .accessibilityIdentifier("ticketWallet.topicCompleted.unknown.\(ticket.id)")
        }
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p }
    }
}

/// MP F13 tag. Upcoming「M月D日开始」(or 即将开始), 退款中, 已通关 / 未通关; nothing otherwise.
private struct TicketWalletCardTag: View {
    let ticket: TicketWalletTicket
    var body: some View {
        if ticket.isUpcoming {
            if let start = ticket.upcomingStartMonthDay {
                CYStatusChip("ticketWallet.tag.startsOn \(start.month) \(start.day)", tone: .info)
            } else { CYStatusChip("ticketWallet.tag.upcoming", tone: .info) }
        } else if ticket.isRefunding {
            CYStatusChip("ticketWallet.tag.refunding", tone: .warning)
        } else if let cleared = ticket.clearedFlag {
            CYStatusChip(cleared ? "ticketWallet.tag.cleared" : "ticketWallet.tag.notCleared", tone: cleared ? .success : .neutral)
                .accessibilityIdentifier("ticketWallet.topicCompleted.\(ticket.id)")
        }
    }
}

/// 类型 · 剩 N 天 / 今天过期. Natural days in Beijing time, as the MP `passDaysLeft`. Upcoming and session tickets
/// show the type only (their time is on the stub lines).
private struct TicketWalletSubline: View {
    let ticket: TicketWalletTicket
    let typeKey: String
    var body: some View {
        if let days = ticket.walletDaysLeft {
            if days == 0 {
                (Text(LocalizedStringKey(typeKey)) + Text(verbatim: " · ") + Text("ticketWallet.subline.today"))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            } else {
                (Text(LocalizedStringKey(typeKey)) + Text(verbatim: " · ") + Text("ticketWallet.subline.daysLeft \(days)"))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        } else {
            Text(LocalizedStringKey(typeKey)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
    }
}

extension TicketWalletTicket {
    /// MP `wType`: 城市定向 / 自由探索 for route tickets, 场次 for sessions. Unknown lane → nil (no sub-line).
    var walletTypeKey: String? {
        switch lane {
        case .route?: return productType == 2 ? "ticketWallet.type.explore" : "ticketWallet.type.route"
        case .activity?: return "ticketWallet.type.session"
        case nil: return nil
        }
    }
    /// Whole days from today to `usableUntil` (Beijing calendar). Nil when upcoming, a session ticket, or no date.
    var walletDaysLeft: Int? {
        guard !isUpcoming, lane == .route, let until = TicketWalletTicket.sourceDate(usableUntil ?? endDate) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: until)).day
        return days.map { max(0, $0) }
    }
}

/// Full-width white pill at the foot of a ticket card. Not a separate button: the card handles the tap.
private struct TicketWalletCardAction: View {
    let title: Text
    let systemImage: String
    init(title: LocalizedStringKey, systemImage: String) { self.title = Text(title); self.systemImage = systemImage }
    init(title: Text, systemImage: String) { self.title = title; self.systemImage = systemImage }
    var body: some View {
        OrderPillLabel(title: title, systemImage: systemImage, fullWidth: true)
    }
}
