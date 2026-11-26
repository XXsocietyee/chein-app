import SwiftUI

/// Always fetches info by ID. A list row is never used as proof of current ticket status.
@MainActor struct TicketWalletDetailView: View {
    let id: Int
    let reader: any TicketWalletReading
    var lifecycleCoordinator: OrderLifecycleCoordinator? = nil
    var makeTeamCoordinator: (() -> TeamCoordinator)? = nil
    /// Zoom source in the wallet (iOS 18); nil keeps the default push.
    var heroNamespace: Namespace.ID? = nil
    var heroID: Int? = nil
    /// PLY-21-3: the pass sheet's 开始游戏 pill pushes this page and starts play once the fresh read allows it.
    var autoStartsPlay = false
    @State private var didAutoStart = false
    @Environment(\.ticketWalletPlayProvider) private var playProvider
    @Environment(\.mpParity) private var mpParity
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = TicketWalletScreenModel<TicketWalletTicket>()
    @State private var isVisible = false
    @State private var refreshOnActive = false
    @State private var playEntry = TicketWalletPlayEntry()
    @State private var playReadOwner: TicketWalletPlayOwner?
    @State private var presenting = false
    @Namespace private var presentHero
    private var key: TicketWalletLoadKey { TicketWalletLoadKey(reader: reader, id: id) }
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        let offeredPresentation = model.presentation
        List {
            if reader.isOfflineExample { Text("ticketWallet.offlineExample").cyText(.caption) }
            if !reader.isAuthenticated { TicketWalletIssueView(issue: .login) }
            else if !reader.isConfigured { TicketWalletIssueView(issue: .notConfigured) }
            else if model.isLoading || model.loadedOwner != key { CYSkeleton().listRowBackground(Color.clear).accessibilityLabel(Text("ticketWallet.loading")) }
            else if let issue = model.issue(owner: key) {
                TicketWalletIssueView(issue: issue, retry: { schedule(offeredPresentation) })
            } else if let ticket = model.value(owner: key), ticket.id == id {
                Section {
                    TicketWalletDetailHeader(ticket: ticket)
                        .cyHeroSource("present", in: presentHero)
                        .questifyCardListRow()
                    if ticket.status == .ready && ticket.clearedFlag != true && !ticket.isWalletLocked {
                        // MP: a cleared ticket shows no entry code (PLY-21-4); a locked one cannot be presented yet.
                        // The pass holder's one primary action. Staff verify; the real code only comes from the injected factory.
                        CYPillButton(verbatim: c.t("出示票券", "Present pass"), systemImage: "qrcode") { presenting = true }
                            .accessibilityIdentifier("ticketWallet.present.open")
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                }
                if let makeTeamCoordinator {
                    TicketWalletTeamEntrySection(ticket: ticket, requestedID: id, reader: reader, makeCoordinator: makeTeamCoordinator)
                }
                if ticket.hasGame, let playProvider, playReadOwner == playProvider.owner,
                   playEntry.canOpen(ticket: ticket, requestedID: id, reader: reader, provider: playProvider) {
                    let presentationID = playEntry.presentationID
                    Section {
                        Button {
                            guard !model.isLoading, model.value(owner: key) == ticket,
                                  playReadOwner == playProvider.owner else { return }
                            // A row already on screen is not proof. Re-read inside this permit, then start only if it is still usable.
                            guard playEntry.presentationID == presentationID,
                                  let permit = model.presentation, model.accepts(permit, currentOwner: key) else { return }
                            schedule(permit, confirmPlay: true)
                        } label: {
                            // PLY-21-4: MP signup wxml:103-105 labels a cleared ticket 查看记录.
                            if ticket.clearedFlag == true { Label { Text(verbatim: c.t("查看记录", "View record")) } icon: { TicketWalletPlayGlyph() } }
                            else { Label { Text("playerJourney.start") } icon: { TicketWalletPlayGlyph() } }
                        }
                        .modifier(TicketWalletPlayButtonStyle(secondary: ticket.status == .ready))
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("ticketWallet.play.open")
                    }
                }
                if mpParity.journeySeats != nil {
                    // Mini-program order detail `goSeats`: the wallet id is the registration id; the lobby gates itself (buyer only).
                    Section {
                        NavigationLink { MPParityDestination(route: .journeySeats(registrationID: String(id))) } label: {
                            Label("mp.entry.journeySeats", systemImage: "person.2")
                        }
                        .accessibilityIdentifier("journeySeats.entry")
                    }
                }
                if [ticket.registrationNumber, ticket.realName, ticket.phone, ticket.verificationTime].contains(where: { $0?.isEmpty == false }) {
                    Section("ticketWallet.registrationInfo") {
                        TicketWalletOptionalField(label: "ticketWallet.number", value: ticket.registrationNumber)
                        TicketWalletOptionalField(label: "ticketWallet.contact", value: ticket.realName)
                        TicketWalletOptionalField(label: "ticketWallet.phone", value: ticket.phone)
                        TicketWalletOptionalField(label: "ticketWallet.verificationTime", value: ticket.verificationTime)
                    }
                }
                if !ticket.entitlements.isEmpty {
                    Section("ticketWallet.entitlements") {
                        LabeledContent("ticketWallet.pendingChapters", value: String(ticket.pendingCount))
                            .accessibilityIdentifier("ticketWallet.pendingChapters")
                        if ticket.hasUnknownEntitlementStatus { Text("ticketWallet.unknownEntitlementStatus").cyText(.meta) }
                        ForEach(Array(ticket.entitlements.enumerated()), id: \.offset) { _, entitlement in
                            TicketWalletEntitlementRow(entitlement: entitlement)
                                .accessibilityIdentifier("ticketWallet.entitlement.\(entitlement.id)")
                        }
                    }
                }
                if let lifecycleCoordinator {
                    Section {
                        NavigationLink { OrderLifecycleView(id: id, coordinator: lifecycleCoordinator).id(lifecycleCoordinator.scope) } label: {
                            Label("orderLifecycle.title", systemImage: "list.bullet.rectangle")
                        }.accessibilityIdentifier("ticketWallet.orderLifecycle")
                    }
                }
                Section("ticketWallet.redemption") {
                    Label {
                        Text(LocalizedStringKey("ticketWallet.redemption." + String(ticket.redemption.rawValue)))
                            .accessibilityIdentifier("ticketWallet.redemption.notice")
                    } icon: { Image(systemName: "info.circle").accessibilityHidden(true) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(20)
        .appNavigationTitle("ticketWallet.detail")
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard let permit = offeredPresentation, permit == model.presentation,
                          model.accepts(permit, currentOwner: key) else { return }
                    schedule(offeredPresentation)
                } label: { Label("ticketWallet.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                    .accessibilityIdentifier("ticketWallet.detail.refresh")
            }
        }
        .onChange(of: TicketWalletPlayLoadKey(readerID: ObjectIdentifier(reader), key: key, providerOwner: playProvider?.owner)) { _, _ in replacePresentation() }
        .refreshable {
            let current = model.presentation
            guard let current, model.accepts(current, currentOwner: key) else { return }
            await model.refresh(presentation: current, currentOwner: key) { await load(presentation: $0) }
        }
        .onAppear { isVisible = true; refreshOnActive = false; playEntry.appear(); replacePresentation() }
        .onDisappear { isVisible = false; model.endPresentation(); playEntry.disappear() }
        .onChange(of: playProvider?.owner) { _, _ in playEntry.retire() }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in playEntry.retire() }
        .onChange(of: key) { _, _ in playEntry.retire() }
        .navigationDestination(item: $playEntry.target) { target in
            if let playProvider, playReadOwner == playProvider.owner, !model.isLoading, let ticket = model.value(owner: key),
               playEntry.matches(target, ticket: ticket, requestedID: id, reader: reader, provider: playProvider),
               let destination = playProvider.destination(target: target, reader: reader) {
                destination
            }
        }
        .onChange(of: scenePhase) { _, phase in
                if phase == .background { refreshOnActive = true; model.endPresentation() }
                else if phase == .active && isVisible && (refreshOnActive || model.presentation == nil) {
                    refreshOnActive = false
                    replacePresentation()
                }
            }
        .accessibilityIdentifier("ticketWallet.detail")
        .cyPushedChrome(domain: .player)
        .appSwitcherPrivacyShield()
        .modifier(CYOptionalHeroDestination(id: heroID ?? id, namespace: heroNamespace))
        .fullScreenCover(isPresented: $presenting) {
            if let ticket = model.value(owner: key), ticket.id == id {
                TicketPassPresentView(ticket: ticket) { presenting = false }
                    .cyHeroDestination("present", in: presentHero)
            } else {
                Color.black.ignoresSafeArea().onAppear { presenting = false }
            }
        }
    }
    private func replacePresentation() {
        guard isVisible, scenePhase == .active else { model.endPresentation(preservingValues: false); return }
        schedule(model.beginPresentation(owner: key))
    }
    private func schedule(_ permit: TicketWalletReadPresentation?, confirmPlay: Bool = false) {
        model.schedule(presentation: permit, currentOwner: key) { await load(presentation: $0, confirmPlay: confirmPlay) }
    }
    private func load(presentation: TicketWalletReadPresentation, confirmPlay: Bool = false) async {
        guard isVisible, scenePhase == .active, !Task.isCancelled,
              model.accepts(presentation, currentOwner: key) else { return }
        playEntry.retire()
        playReadOwner = nil
        let captured = key
        let provider = playProvider
        await model.load(presentation: presentation, currentOwner: { key }) { try await reader.ticketDetail(id: id) }
        if !Task.isCancelled, model.accepts(presentation, currentOwner: key),
           model.value(owner: captured)?.id == id, captured == key,
           let ticket = model.value(owner: captured), !ticket.hasGame,
           ticket.status == .ready, ticket.clearedFlag != true, !ticket.isWalletLocked {
            presenting = true
        }
        if !Task.isCancelled, model.accepts(presentation, currentOwner: key),
           let provider, provider.owner == playProvider?.owner, provider.matches(reader: reader),
           model.value(owner: captured)?.id == id, captured == key {
            playReadOwner = provider.owner
            // Play waits for this detail. A list row, or the ticket that was on screen, is not enough.
            let startPlay = confirmPlay || (autoStartsPlay && !didAutoStart)
            if autoStartsPlay { didAutoStart = true }
            if startPlay, let ticket = model.value(owner: captured), ticket.hasGame,
               playEntry.canOpen(ticket: ticket, requestedID: id, reader: reader, provider: provider) {
                playEntry.activate(ticket: ticket, requestedID: id, reader: reader, provider: provider,
                                   presentationID: playEntry.presentationID)
            }
        }
    }
}

/// Play start steps back to the outlined style while the pass itself owns the primary (Present) action.
private struct TicketWalletPlayButtonStyle: ViewModifier {
    let secondary: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if secondary { content.buttonStyle(.cySecondary(fullWidth: true)) } else { content.buttonStyle(.cyPrimary(fullWidth: true)) }
    }
}

private struct TicketWalletPlayLoadKey: Hashable {
    let readerID: ObjectIdentifier
    let key: TicketWalletLoadKey
    let providerOwner: TicketWalletPlayOwner?
}
private struct TicketWalletPlayProviderKey: EnvironmentKey {
    static let defaultValue: TicketWalletPlayProvider? = nil
}
extension EnvironmentValues {
    var ticketWalletPlayProvider: TicketWalletPlayProvider? {
        get { self[TicketWalletPlayProviderKey.self] }
        set { self[TicketWalletPlayProviderKey.self] = newValue }
    }
}
struct TicketWalletPlayOwner: Hashable {
    let readerID: ObjectIdentifier
    let scope: UUID
    let revision: UInt64
    @MainActor init(reader: any TicketWalletReading, revision: UInt64) {
        readerID = ObjectIdentifier(reader); scope = reader.scope; self.revision = revision
    }
}
/// Account injects this only into its wallet sheet. It cannot grant a proxy or fixture reader access.
struct TicketWalletPlayProvider {
    let owner: TicketWalletPlayOwner
    private let currentRevision: @MainActor () -> UInt64
    private let makeDestination: @MainActor (ParticipationPlayEntry) -> AnyView
    @MainActor init(reader: any TicketWalletReading, revision: UInt64,
                    currentRevision: @escaping @MainActor () -> UInt64,
                    destination: @escaping @MainActor (ParticipationPlayEntry) -> AnyView) {
        owner = TicketWalletPlayOwner(reader: reader, revision: revision)
        self.currentRevision = currentRevision; makeDestination = destination
    }
    @MainActor func matches(reader: any TicketWalletReading) -> Bool {
        reader.isConfigured && reader.isAuthenticated
            && owner == TicketWalletPlayOwner(reader: reader, revision: currentRevision())
    }
    @MainActor func destination(target: TicketWalletPlayEntry.Target, reader: any TicketWalletReading) -> AnyView? {
        guard owner == target.owner, matches(reader: reader) else { return nil }
        return makeDestination(target.entry)
    }
}
@MainActor struct TicketWalletPlayEntry {
    struct Target: Hashable {
        let id = UUID()
        let entry: ParticipationPlayEntry
        let owner: TicketWalletPlayOwner
    }
    private var visible = false
    private(set) var presentationID = UUID()
    var target: Target?
    /// Explicit current registration facts only. No lane, title, product name or numeric-ID guessing.
    static func entry(ticket: TicketWalletTicket, requestedID: Int) -> ParticipationPlayEntry? {
        // R7-MEM-21-2: a wallet-locked ticket has no play entry (MP index.js:371-374).
        guard requestedID > 0, ticket.id == requestedID, ticket.registrationStatus == 2,
              ticket.isWalletUsable, !ticket.isWalletLocked, let ownerID = ticket.ownerID, ownerID > 0 else { return nil }
        let scope: PlaySessionScope
        switch ticket.ownerType {
        case 1:
            guard ticket.activityID == nil, ticket.topicID == nil || ticket.topicID == ownerID else { return nil }
            scope = .topic(ownerID)
        case 2:
            guard ticket.topicID == nil, ticket.activityID == nil || ticket.activityID == ownerID else { return nil }
            scope = .activity(ownerID)
        default: return nil
        }
        return ParticipationPlayEntry(registrationID: requestedID, scope: scope)
    }
    mutating func appear() { visible = true; presentationID = UUID() }
    mutating func disappear() {
        // A push hides the source view; keep its selected destination until native Back.
        visible = false; presentationID = UUID()
    }
    mutating func retire() { target = nil; presentationID = UUID() }
    func canOpen(ticket: TicketWalletTicket, requestedID: Int, reader: any TicketWalletReading, provider: TicketWalletPlayProvider) -> Bool {
        visible && target == nil && provider.matches(reader: reader) && Self.entry(ticket: ticket, requestedID: requestedID) != nil
    }
    mutating func activate(ticket: TicketWalletTicket, requestedID: Int, reader: any TicketWalletReading,
                           provider: TicketWalletPlayProvider, presentationID: UUID) {
        guard self.presentationID == presentationID, canOpen(ticket: ticket, requestedID: requestedID, reader: reader, provider: provider),
              let entry = Self.entry(ticket: ticket, requestedID: requestedID) else { return }
        target = Target(entry: entry, owner: provider.owner)
    }
    func matches(_ target: Target, ticket: TicketWalletTicket, requestedID: Int, reader: any TicketWalletReading, provider: TicketWalletPlayProvider) -> Bool {
        self.target == target && target.owner == provider.owner && provider.matches(reader: reader)
            && target.entry == Self.entry(ticket: ticket, requestedID: requestedID)
    }
}

private struct TicketWalletDetailHeader: View {
    let ticket: TicketWalletTicket
    @Environment(\.locale) private var locale
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        let expiry = TicketExpiryAndOrderStatusRules.passExpiryText(validUntil: ticket.endDate)
        let fulfillment = FourShopCompensationPolicy.evaluateSoldContractFulfillment(
            registrationStatus: ticket.registrationStatus,
            paymentStatus: nil,
            verificationStatus: ticket.verificationStatus,
            productType: ticket.productType
        )
        E1TicketCard(ticket: ticket,
                     fulfillmentNotice: fulfillment.fulfillmentNotice.map { c.tr($0) },
                     expiryText: expiry.isEmpty ? nil : c.tr(expiry))
    }
}

