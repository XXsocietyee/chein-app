import SwiftUI

/// Signed-in order support for one order opened from the existing list.
/// The page calls SupportLookupEntry. It does not own an audit store.
struct ProfileOrderSupportLookup {
    var entry: SupportLookupEntry
    var currentProjection: SupportCurrentProjection?
}

@MainActor
struct ProfileOrdersView: View {
    let reader: any ProfileReading
    var lifecycleCoordinator: OrderLifecycleCoordinator? = nil
    var mediaScope: UUID = UUID()
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var ticketReader: (any TicketWalletReading)? = nil
    /// Source 去发现城市路线 CTA. Nil (the default) renders no CTA and never navigates.
    var discoverRoutes: (@MainActor () -> Void)? = nil
    /// Inert unless the root TabView installed it; mirrors the source switchTab to the home page.
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    var orderSupport: ProfileOrderSupportLookup? = nil
    /// MP 登录 on the signed-out state. Nil keeps the state without a button.
    var onSignIn: (() -> Void)? = nil
    @State private var filterSelection = ProfileOrderFilterSelection()
    /// G-052: local search text; matches only rows already read, never sends a request.
    @State private var orderQuery = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orderEntry: SupportLookupEntry?
    @State private var lookedUpOrderID: Int64?
    /// Pages after the first `orderHistory` page. The first page stays on `ProfileReadScreen`.
    @State private var appendedOrders: [ProfileOrder] = []
    @State private var nextHistoryPage = 2
    @State private var historyMore = false
    @State private var historyLoading = false
    /// The last next-page read failed. The page number stays, and the sentinel does not fire again by itself.
    @State private var historyPageFailed = false
    @State private var historyGeneration = 0
    /// R7-MEM-16-1: the order whose card 取消订单 / 取消报名 opened the cancel sheet.
    @State private var cardExit: ProfileOrderCardExit?
    /// R7-MEM-16-1: MP index.wxml:84-90 shows 取消订单 on unpaid cards and 取消报名 on free registered cards.
    /// fix-r10: money is on in Release, so the card also shows 立即支付 (unpaid) and 取消并退款 (paid, refundable)
    /// like the MP, each while its own money switch is on. Both open the same lifecycle sheet, which owns the pay
    /// section and the reviewed refund confirm.
    @ViewBuilder private func cardExitButton(_ order: ProfileOrder) -> some View {
        if let lifecycleCoordinator,
           lifecycleCoordinator.hasReviewedWriter || lifecycleCoordinator.canDispatch || lifecycleCoordinator.canSimulate {
            if order.cardPayNowShown {
                Button { cardExit = ProfileOrderCardExit(id: order.id) } label: {
                    Label("profile.orderExit.payNow", systemImage: "creditcard")
                }
                .tint(.accentColor)
                .accessibilityIdentifier("profile.order.cardPay.\(order.id)")
            }
            if let key = order.cardExitKey {
                Button(role: .destructive) { cardExit = ProfileOrderCardExit(id: order.id) } label: {
                    Label(LocalizedStringKey(key), systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("profile.order.cardExit.\(order.id)")
            }
        }
    }
    /// One history row: the card link, the NIT-R11-1 visible menu, and the R7-MEM-16-1 swipe / context actions.
    @ViewBuilder private func orderListRow(_ order: ProfileOrder, now: Date) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
        HStack {
            NavigationLink { ProfileOrderDetailView(id: order.id, reader: reader, lifecycleCoordinator: lifecycleCoordinator, mediaScope: mediaScope, makeExternalMaps: makeExternalMaps, ticketReader: ticketReader, orderSupport: orderSupport, lookedUpOrderID: lookedUpOrderID, onOpenedOrder: { [owner = filterOwner] in lookupOpenedOrder($0, expectedOwner: owner) }) } label: {
                ProfileOrderRow(order: order, historyState: order.historyState(now: now), statusKey: order.historyTagKey(now: now), showsPayButtons: showsPayButtons(order))
            }
            .accessibilityIdentifier("profile.order.\(order.id)")
            // NIT-R11-1: MP order-history card shows its buttons (index.wxml:84-90); a visible menu makes them discoverable.
            if hasCardAction(order), !showsPayButtons(order) {
                Menu { cardExitButton(order) } label: {
                    Label("profile.orderExit.more", systemImage: "ellipsis.circle").labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("profile.order.cardMenu.\(order.id)")
            }
        }
        // mp-mine r3: MP order-history pending card bottom row (index.wxml:83-86): 取消订单 then 立即支付, both on the card.
        // They open the same reviewed lifecycle sheet as the swipe action, which owns the pay section.
        if showsPayButtons(order) {
            HStack(spacing: 12) {
                if let key = order.cardExitKey {
                    Button(role: .destructive) { cardExit = ProfileOrderCardExit(id: order.id) } label: {
                        Text(LocalizedStringKey(key))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("profile.order.rowCancel.\(order.id)")
                }
                Button { cardExit = ProfileOrderCardExit(id: order.id) } label: {
                    Text("profile.orderExit.payNow")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("profile.order.rowPay.\(order.id)")
            }
            .controlSize(.small)
        }
        }
        // R7-MEM-16-1: MP order-history card 取消订单 / 取消报名 (index.wxml:84-90) as the native
        // swipe action and context menu; it opens the reviewed cancel flow (MP confirm + 处理中).
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { cardExitButton(order) }
        .contextMenu { cardExitButton(order) }
    }
    private func showsPayButtons(_ order: ProfileOrder) -> Bool {
        hasCardAction(order) && order.cardPayNowShown
    }
    private func hasCardAction(_ order: ProfileOrder) -> Bool {
        guard let lifecycleCoordinator,
              lifecycleCoordinator.hasReviewedWriter || lifecycleCoordinator.canDispatch || lifecycleCoordinator.canSimulate else { return false }
        return order.cardPayNowShown || order.cardExitKey != nil
    }
    private var filterOwner: ProfileOrderFilterOwner {
        .init(readerID: ObjectIdentifier(reader), identity: reader.identity, isConfigured: reader.isConfigured)
    }
    var body: some View {
        ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.orders", issueCopy: .orders, onSignIn: onSignIn, load: {
            if let paged = reader as? ProfileOrderPageReading {
                let page = try await paged.profileOrderHistory(pageNum: 1)
                await MainActor.run {
                    appendedOrders = []
                    nextHistoryPage = 2
                    historyMore = page.hasMore
                    historyPageFailed = false
                    historyGeneration += 1
                }
                return page.rows
            }
            await MainActor.run {
                appendedOrders = []
                historyMore = false
                historyPageFailed = false
                historyGeneration += 1
            }
            return try await reader.profileOrders()
        }) { loaded in
            let orders = displayedOrders(loaded)
            if orders.isEmpty {
                // G-052: an empty List keeps ProfileReadScreen's pull-to-refresh on the empty state too.
                // mp-mine r3: MP scene-member-order-history keeps the filter tabs above the body, so they show here too.
                let owner = filterOwner
                List {
                ProfileOrderFilterSection(selection: Binding(
                    get: { filterSelection.value(for: filterOwner) },
                    set: { filterSelection.choose($0, rendered: owner, current: filterOwner) }),
                    isEmpty: false)
                Section {
                ContentUnavailableView {
                    Label("profile.orders.sourceEmpty", systemImage: "tray")
                } actions: {
                    if let discoverRoutes {
                        Button("profile.orderParity.discover") { discoverRoutes() }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .accessibilityIdentifier("profile.orders.discover")
                    } else if rootTabSwitch.isAvailable {
                        Button("profile.orderParity.discover") { rootTabSwitch(.home) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .accessibilityIdentifier("profile.orders.discover")
                    }
                }
                .accessibilityIdentifier("profile.orders.empty")
                }
                }
                .listStyle(.insetGrouped)
            } else {
                // Local time may move an already-loaded order between categories.
                // No timer-triggered read or financial action is performed here.
                TimelineView(.periodic(from: .now, by: 60)) { clock in
                    let owner = filterOwner
                    let filter = filterSelection.value(for: owner)
                    let visible = filter.orders(in: orders, now: clock.date)
                    // G-052: local search over the rows already on screen (no request); filter first, then search.
                    let matches = ProfileOrderSearch.matches(visible, query: orderQuery)
                    List {
                        ProfileOrderFilterSection(selection: Binding(
                            get: { filterSelection.value(for: filterOwner) },
                            set: { filterSelection.choose($0, rendered: owner, current: filterOwner) }),
                            isEmpty: visible.isEmpty)
                        if !visible.isEmpty, matches.isEmpty {
                            ContentUnavailableView.search(text: orderQuery)
                                .accessibilityIdentifier("profile.orders.search.empty")
                        }
                        Section {
                            ForEach(matches) { order in
                                orderListRow(order, now: clock.date)
                            }
                            if historyMore, ProfileOrderSearch.isIdle(orderQuery) {
                                Group {
                                    if historyLoading {
                                        ProgressView().accessibilityLabel(Text("profile.loading"))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    } else if historyPageFailed {
                                        Button("action.retry") { loadNextHistoryPage() }
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    } else {
                                        Color.clear.frame(height: 1).onAppear { loadNextHistoryPage() }
                                    }
                                }
                                .accessibilityIdentifier("profile.orders.more")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(reduceMotion ? nil : .default, value: matches.map(\.id))
                    .searchable(text: $orderQuery, placement: .navigationBarDrawer(displayMode: .automatic),
                                prompt: Text("profile.orders.search.prompt"))
                    .accessibilityIdentifier("profile.orders.list")
                }
            }
        }
        .environment(\.profileReadShowsRefreshButton, false)
        .cySheet(item: $cardExit) { exit in
            if let lifecycleCoordinator {
                NavigationStack {
                    OrderLifecycleView(id: exit.id, coordinator: lifecycleCoordinator).id(lifecycleCoordinator.scope)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("action.done") { cardExit = nil }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .appNavigationTitle("profile.orders.title").navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome(domain: .player)
        .onAppear { appearOrderSupport() }
        .onChange(of: filterOwner) { _, _ in
            filterSelection.retire(); orderEntry = nil; lookedUpOrderID = nil; orderQuery = ""
        }
        .onChange(of: filterOwner) { _, _ in
            appendedOrders = []; nextHistoryPage = 2; historyMore = false; historyLoading = false; historyPageFailed = false; historyGeneration += 1
        }
    }
    /// First page plus later `orderHistory` pages, in server order, without repeating an id.
    private func displayedOrders(_ first: [ProfileOrder]) -> [ProfileOrder] {
        var seen = Set(first.map(\.id))
        var rows = first
        for row in appendedOrders where row.id > 0 && seen.insert(row.id).inserted { rows.append(row) }
        return rows
    }
    /// Bottom sentinel. The unpaged `orders()` path never sets `historyMore`.
    private func loadNextHistoryPage() {
        guard historyMore, !historyLoading, let paged = reader as? ProfileOrderPageReading else { return }
        let owner = filterOwner
        let page = nextHistoryPage
        let generation = historyGeneration
        historyLoading = true
        historyPageFailed = false
        Task {
            defer { historyLoading = false }
            await appendHistoryPage(page, owner: owner, reader: paged, generation: generation)
        }
    }
    private func appendHistoryPage(_ page: Int, owner: ProfileOrderFilterOwner, reader: any ProfileOrderPageReading, generation: Int) async {
        guard owner == filterOwner, generation == historyGeneration, historyMore else { return }
        do {
            let next = try await reader.profileOrderHistory(pageNum: page)
            guard owner == filterOwner, generation == historyGeneration else { return }
            var seen = Set(appendedOrders.map(\.id))
            appendedOrders.append(contentsOf: next.rows.filter { $0.id > 0 && seen.insert($0.id).inserted })
            nextHistoryPage = page + 1
            historyMore = next.hasMore
            historyPageFailed = false
        } catch {
            // Keep the rows on screen and ask for this same page again. Do not advance nextHistoryPage.
            guard owner == filterOwner, generation == historyGeneration else { return }
            historyPageFailed = true
        }
    }
    /// Appearance records the entry only. It does not look up and does not send.
    private func appearOrderSupport() {
        guard orderEntry == nil, var entry = orderSupport?.entry else { return }
        entry.appear()
        orderEntry = entry
    }
    /// The request's first ORDER id must equal the order the user opened.
    /// A different id is original-missing and is not shown as this order.
    private func lookupOpenedOrder(_ openedID: Int, expectedOwner: ProfileOrderFilterOwner) {
        guard expectedOwner == filterOwner, reader.identity != nil, reader.isConfigured else { return }
        appearOrderSupport()
        guard openedID > 0, var entry = orderEntry else {
            lookedUpOrderID = nil
            return
        }
        let requested = Int64(openedID)
        guard requested > 0 else {
            lookedUpOrderID = nil
            return
        }
        do {
            let composition = try entry.lookupByOrderId(
                requested,
                currentProjection: orderSupport?.currentProjection,
                withdrawal: nil,
                orderRead: .detail(openedID))
            guard expectedOwner == filterOwner else { return }
            orderEntry = entry
            guard let composition, composition.located.orderId == requested,
                  Self.firstOrderID(composition.located.originalEvents) == requested,
                  OrderPageReadback.openedID(requested: requested, events: composition.located.originalEvents) == requested else {
                lookedUpOrderID = nil
                return
            }
            lookedUpOrderID = requested
        } catch {
            guard expectedOwner == filterOwner else { return }
            orderEntry = entry
            lookedUpOrderID = nil
        }
    }
    private static func firstOrderID(_ events: [OriginalAuditEvent]) -> Int64? {
        for event in events {
            guard event.targetType == "ORDER" else { continue }
            return event.targetId
        }
        return nil
    }
}

/// History-screen opt-in. Readers without it keep unpaged `profileOrders()`.
@MainActor protocol ProfileOrderPageReading: AnyObject {
    func profileOrderHistory(pageNum: Int) async throws -> ProfileOrderPage
}

extension ProfileSessionReader: ProfileOrderPageReading {}
extension OwnedOrderSessionReader: ProfileOrderPageReading {}

/// R7-MEM-16-1: sheet item for the card cancel action.
private struct ProfileOrderCardExit: Identifiable {
    let id: Int
}

/// G-052: case- and diacritic-insensitive match on the order's own text facts (title, registration and order number,
/// place, ticket, organizer). Pure; the list stays in server order.
enum ProfileOrderSearch {
    static func isIdle(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    static func matches(_ orders: [ProfileOrder], query: String) -> [ProfileOrder] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return orders }
        return orders.filter { order in
            let fields: [String?] = [order.title, order.registrationNo, order.orderNum.map { String($0) },
                                     order.addressName, order.ticketName, order.organizerName]
            return fields.contains { $0?.localizedStandardContains(needle) == true }
        }
    }
}

private struct ProfileOrderRow: View {
    let order: ProfileOrder
    let historyState: OrderLifecycleState
    let statusKey: String
    /// mp-mine r3: the list draws 取消订单 / 立即支付 under the card, so the card drops its 查看详情 pill.
    var showsPayButtons: Bool = false
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    /// a11y-dt r3: the MP order-card icons grow with the .subheadline text beside them (were fixed 16 pt at AX5).
    @ScaledMetric(relativeTo: .subheadline) private var metaIconSide: CGFloat = 16
    @Environment(\.openURL) private var openURL
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    static func mapURL(_ address: String) -> URL? {
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [URLQueryItem(name: "q", value: address)]
        return parts?.url
    }
    var body: some View {
        // Source V3-22 card: cover | mode tag + state / name / time / place, then the 实付款 (待付款) line and its action.
        // The order number lives on the detail page only.
        VStack(alignment: .leading, spacing: 10) {
            content
            if let explanation = UnknownPaymentState.explanation(payment: order.paymentStatus, registration: order.registrationStatus) {
                Text(verbatim: explanation).font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.orders.history.unknownPayment")
            }
            Divider()
            footer
        }
        .padding(.vertical, 4)
    }
    private var stateChip: some View {
        OrderStatusChip(title: LocalizedStringKey(statusKey),
                        systemImage: Self.symbol(historyState),
                        emphasized: historyState == .pendingPayment || historyState == .notStarted || historyState == .inProgress)
    }
    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                OrderCoverTile(systemImage: order.sourceMode == .freeExplore ? "figure.walk" : "map",
                               url: QuestifyCardArtwork.safeURL(order.coverURL), size: 60, seed: order.title ?? "")
            }
            VStack(alignment: .leading, spacing: 6) {
                // Source moh-head: mode tag on the left, order state on the right.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) { modeTag; Spacer(minLength: 4); stateChip }
                    VStack(alignment: .leading, spacing: 4) { modeTag; stateChip }
                }
                Group {
                    if let title = order.title, !title.isEmpty { Text(verbatim: title) }
                    // FIN-16-7: MP OR-034 writes 已下架 when neither the activity nor the topic reads back.
                    else if order.title == nil { Text(verbatim: c.t("已下架", "No longer available")) }
                    else { Text("profile.orders.untitled") }
                }
                .font(.headline).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                // Source row shows the owner's MM.dd HH:mm range; otherwise keep the literal date.
                if let range = ProfileOrderTimeRangeText.text(start: order.startDate, end: order.endDate) {
                    meta(Text(verbatim: range).monospacedDigit(), mp: MPAsset.FeatureIcon.dOrderIcon).accessibilityIdentifier("profile.orderRow.timeRange")
                } else if let date = order.participateDate ?? order.startDate, !date.isEmpty {
                    meta(Text(verbatim: LocaleDisplay.civil(date, locale: locale)), mp: MPAsset.FeatureIcon.dOrderIcon)
                }
                if let location = order.addressName?.trimmingCharacters(in: .whitespaces), !location.isEmpty, location.lowercased() != "null" {
                    // FIN-16-7: MP onAddressTap opens the address in the map app; the card tap still opens the detail.
                    if let mapURL = Self.mapURL(location) {
                        Button { openURL(mapURL) } label: { meta(Text(verbatim: location), mp: MPAsset.FeatureIcon.dOrderIcon2) }
                            .buttonStyle(.borderless)
                            .frame(minHeight: 44, alignment: .leading)
                            .accessibilityLabel(Text(verbatim: c.t("在地图中打开 ", "Open in Maps: ") + location))
                            .accessibilityIdentifier("profile.orderRow.address")
                    } else {
                        meta(Text(verbatim: location), mp: MPAsset.FeatureIcon.dOrderIcon2)
                    }
                }
                // FIN-16-5: 待付款 with payment held behind the release switch says where to pay instead of staying silent.
                if historyState == .pendingPayment, !ReleaseMoneyWriteSwitch.paymentEnabled {
                    meta(Text("profile.orders.payElsewhere"), "info.circle").accessibilityIdentifier("profile.orderRow.payElsewhere")
                }
            }
        }
    }
    @ViewBuilder private var modeTag: some View {
        switch order.sourceMode {
        case .cityOrienteering?:
            // HANDOFF-R1 MC-35 / §2 Status: blue is not used for status or tags.
            Text("profile.orders.mode.city").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        case .freeExplore?:
            Text("profile.orders.mode.free").font(.caption.weight(.semibold)).foregroundStyle(.green)
        case nil: EmptyView()
        }
    }
    private func meta(_ text: Text, _ symbol: String) -> some View {
        Label { text.fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: symbol).accessibilityHidden(true) }
            .font(.subheadline).foregroundStyle(.secondary)
    }
    /// MP order card icons (`d_orderIcon.png` time, `d_orderIcon2.png` address), drawn as shipped.
    private func meta(_ text: Text, mp icon: Image) -> some View {
        Label { text.fixedSize(horizontal: false, vertical: true) } icon: {
            icon.resizable().scaledToFit().frame(width: metaIconSide, height: metaIconSide).accessibilityHidden(true)
        }
        .font(.subheadline).foregroundStyle(.secondary)
    }
    private var footer: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                                  : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            // Source 实付款 ¥x; an unknown amount shows "—", never a currency caveat.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Source: 待付款 while registrationStatus == 1, otherwise 实付款.
                // MP OR-021: 待付款 reads pendingPayAmount and hides the whole line when it is missing.
                if order.registrationStatus != 1 || order.pendingPayAmount != nil {
                Text(order.registrationStatus == 1 ? "u9cde.orders.payable" : "profile.orders.paid").font(.subheadline).foregroundStyle(.secondary)
                Text(verbatim: (order.registrationStatus == 1 ? order.pendingPayAmount : order.actualPaidAmount).map(ProfileOrderYuan.text) ?? "—")
                    .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
                    .cyWrapText()
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            // Visual label only: the whole card is the NavigationLink, so there is a single control.
            // Source shows 查看详情 for pending/registered orders, 查看退款详情 for refunds, and nothing on closed orders.
            // mp-mine r3: with payment on, the pending card's 取消订单 / 立即支付 are drawn by the list under the card.
            if showsPayButtons {
                EmptyView()
            } else if historyState == .refunding || historyState == .refunded {
                OrderPillLabel(title: Text(verbatim: c.t("查看退款详情", "View refund details")))
            } else if historyState == .manualRefund {
                // FIN-16-7: MP manual_refund reads 查看处理进度.
                OrderPillLabel(title: Text(verbatim: c.t("查看处理进度", "View progress")))
            } else if order.registrationStatus == 1 || order.registrationStatus == 2 {
                OrderPillLabel(title: Text(verbatim: c.t("查看详情", "View details")))
            }
        }
    }
    /// The symbol and label carry the state together, never colour alone.
    private static func symbol(_ state: OrderLifecycleState) -> String {
        switch state {
        case .pendingPayment: return "creditcard"
        case .notStarted: return "ticket"
        case .inProgress: return "figure.walk"
        case .completed: return "checkmark.seal"
        case .cancelled: return "xmark.circle"
        case .expired: return "calendar.badge.exclamationmark"
        case .refunding, .manualRefund: return "arrow.uturn.backward.circle"
        case .refunded: return "arrow.uturn.backward"
        case .nonRefundable: return "lock"
        case .unknown: return "questionmark.circle"
        }
    }
}

@MainActor
struct ProfileOrderDetailView: View {
    let id: Int
    let reader: any ProfileReading
    var lifecycleCoordinator: OrderLifecycleCoordinator? = nil
    var mediaScope: UUID = UUID()
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var ticketReader: (any TicketWalletReading)? = nil
    /// Existing locator only. Nil stays quiet and does not invent an order id.
    var orderLocator: SupportEventLocator? = nil
    var orderSupport: ProfileOrderSupportLookup? = nil
    var lookedUpOrderID: Int64? = nil
    var onOpenedOrder: ((Int) -> Void)? = nil
    @State private var ticketTarget: ProfileOrderTicketTarget?
    @State private var ticketEntryVisible = false
    @State private var ticketPresentationID = UUID()
    @State private var readBackForID: Int?
    @State private var openedOrderID: Int64?
    @State private var copyToast: LocalizedStringKey?
    @State private var copyTone: CYToastTone = .success
    var body: some View {
        ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.order.detail", issueCopy: .orderDetail, load: { try await reader.profileOrder(id: id) }) { order in
            ProfileOrderMeetingPointHost(order: order, requestedID: id, reader: reader) { meetingPointEntry in
            List {
                ProfileOrderHeroSection(order: order)
                ProfileOrderStateNoticeSection(order: order)
                Section(LocalizedStringKey("profile.orderParity.section.order")) {
                    if let title = order.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ProfileOptionalRow(key: "profile.orders.name", value: title)
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(Text(verbatim: title))
                            .accessibilityIdentifier("profile.order.detail.name")
                    }
                    ProfileOptionalRow(key: "profile.orders.number", value: order.registrationNo)
                    ProfileOrderNumberCopySection(order: order, requestedID: id, reader: reader) { ok in
                        copyTone = ok ? .success : .warning
                        copyToast = ok ? "localCopy.copied" : "localCopy.failed"
                    }
                    LabeledContent("profile.orders.state") { ProfileOrderStatus(order: order) }
                    ProfileOptionalRow(key: "profile.orders.serverHint", value: order.orderHint)
                    LabeledContent("profile.orders.amount") { ProfileOrderAmountLabel(amount: order.payableAmount) }
                    ProfileOptionalRow(key: "profile.orders.ticket", value: order.ticketName)
                    if let count = order.orderNum { LabeledContent("profile.orders.quantity", value: String(count)) }
                    ProfileOptionalRow(key: "profile.orders.organizer", value: order.organizerName)
                }
                Section("profile.orders.schedule") {
                    ProfileOrderTicketScheduleRows(order: order)
                    ProfileOptionalRow(key: "profile.orders.location", value: order.addressName)
                    if let makeExternalMaps {
                        PlatformExternalMapHost(destination: .init(name: order.meetingPoint ?? "", address: order.meetingPoint, latitude: order.gatherLatitude, longitude: order.gatherLongitude), scope: mediaScope, makeModel: makeExternalMaps)
                    } else {
                        meetingPointEntry
                    }
                }
                Section("profile.orders.records") {
                    if let code = order.verificationStatus {
                        LabeledContent("profile.orders.verification") {
                            if code == 1 { Text("profile.orders.verified") }
                            else if code == 0 { Text("profile.orders.notVerified") }
                            else { Text("profile.orders.unknown") }
                        }
                    }
                    // Keep status dimensions distinct; never infer settlement/refund from registration.
                    if let explanation = UnknownPaymentState.explanation(payment: order.paymentStatus, registration: order.registrationStatus) {
                        Text(verbatim: explanation).accessibilityIdentifier("profile.order.detail.unknownPayment")
                    } else if let code = order.paymentStatus {
                        LabeledContent("profile.orderParity.payment") { ProfileOrderCodeText(label: .payment(code)) }
                    }
                    if let code = order.refundPayoutStatus {
                        LabeledContent("profile.orders.refund") { ProfileRefundStatus(code: code) }
                    }
                }
                Section(LocalizedStringKey(order.paymentSectionTitleKey)) {
                    if let amount = order.wechatPaymentAmount { LabeledContent("profile.orders.cashAmount") { ProfileOrderAmountLabel(amount: amount) } }
                    if let count = order.pointUsed { LabeledContent("profile.orders.pointsUsed", value: String(count)) }
                    if let amount = order.pointDeductAmount { LabeledContent("profile.orders.pointsDeduction") { ProfileOrderAmountLabel(amount: amount) } }
                    if let amount = order.pointPaymentAmount { LabeledContent("profile.orders.pointsMoney") { ProfileOrderAmountLabel(amount: amount) } }
                    // The source shows only the payment method label; a bare method code is not shown.
                    if let amount = order.refundAmount { LabeledContent("profile.orders.refundAmount") { ProfileOrderAmountLabel(amount: amount) } }
                    if let code = order.refundApplicationStatus {
                        LabeledContent("profile.orderParity.refundApplication") { ProfileOrderCodeText(label: .refundApplication(code)) }
                    }
                    ProfileOptionalRow(key: "profile.orders.manualRefund", value: order.manualRefundCaseStatus)
                }
                // mp-mine r3: team, merchant-message consent and invoice sit where the MP order detail puts them.
                ProfileOrderSourceDetailSections(order: order)
                    .mpSlots(beforeTimeline: AnyView(ProfileOrderTeamSeatClubSection(order: order)),
                             beforePaymentInfo: AnyView(ProfileOrderConsentSection(order: order)),
                             beforeRegistrant: AnyView(ProfileOrderInvoiceSection(order: order)))
                if order.settlementView.show {
                    Section("profile.order.settlement") {
                        if !order.settlementView.stage.isEmpty {
                            ProfileOrderSettlementCopy.stage(order.settlementView.stage)
                                .accessibilityIdentifier("profile.order.settlement.stage")
                        }
                        ForEach(Array(order.settlementView.rows.enumerated()), id: \.offset) { _, row in
                            LabeledContent { ProfileOrderSettlementCopy.value(row) } label: { ProfileOrderSettlementCopy.label(row) }
                        }
                    }
                    .accessibilityIdentifier("profile.order.settlement")
                }
                // FIN-16-1 / FIN-17-1: the MP's only self-service money exit. The lifecycle screen (fresh read +
                // reviewed confirm sheet) opens when a reviewed writer is mounted for this reader; payment stays gated
                // inside it. Without a writer the support section says where to go instead of staying silent.
                if let lifecycleCoordinator, lifecycleCoordinator.hasReviewedWriter || lifecycleCoordinator.canDispatch || lifecycleCoordinator.canSimulate {
                    Section {
                        NavigationLink { OrderLifecycleView(id: id, coordinator: lifecycleCoordinator).id(lifecycleCoordinator.scope) } label: {
                            if let key = order.selfServiceExitKey {
                                Label(LocalizedStringKey(key), systemImage: "xmark.circle").foregroundStyle(.red)
                            } else {
                                Label("orderLifecycle.title", systemImage: "list.bullet.rectangle")
                            }
                        }.accessibilityIdentifier("profile.order.lifecycle")
                    }
                }
                if let ticketReader {
                    Section { ticketEntry(order: order, tickets: ticketReader) }
                }
                ExploreCompletionEntry(order: order, requestedID: id, origin: reader)
                ProfileOrderRecordSection(order: order)
                FreeExploreBundleReadEntry(order: order, requestedID: id, origin: reader)
                BundleCommerceOrderEntry(order: order, requestedID: id, origin: reader)
                // Source 退款与客服 (报名与客服 when free): 联系客服 opens the read-only support page.
                Section(LocalizedStringKey(order.isSourceFreeOrder ? "profile.orderP2.supportSection.free" : "profile.orderP2.supportSection")) {
                    // R7-MEM-17-2: MP refund-main / refund-sub text (D:328-329) instead of a bare 退款截止 row.
                    ProfileOrderRefundPolicyText(order: order)
                    NavigationLink { ParticipationSupportView() } label: {
                        Label("profile.orderP2.contactSupport", systemImage: "message")
                    }.accessibilityIdentifier("profile.order.detail.support")
                    if order.selfServiceExitKey != nil, lifecycleCoordinator?.hasReviewedWriter != true {
                        Text("profile.orderExit.viaSupport").font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("profile.order.detail.exitViaSupport")
                    }
                }
                if orderSupport != nil, order.id == id {
                    Section {
                        LabeledContent("profile.orders.number") {
                            if let lookedUpOrderID, lookedUpOrderID == Int64(id) {
                                Text(verbatim: String(lookedUpOrderID))
                            } else { Text("profile.orders.unknown") }
                        }.accessibilityIdentifier("profile.orders.supportLookup")
                    }
                }
            }
            }
        }
        .environment(\.profileReadShowsRefreshButton, false)
        .appNavigationTitle("profile.orders.detail")
        .navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome(domain: .player)
        .background {
            if orderLocator != nil {
                Color.clear.frame(width: 0, height: 0)
                    .accessibilityIdentifier(openedOrderID == Int64(id) ? "profile.order.readback.opened.\(id)" : "profile.order.readback.closed")
            }
        }
        .task(id: id) {
            readBackHeldOrder()
            if orderLocator == nil { onOpenedOrder?(id) }
        }
        .navigationDestination(item: $ticketTarget) { target in
            if let ticketReader, target.registrationID == id, target.matches(origin: reader, tickets: ticketReader) {
                ProfileOrderTicketDestination(target: target, origin: reader, tickets: ticketReader)
                    .id(target.id)
            } else { ProfileOrderTicketUnavailableView() }
        }
        .onAppear { ticketEntryVisible = true; ticketPresentationID = UUID() }
        // A push must not remove its destination. Retire only activation callbacks here.
        .onDisappear { ticketEntryVisible = false; ticketPresentationID = UUID() }
        .onChange(of: reader.identity) { _, _ in retireTicketEntry() }
        .onChange(of: reader.isConfigured) { _, _ in retireTicketEntry() }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in retireTicketEntry() }
        .onChange(of: ticketReader.map { ObjectIdentifier($0) }) { _, _ in retireTicketEntry() }
        .onChange(of: ticketReader?.scope) { _, _ in retireTicketEntry() }
        .onChange(of: ticketReader?.isAuthenticated) { _, _ in retireTicketEntry() }
        .onChange(of: ticketReader?.isConfigured) { _, _ in retireTicketEntry() }
        .onChange(of: id) { _, _ in retireTicketEntry() }
        .cyToast(message: $copyToast, tone: copyTone)
    }
    /// One locateByOrderId for the id this page already holds. The returned first
    /// ORDER id must equal that id. A different id is not opened.
    private func readBackHeldOrder() {
        guard readBackForID != id else { return }
        readBackForID = id
        openedOrderID = nil
        guard let locator = orderLocator else { return }
        let requested: Int64? = id > 0 ? Int64(id) : nil
        do {
            let located = try locator.locateByOrderId(requested, currentProjection: nil)
            guard let requested, let located, located.orderId == requested else { return }
            openedOrderID = OrderPageReadback.openedID(requested: requested, events: located.originalEvents)
        } catch {
            openedOrderID = nil
        }
    }
    @ViewBuilder private func ticketEntry(order: ProfileOrder, tickets: any TicketWalletReading) -> some View {
        let renderedPresentation = ticketPresentationID
        let target = ProfileOrderTicketTarget(order: order, requestedID: id, origin: reader, tickets: tickets)
        Button {
            guard ticketEntryVisible, ticketTarget == nil, renderedPresentation == ticketPresentationID,
                  let target, target.matches(origin: reader, tickets: tickets) else { return }
            ticketTarget = target
        } label: { Label("orderTicketEntry.open", systemImage: "ticket") }
            .disabled(target == nil || !ticketEntryVisible)
            .accessibilityIdentifier("orderTicketEntry.open")
        Text(target == nil ? "orderTicketEntry.unavailable" : "orderTicketEntry.freshRead")
            .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private func retireTicketEntry() { ticketTarget = nil; ticketPresentationID = UUID() }
}

