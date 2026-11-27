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
    @EnvironmentObject private var session: AppSession
    @State private var companions: [WalletSeatInvitation] = []
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
                        Button(action: onSignIn) { Text("ticketWallet.signIn").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                            .accessibilityIdentifier("ticketWallet.signIn")
                    }
                } else if !reader.isConfigured { TicketWalletIssueView(issue: .notConfigured) }
                else if model.isLoading || model.loadedOwner != key { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("mpfresh.ticketWallet.loading", tableName: "MpFresh")) }
                else if let issue = model.issue(owner: key) {
                    // Source failure title 票夹没能打开 precedes the specific reason.
                    Text("ticketWallet.parity.error.title").font(.headline)
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
                        } actions: {
                            // mp-mine r3: MP signup empty shell has one primary 去探索 (goExplore → 首页).
                            if let onExplore, snapshot.partialFailure == nil {
                                Button(action: onExplore) { Text("ticketWallet.emptyExplore") }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("ticketWallet.empty.explore")
                            }
                        }
                    }
                    // R9-MEM-NIT-1: the MP signup wallet has no filter (signup/index.wxml), so every ticket shows.
                    let shown = snapshot.tickets
                    // NAT-12 (native-r2): MP signup/index.wxml has no swiper; the rows are the one list (no app-only carousel).
                    // Source preserves both lanes and row order, including repeated server IDs.
                    ForEach(Array(shown.enumerated()), id: \.offset) { rowIndex, ticket in
                        if ticket.action == .detail && !ticket.isWalletLocked {
                            NavigationLink {
                                TicketWalletDetailView(id: ticket.id, reader: reader, lifecycleCoordinator: orderLifecycleCoordinator, makeTeamCoordinator: makeTeamCoordinator)
                            } label: { TicketWalletRow(ticket: ticket) }
                            .accessibilityIdentifier("ticketWallet.row.\(ticket.id)")
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
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("ticketWallet.pendingOrder.open.\(ticket.id)")
                            .id(rowIndex)
                        } else {
                            TicketWalletRow(ticket: ticket)
                                .accessibilityIdentifier("ticketWallet.row.\(ticket.id)")
                                .id(rowIndex)
                        }
                    }
                }
                if !companions.isEmpty {
                    // R8-MEM-21-1: companion seats join the wallet as 同伴席位 rows (MP signup index.js:293-300).
                    Section {
                        ForEach(companions, id: \.invitationID) { seat in
                            TicketWalletCompanionCard(seat: seat)
                        }
                    }
                    .accessibilityIdentifier("ticketWallet.companions")
                }
                // MP F-R2U-01: one lane failing leaves the other lane's tickets on screen with a quiet note, no red block.
                if let partial = model.value(owner: key)?.partialFailure {
                    Text(LocalizedStringKey(partial.lane == .route ? "ticketWallet.partial.route" : "ticketWallet.partial.activity"))
                        .font(.footnote).foregroundStyle(.secondary)
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
                // PLY-21-8 MP-first: signup/index.wxml:16-18 (F13) has no status filter; one list, so no 票夹 ▾ menu.
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
                // Stay on the permit this screen already holds. Refresh does not open another read.
                let current = model.presentation
                guard let current, model.accepts(current, currentOwner: key) else { return }
                retirePendingOrder()
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
            .onChange(of: model.isLoading) { _, loading in
                if !loading { focusRegistration(proxy) }
                // Components r1 C1: a session starting soon counts down on the Lock Screen / Dynamic Island.
                if !loading, let tickets = model.value(owner: key)?.tickets {
                    QuestLiveActivityCenter.shared.eventCountdown(tickets: tickets)
                }
            }
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
            // R8-MEM-21-2: MP index.js:200-203 also needs a paid registration (`registrationStatus == 2`) on a
            // topic or activity (`ownerType` 1/2), and a present `memberId` must be the signed-in member
            // (`row.memberId != null && String(row.memberId) !== owner`); anything else is 未定位到原报名凭证.
            guard ticket.id == id, ticket.registrationStatus == 2, ticket.ownerType == 1 || ticket.ownerType == 2 else {
                focusPhase = .missing; return
            }
            if let memberID = ticket.memberID {
                guard let owner = session.currentRuntimeDependencyContext?.session.accountID, memberID == String(owner) else {
                    focusPhase = .missing; return
                }
            }
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
                .accessibilityIdentifier("ticketWallet.focus.resolving")
        } else if focusPhase == .missing {
            CYStateView(content: .empty(glyph: "ticket", title: appLocalized("ticketWallet.focus.missing", locale: locale),
                                        body: "", actionTitle: appLocalized("ticketWallet.focus.retry", locale: locale)),
                        onPrimary: { focusPhase = .idle; schedule(model.presentation ?? model.beginPresentation(owner: key)) },
                        compact: true)
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
        else { companions = [] }
        model.schedule(presentation: permit, currentOwner: key) { await load(presentation: $0) }
    }
    /// R8-MEM-21-1: companion cards on the wallet. A failed read shows no error and no entry code.
    private func loadCompanions() async {
        guard reader.isAuthenticated,
              let token = session.token, AuthRequestBuilder.isValidToken(token),
              let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else {
            companions = []
            return
        }
        companions = await WalletSeatInvitationSource(configuration: configuration, transport: session.runtimeHTTPTransport).load(token: token)
    }

    private func load(presentation: TicketWalletReadPresentation) async {
        guard isVisible, scenePhase == .active, !Task.isCancelled,
              model.accepts(presentation, currentOwner: key) else { return }
        retirePendingOrder()
        let captured = key
        let provider = pendingOrderProvider
        // MP F13: the wallet holds usable tickets only, in walletOrder (PLY-21-1). Unpaid ones live in 我的订单.
        await model.load(presentation: presentation, currentOwner: { key }) { try await reader.ticketWallet().walletUsable }
        if !Task.isCancelled, model.accepts(presentation, currentOwner: key), captured == key {
            await loadCompanions()
        }
        if !Task.isCancelled, model.accepts(presentation, currentOwner: key), captured == key,
           let provider, provider.owner == pendingOrderProvider?.owner, provider.matches(reader: reader),
           model.value(owner: captured) != nil {
            pendingOrderReadOwner = provider.owner
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

extension TicketWalletTicket {
    /// The wallet cover (`coverURL`) only when it is a plain https URL; shared by the row and the pass sheet (R8-MEM-21-3).
    var walletHTTPSCoverURL: URL? {
        guard let raw = coverURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, raw.utf8.count <= 512,
              !raw.contains("\\"),
              !raw.contains(where: \.isWhitespace),
              let url = URL(string: raw),
              url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil else { return nil }
        return url
    }
}

/// Native r2: one inset-grouped list row (artwork thumbnail, tag, title, facts), no card chrome, scrim or shadow.
private struct TicketWalletRow: View {
    let ticket: TicketWalletTicket
    var showsPendingOrderAction = false
    @Environment(\.ticketWalletCompletionReader) private var completionReader
    @ScaledMetric(relativeTo: .body) private var thumb: CGFloat = 60
    /// R7-MEM-21-3: activity image, else topic image. The MP illustration stays only when that URL is absent.
    private var httpsCover: URL? { ticket.walletHTTPSCoverURL }
    private var coverIllustration: some View {
        // MP signup wxml:68 `wc__im--illus`: with no cover the card shows the shipped route illustration (cover-route.svg).
        MPAsset.BannerCover.coverRoute.resizable().scaledToFit().padding(6)
            .background(Color(uiColor: .tertiarySystemFill))
            .accessibilityHidden(true)
    }
    var body: some View {
        let dimmed = ticket.status == .cancelled || ticket.status == .expired || ticket.isWalletLocked
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let url = httpsCover {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color(uiColor: .tertiarySystemFill)
                        }
                    }
                } else {
                    coverIllustration
                }
            }
            .frame(width: thumb, height: thumb)
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                // Owner rule (MP 2026-10-28): no status on the card. Only the MP tag: M月D日开始 / 退款中 / 已通关 / 未通关.
                TicketWalletCardTag(ticket: ticket)
                TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                    .font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if ticket.clearedFlag == nil { completionCaption }
                if let date = ticket.participateDate, !date.isEmpty {
                    QuestifyMetadataLine(label: "ticketWallet.participateDate", value: date, systemImage: "calendar")
                }
                if let place = ticket.addressName, !place.isEmpty {
                    QuestifyMetadataLine(label: "ticketWallet.place", value: place, systemImage: "mappin.and.ellipse")
                }
                if ticket.needsScheduleSync {
                    Label { Text("ticketWallet.p2.notice.scheduleSync").fixedSize(horizontal: false, vertical: true) }
                        icon: { Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true) }
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("ticketWallet.scheduleSync.\(ticket.id)")
                }
                if ticket.action != .detail {
                    Label { Text(LocalizedStringKey(ticket.sourceNoticeKey)).fixedSize(horizontal: false, vertical: true) }
                        icon: { Image(systemName: "info.circle").accessibilityHidden(true) }
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("ticketWallet.sourceNotice.\(ticket.id)")
                }
                if ticket.walletTypeKey != nil || ticket.showsSharedParty || ticket.exploreProgress != nil {
                    // MP card sub-line: 类型 · 剩 N 天, then 已核销 x/y 家 and N 大 M 小同享 (signup/index.js walletCard).
                    TicketWalletSubline(ticket: ticket, typeKey: ticket.walletTypeKey)
                        .accessibilityIdentifier("ticketWallet.subline.\(ticket.id)")
                }
                if showsPendingOrderAction {
                    Label { Text("ticketPendingOrder.open", tableName: "TicketPendingOrder") } icon: { Image(systemName: "list.bullet.rectangle") }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                }
                // PLY-21-15: no decorative QR glyph; the code is only on the pass.
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .opacity(dimmed ? 0.6 : 1)
    }
    /// Completed shows 已通关. Absent hides that line. A non-boolean shows an em dash.
    @ViewBuilder private var completionCaption: some View {
        if let completionReader, completionReader.topicCompleted(ticket) == true {
            Text("mpfresh.ticketWallet.filter.completed", tableName: "MpFresh")
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("ticketWallet.topicCompleted.\(ticket.id)")
        } else if let completionReader, completionReader.topicCompleted(ticket) == nil, ticket.topicCompletion == .unknown {
            Text("mpfresh.ticketWallet.completion.unknown", tableName: "MpFresh")
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityLabel(Text("mpfresh.ticketWallet.completion.unknownLabel", tableName: "MpFresh"))
                .accessibilityIdentifier("ticketWallet.topicCompleted.unknown.\(ticket.id)")
        }
    }
}