private struct TicketWalletEntitlementRow: View {
    let entitlement: TicketWalletEntitlement
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var symbol: String {
        switch entitlement.status {
        case 0: return "circle"
        case 1: return "checkmark.circle"
        case 2: return "xmark.circle"
        default: return "questionmark.circle"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
            layout {
                Group {
                    if let name = entitlement.chapterName, !name.isEmpty { Text(verbatim: name) }
                    else if let id = entitlement.chapterID { Text("ticketWallet.chapter"); Text(verbatim: String(id)) }
                    else { Text("ticketWallet.unnamedChapter") }
                }
                .cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                // B-21 (FE-G6): MP order-detail wxml:278 prints `statusLabel || ''`, so an empty server label shows no text.
                // The glyph stays and carries the local state name for VoiceOver, so the state is never colour or shape alone.
                if let label = entitlement.displayStatusLabel {
                    Label { Text(verbatim: label) } icon: { Image(systemName: symbol).accessibilityHidden(true) }
                        .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Image(systemName: symbol).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .accessibilityLabel(Text(LocalizedStringKey("ticketWallet.entitlementStatus." + entitlement.statusKey)))
                }
            }
            // B-16: no 已含 / 需消费 / 需预约 line here. The backend sends those perk terms only on the play-nodes perk map
            // and the free-explore catalog, never on the ticket-wallet entitlement, so the row could never render.
            TicketWalletOptionalField(label: "ticketWallet.redeemedAt", value: entitlement.redeemedAt).font(.caption)
            if let reason = entitlement.invalidReason, !reason.isEmpty {
                Text(verbatim: reason).font(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 6)
    }
}