/// Presentation only; the enclosing ProfileReadScreen owns the existing reader/scope lifetime.
struct ProfileOrderTicketScheduleRows: View {
    let order: ProfileOrder
    var body: some View {
        let schedule = ProfileOrderSchedulePresentation(order)
        if schedule.isTicket {
            Text("profileTicketSchedule.title").font(.body.weight(.medium))
                .accessibilityIdentifier("profile.order.ticketSchedule")
            ProfileOrderTicketTimeRow(label: "profile.orders.start", value: schedule.start)
            ProfileOrderTicketTimeRow(label: "profile.orders.end", value: schedule.end)
        } else {
            if schedule.start != .absent || schedule.end != .absent {
                Text("profileTicketSchedule.ownerTimes").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.order.ownerSchedule")
            }
            if schedule.start != .absent { ProfileOrderTicketTimeRow(label: "profile.orders.start", value: schedule.start) }
            if schedule.end != .absent { ProfileOrderTicketTimeRow(label: "profile.orders.end", value: schedule.end) }
        }
    }
}
struct ProfileOrderSchedulePresentation {
    let isTicket: Bool
    let start: ProfileOrderTicketTime
    let end: ProfileOrderTicketTime
    init(_ order: ProfileOrder) {
        if let schedule = order.ticketSchedule {
            isTicket = true; start = schedule.start; end = schedule.end
        } else {
            func source(_ value: String?) -> ProfileOrderTicketTime {
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .absent }
                return .source(value)
            }
            isTicket = false; start = source(order.startDate); end = source(order.endDate)
        }
    }
}
struct ProfileOrderTicketTimeRow: View {
    let label: LocalizedStringKey
    let value: ProfileOrderTicketTime
    @Environment(\.timeZone) private var phoneTimeZone
    var body: some View {
        LabeledContent(label) {
            if let display = value.display(phoneTimeZone: phoneTimeZone) {
                Text(verbatim: display).textSelection(.enabled).monospacedDigit()
            } else if case .source(let raw) = value {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(verbatim: raw).textSelection(.enabled)
                    Text("profileTicketSchedule.unparsed").font(.footnote).foregroundStyle(.secondary)
                }.fixedSize(horizontal: false, vertical: true)
            } else { Text("profile.orders.unknown") }
        }
    }
}

