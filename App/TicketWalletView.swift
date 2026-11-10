import SwiftUI

/// Retain the reader in the session host. Host must observe session changes and use .id(reader.scope).
@MainActor struct TicketWalletView: View {
    let reader: any TicketWalletReading
    var onClose: (() -> Void)? = nil
    var onSignIn: (() -> Void)? = nil
    var makeTeamCoordinator: (() -> TeamCoordinator)? = nil
    var orderLifecycleCoordinator: OrderLifecycleCoordinator? = nil
    @Environment(\.ticketWalletPendingOrderProvider) private var pendingOrderProvider
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = TicketWalletScreenModel<TicketWalletSnapshot>()
    @State private var isVisible = false
    @State private var refreshOnActive = false
    @State private var pendingOrderEntry = TicketWalletPendingOrderEntry()
    @State private var pendingOrderReadOwner: TicketWalletPendingOrderOwner?
    @State private var stagger = CYStaggerGate()
    @Namespace private var hero
    private var key: TicketWalletLoadKey { TicketWalletLoadKey(reader: reader) }
    var body: some View {
        let offeredPresentation = model.presentation
        let offeredPendingPresentation = pendingOrderEntry.presentationID
        NavigationStack {
            List {
                if !reader.isAuthenticated {
                    TicketWalletIssueView(issue: .login)
                    if let onSignIn { Button("ticketWallet.signIn", action: onSignIn) }
                } else if !reader.isConfigured { TicketWalletIssueView(issue: .notConfigured) }
                else if model.isLoading || model.loadedOwner != key { CYSkeleton().listRowBackground(Color.clear).accessibilityLabel(Text("ticketWallet.loading")) }
                else if let issue = model.issue(owner: key) {
                    // Source failure title 票夹没能打开 precedes the specific reason.
                    Text("ticketWallet.parity.error.title").font(.headline)
                        .accessibilityIdentifier("ticketWallet.errorTitle")
                    TicketWalletIssueView(issue: issue, retry: { schedule(offeredPresentation) })
                } else if let snapshot = model.value(owner: key) {
                    if let partial = snapshot.partialFailure {
                        Section {
                            Text(LocalizedStringKey(partial.lane == .route ? "ticketWallet.partial.route" : "ticketWallet.partial.activity"))
                                .font(.headline).accessibilityIdentifier("ticketWallet.partialFailure")
                            TicketWalletIssueView(issue: partial.issue, retry: { schedule(offeredPresentation) })
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
                    }
                    // Source preserves both lanes and row order, including repeated server IDs.
                    ForEach(Array(snapshot.tickets.enumerated()), id: \.offset) { rowIndex, ticket in
                        if ticket.action == .detail {
                            NavigationLink {
                                TicketWalletDetailView(id: ticket.id, reader: reader, lifecycleCoordinator: orderLifecycleCoordinator, makeTeamCoordinator: makeTeamCoordinator, heroNamespace: hero, heroID: rowIndex)
                            } label: { TicketWalletRow(ticket: ticket).cyHeroSource(rowIndex, in: hero) }
                            .buttonStyle(QuestifyCardButtonStyle())
                            .questifyHidesLinkIndicator()
                            .accessibilityIdentifier("ticketWallet.row.\(ticket.id)")
                            .cyStaggeredAppear(index: rowIndex, gate: stagger)
                            .questifyCardListRow()
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
                            .cyStaggeredAppear(index: rowIndex, gate: stagger)
                            .questifyCardListRow()
                        } else {
                            TicketWalletRow(ticket: ticket)
                                .accessibilityIdentifier("ticketWallet.row.\(ticket.id)")
                                .cyStaggeredAppear(index: rowIndex, gate: stagger)
                                .questifyCardListRow()
                        }
                    }
                }
                if reader.isAuthenticated, let makeTeamCoordinator {
                    Section {
                        NavigationLink { TeamHomeView(coordinator: makeTeamCoordinator(), makeCoordinator: makeTeamCoordinator) } label: {
                            Label("team.title", systemImage: "person.3")
                        }.accessibilityIdentifier("ticketWallet.teams")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(20)
            .appNavigationTitle("ticketWallet.title")
            .toolbar {
                if let onClose { ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) } }
                ToolbarItem(placement: .primaryAction) {
                    Button { schedule(offeredPresentation) } label: { Label("ticketWallet.refresh", systemImage: "arrow.clockwise") }
                        .disabled(model.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                        .accessibilityIdentifier("ticketWallet.refresh")
                }
            }
            .onChange(of: key) { _, _ in replacePresentation() }
            .onChange(of: pendingOrderProvider?.owner) { _, _ in replacePresentation() }
            .navigationDestination(item: $pendingOrderEntry.target) { target in
                if let provider = pendingOrderProvider, pendingOrderReadOwner == provider.owner,
                   !model.isLoading, let snapshot = model.value(owner: key),
                   pendingOrderEntry.matches(target, snapshot: snapshot, reader: reader, provider: provider),
                   let destination = provider.destination(target: target, reader: reader) {
                    destination.id(provider.owner)
                }
            }
            .refreshable {
                if let offeredPresentation, model.accepts(offeredPresentation, currentOwner: key) { retirePendingOrder() }
                await model.refresh(presentation: offeredPresentation, currentOwner: key) { await load(presentation: $0) }
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
        }
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

private struct TicketTopHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// One pass in the holder: art band with the title and a corner status ribbon, a perforated tear line with side
/// notches (real cut-outs), and a stub with date, place and the code glyph. Two sleeves behind it give the stack
/// its depth and a band of light slides across as the list scrolls. The NavigationLink owns the press feel.
private struct TicketWalletRow: View {
    let ticket: TicketWalletTicket
    var showsPendingOrderAction = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var topHeight: CGFloat = 0
    private let radius = CYRadius.xl
    private let tearBand: CGFloat = 18
    private var state: CYPassState { CYPassState(ticket.status) }
    private var hasStub: Bool {
        (ticket.participateDate?.isEmpty == false) || (ticket.addressName?.isEmpty == false) || ticket.needsScheduleSync
            || (ticket.statusHintKey != nil && ticket.action == .detail) || showsPendingOrderAction
    }
    private var shape: CYTicketPassShape {
        CYTicketPassShape(notchY: hasStub && topHeight > 0 ? topHeight + tearBand / 2 : -1, radius: radius, notch: 10, perforation: 3, perforationGap: 7)
    }
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                E1CoverArt(seed: ticket.title ?? "ticket-\(ticket.id)", symbol: "ticket", debugLabel: false)
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                    .font(.system(.title3, weight: .semibold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(CYSpacing.lg)
                    .padding(.trailing, typeSize.isAccessibilitySize ? 0 : CYSpacing.xxxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: typeSize.isAccessibilitySize ? 96 : 150)
            .clipped()
            .background(GeometryReader { Color.clear.preference(key: TicketTopHeightKey.self, value: $0.size.height) })
            if hasStub {
                Color.clear.frame(height: tearBand).accessibilityHidden(true)
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
                        Image(systemName: "qrcode").font(.title).imageScale(.large).foregroundStyle(CYColor.textPrimary.opacity(0.9))
                            .padding(CYSpacing.sm).background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.lg).padding(.top, CYSpacing.xs)
            }
        }
        .onPreferenceChange(TicketTopHeightKey.self) { topHeight = $0 }
        .background(CYColor.bgElevated)
        .overlay(alignment: .topTrailing) {
            CYStatusRibbon(state: state, text: Text(LocalizedStringKey("ticketWallet.status." + ticket.status.rawValue)))
        }
        .cyScrollSheen()
        .clipShape(shape, style: FillStyle(eoFill: true))
        .overlay(shape.stroke(CYColor.borderSubtle, lineWidth: 1).allowsHitTesting(false))
        .shadow(color: .black.opacity(0.40), radius: 14, y: 8)
        .cyPassStack(depth: 2, radius: radius)
        .opacity(state.isRetired ? 0.72 : 1)
        .padding(.horizontal, CYSpacing.pageHorizontal)
    }
}