/// MP F13 tag. Upcoming「M月D日开始」(or 即将开始), 退款中, 已通关 / 未通关; nothing otherwise.
private struct TicketWalletCardTag: View {
    let ticket: TicketWalletTicket
    var body: some View {
        if ticket.isUpcoming {
            if let soon = Self.startsSoon(ticket) {
                // Design pass me (P2, P5): within a day of the start the tag ticks down like the event's Live Activity.
                Label {
                    HStack(spacing: 4) {
                        Text("passme.ticket.startsIn")
                        CYCountdown(until: soon, style: nil, tint: nil)
                    }
                } icon: { Image(systemName: "timer").foregroundStyle(.blue) }
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ticketWallet.startsIn.\(ticket.id)")
            } else if let start = ticket.upcomingStartMonthDay {
                Label { Text("ticketWallet.tag.startsOn \(start.month) \(start.day)") } icon: { Image(systemName: "calendar").foregroundStyle(.blue) }
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Label { Text("ticketWallet.tag.upcoming") } icon: { Image(systemName: "calendar").foregroundStyle(.blue) }
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else if ticket.isRefunding {
            Label { Text("ticketWallet.tag.refunding") } icon: { Image(systemName: "arrow.uturn.backward.circle").foregroundStyle(.orange) }
                .font(.footnote).foregroundStyle(.secondary)
        } else if let cleared = ticket.clearedFlag {
            Label {
                Text(LocalizedStringKey(cleared ? "ticketWallet.tag.cleared" : "ticketWallet.tag.notCleared"))
            } icon: {
                Image(systemName: cleared ? "checkmark.seal.fill" : "circle.dashed").foregroundStyle(cleared ? Color.green : Color.secondary)
            }
            .font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("ticketWallet.topicCompleted.\(ticket.id)")
        }
    }
}

extension TicketWalletCardTag {
    /// The start time when `usableFrom` carries a clock time and it is less than 24 hours away; nil otherwise
    /// (date-only values keep the MP「M月D日开始」tag).
    static func startsSoon(_ ticket: TicketWalletTicket, now: Date = Date()) -> Date? {
        guard let text = ticket.usableFrom?.trimmingCharacters(in: .whitespaces), text.count > 10,
              let start = TicketWalletTicket.sourceDate(text) else { return nil }
        let interval = start.timeIntervalSince(now)
        return interval > 0 && interval < 86_400 ? start : nil
    }
}

/// 类型 · 剩 N 天 / 今天过期, then the MP wallet-card facts 已核销 x/y 家 and N 大 M 小同享.
/// Natural days in Beijing time, as the MP `passDaysLeft`. Upcoming and session tickets
/// show the type only (their time is on the stub lines). Party is only when a child shares the ticket.
private struct TicketWalletSubline: View {
    let ticket: TicketWalletTicket
    let typeKey: String?
    var body: some View {
        line.font(.subheadline).foregroundStyle(.secondary)
    }
    private var line: Text {
        var text: Text?
        func append(_ next: Text) {
            text = text.map { $0 + Text(verbatim: " · ") + next } ?? next
        }
        if let typeKey { append(head(typeKey)) }
        if let progress = ticket.exploreProgress {
            append(Text("ticketWallet.explore.redeemed \(progress.redeemed) \(progress.required)"))
        }
        if ticket.showsSharedParty, let party = ticket.party {
            append(Text("ticketWallet.party.share \(party.adultCount) \(party.childCount)"))
        }
        return text ?? Text(verbatim: "")
    }
    private func head(_ typeKey: String) -> Text {
        guard let days = ticket.walletDaysLeft else { return Text(LocalizedStringKey(typeKey)) }
        if days == 0 {
            return Text(LocalizedStringKey(typeKey)) + Text(verbatim: " · ") + Text("ticketWallet.subline.today")
        }
        return Text(LocalizedStringKey(typeKey)) + Text(verbatim: " · ") + Text("ticketWallet.subline.daysLeft \(days)")
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