/// FIN-17-5 (handoff MC-35, MP hero 578:2298): paid amount, then the order name and a status chip, before any row.
private struct ProfileOrderHeroSection: View {
    let order: ProfileOrder
    private var title: String? {
        let value = order.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
    private var statusText: String? {
        let value = order.statusText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
    private var stateKey: LocalizedStringKey {
        switch order.registrationState {
        case .awaitingPayment: return "profile.orders.awaitingPayment"
        case .registered: return "profile.orders.registered"
        case .cancelled: return "profile.orders.cancelled"
        case .expired: return "profile.orders.expired"
        case .unknown: return "profile.orders.unknown"
        }
    }
    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
            OrderCoverTile(url: QuestifyCardArtwork.safeURL(order.coverURL), size: 72, fallback: MPAsset.EmptyState.iconTicketEmpty)
            VStack(alignment: .leading, spacing: 4) {
                // Unknown money is an em dash, never ¥0.
                Text(verbatim: order.actualPaidAmount.map(ProfileOrderYuan.text) ?? "—")
                    .font(.largeTitle.weight(.bold)).monospacedDigit().foregroundStyle(.primary)
                if let title {
                    Text(verbatim: title).font(.headline).foregroundStyle(.primary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    if let statusText { Text(verbatim: statusText) } else { Text(stateKey) }
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.order.detail.hero")
        }
    }
}

private struct ProfileOrderStatus: View {
    let order: ProfileOrder
    private var stateKey: LocalizedStringKey {
        switch order.registrationState {
        case .awaitingPayment: return "profile.orders.awaitingPayment"
        case .registered: return "profile.orders.registered"
        case .cancelled: return "profile.orders.cancelled"
        case .expired: return "profile.orders.expired"
        case .unknown: return "profile.orders.unknown"
        }
    }
    var body: some View {
        if let status = order.statusText, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(verbatim: status) }
        else { Text(stateKey) }
    }
}
private struct ProfileRefundStatus: View {
    let code: Int
    var body: some View {
        switch code {
        case 0: Text("profile.orders.refunding")
        case 1, 4: Text("profile.orders.refunded")
        case 2: Text("profile.orders.refundManualPending")
        case 3: Text("profile.orders.refundManualReview")
        case 5: Text("profile.orders.refundQueued")
        case 6: Text("profile.orders.refundDispatching")
        default: Text("profile.orders.unknown")
        }
    }
}

/// Source STATE_TITLE card: title, server orderHint and the projected state tag.
private struct ProfileOrderStateNoticeSection: View {
    let order: ProfileOrder
    var body: some View {
        // Evaluated on render like the source detail; the card never triggers a read.
        if let notice = order.stateNotice() {
            Section {
                // Native r2: system text styles; the state tag is secondary text, not a capsule.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(LocalizedStringKey(notice.titleKey)).font(.headline)
                            .accessibilityIdentifier("profile.order.detail.stateTitle")
                        Spacer(minLength: 8)
                        Text(LocalizedStringKey(notice.tagKey)).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("profile.order.detail.stateTag")
                    }
                    if let hint = notice.hint { Text(verbatim: hint).font(.subheadline).foregroundStyle(.secondary) }
                }.accessibilityElement(children: .contain)
            }
        }
    }
}

