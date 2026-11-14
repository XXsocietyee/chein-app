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
    private var key: TicketWalletLoadKey { TicketWalletLoadKey(reader: reader) }
    var body: some View {
        let offeredPresentation = model.presentation
        let offeredPendingPresentation = pendingOrderEntry.presentationID
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                if !reader.isAuthenticated {
                    TicketWalletIssueView(issue: .login)
                    if let onSignIn { Button("ticketWallet.signIn", action: onSignIn) }
                } else if !reader.isConfigured { TicketWalletIssueView(issue: .notConfigured) }
                else if model.isLoading || model.loadedOwner != key { CYSkeleton().listRowBackground(Color.clear).accessibilityLabel(Text("mpfresh.ticketWallet.loading", tableName: "MpFresh")) }
                else if let issue = model.issue(owner: key) {
                    // Source failure title 票夹没能打开 precedes the specific reason.
                    Text("ticketWallet.parity.error.title").font(.headline)
                        .accessibilityIdentifier("ticketWallet.errorTitle")
                    TicketWalletIssueView(issue: issue, retry: { schedule(model.presentation ?? model.beginPresentation(owner: key)) })
                } else if let snapshot = model.value(owner: key) {
                    if let partial = snapshot.partialFailure {
                        Section {
                            Text(LocalizedStringKey(partial.lane == .route ? "ticketWallet.partial.route" : "ticketWallet.partial.activity"))
                                .font(.headline).accessibilityIdentifier("ticketWallet.partialFailure")
                            TicketWalletIssueView(issue: partial.issue, retry: { schedule(model.presentation ?? model.beginPresentation(owner: key)) })
                        }
                    }
                    if snapshot.tickets.isEmpty {
                        // A partial empty response never claims the whole wallet is empty.
                        ContentUnavailableView {
                            Label {
                                Text(LocalizedStringKey(snapshot.partialFailure == nil ? "ticketWallet.empty" : "ticketWallet.partialEmpty"))
                                    .accessibilityIdentifier("ticketWallet.empty")
                            } icon: { Image(systemName: "ticket") }
                        } description: {
                            if snapshot.partialFailure == nil {
                                Text("ticketWallet.parity.empty.detail")
                                    .accessibilityIdentifier("ticketWallet.emptyHint")
                            }
                        }
                        .padding(CYSpacing.md)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CYNight.glassFill)
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                        }
                        .listRowBackground(Color.clear)
                    }
                    let shown = filtered(snapshot.tickets)
                    if !snapshot.tickets.isEmpty && shown.isEmpty {
                        // Source filter 即将开始 / 已通关 with no match: say so instead of an empty wallet.
                        Text(LocalizedStringKey(walletFilter.emptyKey), tableName: "MpFresh")
                            .font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.lg)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("ticketWallet.filterEmpty")
                    }
                    ticketCarousel(shown)
                    // Source preserves both lanes and row order, including repeated server IDs.
                    ForEach(Array(snapshot.tickets.enumerated()).filter { shown.contains($0.element) }, id: \.offset) { rowIndex, ticket in
                        if ticket.action == .detail {
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
                        NavigationLink { TeamHomeView(coordinator: makeTeamCoordinator(), makeCoordinator: makeTeamCoordinator) } label: {
                            Label("team.title", systemImage: "person.3")
                        }
                        .accessibilityIdentifier("ticketWallet.teams")
                    }
                }
                // Payment, refunds and completion rewards are not in the app; shown in every state so the wallet never implies otherwise.
                Section {
                    Text("ticketWallet.readOnly").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ticketWallet.readOnly")
                }
            }
            .onAppear { focusTopic(proxy) }
            .onChange(of: model.value(owner: key)?.tickets.map(\.id)) { _, _ in focusTopic(proxy) }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
            .listSectionSpacing(20)
            .appNavigationTitle("ticketWallet.title")
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
                ToolbarItem(placement: .primaryAction) {
                    Button { schedule(model.presentation ?? model.beginPresentation(owner: key)) } label: { Label("ticketWallet.refresh", systemImage: "arrow.clockwise") }
                        .disabled(model.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                        .accessibilityIdentifier("ticketWallet.refresh")
                }
            }
            .onChange(of: key) { _, _ in replacePresentation() }
            .onChange(of: pendingOrderProvider?.owner) { _, _ in replacePresentation() }
            .navigationDestination(item: $carouselTicketID) { id in
                TicketWalletDetailView(id: id, reader: reader, lifecycleCoordinator: orderLifecycleCoordinator, makeTeamCoordinator: makeTeamCoordinator)
            }
            .navigationDestination(item: $pendingOrderEntry.target) { target in
                if let provider = pendingOrderProvider, pendingOrderReadOwner == provider.owner,
                   !model.isLoading, let snapshot = model.value(owner: key),
                   pendingOrderEntry.matches(target, snapshot: snapshot, reader: reader, provider: provider),
                   let destination = provider.destination(target: target, reader: reader) {
                    destination.id(provider.owner)
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
            }
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
        guard isVisible, scenePhase == .active else { model.endPresentation(preservingValues: false); return }
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
        await model.load(presentation: presentation, currentOwner: { key }) { try await reader.ticketWallet() }
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
    /// Generated cover art (no ticket image exists in the model): muted dark gradients keyed by id.
    private var art: [Color] {
        let sets: [[Color]] = [
            [Color(red: 0.10, green: 0.32, blue: 0.36), Color(red: 0.04, green: 0.10, blue: 0.14)],
            [Color(red: 0.24, green: 0.20, blue: 0.46), Color(red: 0.07, green: 0.06, blue: 0.16)],
            [Color(red: 0.42, green: 0.17, blue: 0.22), Color(red: 0.13, green: 0.05, blue: 0.08)],
            [Color(red: 0.30, green: 0.34, blue: 0.16), Color(red: 0.08, green: 0.10, blue: 0.05)]]
        return sets[abs(ticket.id) % sets.count]
    }
    private var hasStub: Bool {
        (ticket.participateDate?.isEmpty == false) || (ticket.addressName?.isEmpty == false) || ticket.needsScheduleSync
            || ticket.action != .detail || (ticket.statusHintKey != nil && ticket.action == .detail) || showsPendingOrderAction
    }
    var body: some View {
        let dimmed = ticket.status == .cancelled || ticket.status == .expired
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: art, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "ticket.fill").font(.system(size: 120)).rotationEffect(.degrees(-14))
                    .foregroundStyle(.white.opacity(0.07)).offset(x: 90, y: -10).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    TicketWalletStatusBadge(status: ticket.status)
                    TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                        .font(.system(.title3, weight: .semibold)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    completionCaption
                }
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                            .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("ticketWallet.scheduleSync.\(ticket.id)")
                    }
                    if ticket.action != .detail {
                        Label { Text(LocalizedStringKey(ticket.sourceNoticeKey)).fixedSize(horizontal: false, vertical: true) }
                            icon: { Image(systemName: "info.circle").accessibilityHidden(true) }
                            .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("ticketWallet.sourceNotice.\(ticket.id)")
                    }
                    if let hint = ticket.statusHintKey, ticket.action == .detail {
                        Text(LocalizedStringKey(hint)).font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textPrimary)
                            .accessibilityIdentifier("ticketWallet.statusHint.\(ticket.id)")
                    }
                    if showsPendingOrderAction {
                        Label { Text("ticketPendingOrder.open", tableName: "TicketPendingOrder") } icon: { Image(systemName: "list.bullet.rectangle") }
                            .font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textPrimary)
                    }
                }
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize, ticket.action == .detail {
                    Image(systemName: "qrcode").font(.system(size: 34)).foregroundStyle(CYColor.textPrimary.opacity(0.85))
                        .padding(CYSpacing.sm).background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated)
            }
        }
        .onPreferenceChange(TicketTopHeightKey.self) { topHeight = $0 }
        .clipShape(TicketStubShape(notchY: hasStub ? topHeight : -1), style: FillStyle(eoFill: true))
        .opacity(dimmed ? 0.62 : 1)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    /// Completed shows 已通关. Absent hides that line. A non-boolean shows an em dash.
    @ViewBuilder private var completionCaption: some View {
        if let completionReader, completionReader.topicCompleted(ticket) == true {
            Text("mpfresh.ticketWallet.filter.completed", tableName: "MpFresh")
                .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.92))
                .accessibilityIdentifier("ticketWallet.topicCompleted.\(ticket.id)")
        } else if let completionReader, completionReader.topicCompleted(ticket) == nil, ticket.topicCompletion == .unknown {
            Text("mpfresh.ticketWallet.completion.unknown", tableName: "MpFresh")
                .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.92))
                .accessibilityLabel(Text("mpfresh.ticketWallet.completion.unknownLabel", tableName: "MpFresh"))
                .accessibilityIdentifier("ticketWallet.topicCompleted.unknown.\(ticket.id)")
        }
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p }
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