/// R7-MEM-17-2: MP `refundDeadlineDisplay || 支付成功后将按订单退款截止时间判断是否可原路退款。`, plus
/// 本单未收取费用 for a free order. The settle-stage 退款进度 rows need Core fields (see receipt).
private struct ProfileOrderRefundPolicyText: View {
    let order: ProfileOrder
    @Environment(\.locale) private var locale
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let deadline = order.refundDeadlineDisplay?.trimmingCharacters(in: .whitespacesAndNewlines), !deadline.isEmpty {
                Text(verbatim: deadline).foregroundStyle(.primary)
            } else {
                Text(verbatim: c.t("支付成功后将按订单退款截止时间判断是否可原路退款。", "After payment, the order’s refund deadline decides whether it can be refunded to the original method."))
                    .foregroundStyle(.primary)
            }
            if order.isSourceFreeOrder {
                Text(verbatim: c.t("本单未收取费用。如需咨询报名安排，请联系客服。", "This order was free. For questions about your booking, contact support."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.order.detail.refundPolicy")
    }
}

/// Known source codes are labeled; any other code stays visible as a raw value.
private struct ProfileOrderCodeText: View {
    let label: ProfileOrderCodeLabel
    var body: some View {
        switch label {
        case .key(let key): Text(LocalizedStringKey(key))
        case .raw: Text(verbatim: "—")
        }
    }
}

/// Owner decision #9 (11-24): money shows two decimals (¥12.50) through the one shared formatter.
/// `OwnedOrderMoneyText` keeps the exact decimal digits; `MoneyDisplay.text` pads them lexically (no Double).
enum ProfileOrderYuan {
    static func text(_ amount: Decimal) -> String { text(amount, locale: .current) }
    /// i18n r1: Chinese keeps `¥x`; other languages name the currency (`CN¥x`).
    static func text(_ amount: Decimal, locale: Locale) -> String {
        let raw = OwnedOrderMoneyText.string(amount)
        guard LocaleDisplay.isChinese(locale) else { return LocaleDisplay.money(text: raw, locale: locale) }
        return "¥" + MoneyDisplay.text(raw)
    }
}

/// FIN-17-2: real money reads "¥x" like the MP and the list row, with no currency caveat.
private struct ProfileOrderAmountLabel: View {
    let amount: Decimal?
    var body: some View {
        if let amount {
            Text(verbatim: ProfileOrderYuan.text(amount)).monospacedDigit().foregroundStyle(.primary)
        } else { Text("activity.priceUnknown").foregroundStyle(.secondary) }
    }
}

extension ProfileOrder {
    /// MP `cancelRegistration` label by state: unpaid → 取消订单, paid free → 取消报名, paid and refundable → 申请退款.
    /// Nil when no self-service exit applies (verified, closed, refund already applied, or unknown state).
    var selfServiceExitKey: String? {
        guard verificationStatus == 0 else { return nil }
        if registrationStatus == 1, paymentStatus == 1 { return "profile.orderExit.cancel" }
        if registrationStatus == 2, paymentStatus == 2 {
            if isSourceFreeOrder { return "profile.orderExit.cancelSignup" }
            return refundable == true ? "profile.orderExit.refund" : nil
        }
        return nil
    }

    /// R7-MEM-16-1 card label (MP order-history index.wxml:84-90). A refundable paid order reads 取消并退款 and
    /// shows only while the refund switch is on; the other exits keep the detail label.
    var cardExitKey: String? {
        guard let key = selfServiceExitKey else { return nil }
        guard key == "profile.orderExit.refund" else { return key }
        return ReleaseMoneyWriteSwitch.refundEnabled ? "profile.orderExit.cancelRefund" : nil
    }

    /// R7-MEM-16-1: MP index.wxml:84-90 立即支付 on an unpaid card, while the payment switch is on.
    var cardPayNowShown: Bool {
        verificationStatus == 0 && registrationStatus == 1 && paymentStatus == 1 && ReleaseMoneyWriteSwitch.paymentEnabled
    }
}

/// FIN-17-3: opens the invoice pages from an order. Set by the session host; nil hides the links, not the status.
private struct ProfileOrderInvoicePresentationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> InvoiceLaunchPresentation?)? = nil
}

extension EnvironmentValues {
    var profileOrderInvoicePresentation: (@MainActor () -> InvoiceLaunchPresentation?)? {
        get { self[ProfileOrderInvoicePresentationKey.self] }
        set { self[ProfileOrderInvoicePresentationKey.self] = newValue }
    }
}

/// FIN-17-3: MP 发票 block (scene-member-order-detail index.wxml:217-237): 开票状态, 发票号 when issued,
/// 申请开票 when not applied, 发票申请 → detail while issuing or issued. Paused keeps only the status row.
@MainActor struct ProfileOrderInvoiceSection: View {
    let order: ProfileOrder
    @Environment(\.profileOrderInvoicePresentation) private var makeInvoice

    var body: some View {
        if let state = order.invoiceState, !order.isSourceFreeOrder {
            Section("profile.orderInvoice.section") {
                LabeledContent("profile.orderInvoice.state") { Text(stateKey(state)) }
                    .accessibilityIdentifier("profile.order.invoice.state")
                if state == .issued, let number = order.invoiceNo {
                    LabeledContent("profile.orderInvoice.number") { Text(verbatim: number).monospacedDigit().textSelection(.enabled) }
                }
                if let makeInvoice, let model = makeInvoice() {
                    if state == .notApplied {
                        NavigationLink { InvoiceLaunchApplyView(model: model) } label: { Text("profile.orderInvoice.apply") }
                            .accessibilityIdentifier("profile.order.invoice.apply")
                    } else if state != .paused, let application = order.invoiceApplicationID {
                        NavigationLink { InvoiceLaunchDetailView(model: model, applicationID: application) } label: {
                            Text("profile.orderInvoice.application")
                        }
                        .accessibilityIdentifier("profile.order.invoice.detail")
                    }
                }
            }
        }
    }

    private func stateKey(_ state: ProfileOrderInvoiceState) -> LocalizedStringKey {
        switch state {
        case .notApplied: return "profile.orderInvoice.notApplied"
        case .issuing: return "profile.orderInvoice.issuing"
        case .issued: return "profile.orderInvoice.issued"
        case .paused: return "profile.orderInvoice.paused"
        }
    }
}
