import SwiftUI

/// Copy for pages/merchant/coop-center lives in its own table.
func mcc(_ key: String, _ locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "MerchantCoopCenter", locale: locale))
}

/// Read-only cooperation center. Both tab reads start together on first appearance, each with
/// its own in-flight guard; switching tabs never refetches. Opening a card never applies or accepts.
@MainActor final class MerchantCoopCenterModel: ObservableObject {
    enum Issue: Equatable { case signIn, denied, failed(String?) }
    @Published private(set) var routes: [MerchantCoopCenterRoute] = []
    @Published private(set) var routeScope: MerchantCoopCenterPlaza.Scope?
    @Published private(set) var routesLoading = true
    @Published private(set) var routesIssue: Issue?
    @Published private(set) var events: [OfficialEvent] = []
    @Published private(set) var eventsLoading = true
    @Published private(set) var eventsIssue: Issue?
    @Published private(set) var focusedRouteID: String?
    let content: MerchantContentService
    let official: any OfficialEventReading
    private let now: () -> Date
    private let focusTopicID: String?
    private var routesInFlight = false, eventsInFlight = false, started = false
    private var eventsGeneration = UUID()
    private var officialObservation: OfficialReadInvalidationSubscription?

    init(content: MerchantContentService, official: any OfficialEventReading, focusTopicID: Int?, now: @escaping () -> Date) {
        self.content = content; self.official = official; self.now = now
        self.focusTopicID = focusTopicID.flatMap { $0 > 0 ? String($0) : nil }
        officialObservation = official.invalidationSignal?.observe { [weak self] in
            guard let self else { return }
            // Retire only the official list. The independent merchant routes stay intact.
            self.eventsGeneration = UUID(); self.eventsInFlight = false
            self.events = []; self.eventsLoading = false; self.eventsIssue = .failed(nil)
        }
    }
    func start() { guard !started else { return }; started = true; loadAll() }
    func loadAll() { loadRoutes(); loadEvents() }

    func loadRoutes() {
        guard !routesInFlight else { return }
        routesInFlight = true; routesLoading = true; routesIssue = nil
        let scope = content.scope, service = content, clock = now
        Task { [weak self] in
            let result: Result<MerchantCoopCenterPlaza, Error>
            do {
                let snapshot = try await service.loadRecruitingHome()
                result = .success(try MerchantCoopCenterPlaza(home: snapshot.value, now: clock()))
            } catch { result = .failure(error) }
            guard let self else { return }
            self.routesInFlight = false; self.routesLoading = false
            guard service.scope == scope else {
                // Logout or account change: never show the previous merchant's routes.
                self.routes = []; self.routeScope = nil; self.focusedRouteID = nil; self.routesIssue = .signIn; return
            }
            switch result {
            case .success(let plaza):
                self.routes = plaza.routes; self.routeScope = plaza.scope; self.locateFocus()
            case .failure(let error):
                if error as? MerchantCoopCenterFailure == .malformed { self.routeScope = nil }
                let issue = Self.issue(error)
                if issue == .denied || issue == .signIn {
                    // This current read refused access. Do not retain cards/counts from a prior grant.
                    self.routes = []; self.routeScope = nil; self.focusedRouteID = nil
                }
                self.routesIssue = issue
            }
        }
    }

    func loadEvents() {
        guard !eventsInFlight else { return }
        eventsInFlight = true; eventsLoading = true; eventsIssue = nil
        eventsGeneration = UUID(); let generation = eventsGeneration
        let reader = official, scope = official.scope
        Task { [weak self] in
            guard !Task.isCancelled, self?.eventsGeneration == generation else { return }
            guard reader.scope == scope else {
                self?.eventsInFlight = false; self?.eventsLoading = false
                self?.events = []; self?.eventsIssue = .signIn; return
            }
            let result: Result<[OfficialEvent], Error>
            do { result = .success(MerchantOfficialRecruitment.visible(try await reader.events(city: nil))) }
            catch { result = .failure(error) }
            guard let self else { return }
            guard self.eventsGeneration == generation else { return }
            self.eventsInFlight = false; self.eventsLoading = false
            guard reader.scope == scope else { self.events = []; self.eventsIssue = .signIn; return }
            switch result {
            case .success(let rows): self.events = rows
            case .failure(let error):
                let issue = Self.issue(error)
                if issue == .denied || issue == .signIn { self.events = [] }
                self.eventsIssue = issue
            }
        }
    }

    /// Source CU-M-85: mark and scroll to the recommended topic; absent means stay quietly on the list.
    private func locateFocus() {
        guard let focusTopicID, routes.contains(where: { $0.id == focusTopicID }) else { return }
        focusedRouteID = focusTopicID
    }

    static func issue(_ error: Error) -> Issue {
        if let error = error as? APIError, error == .unauthorized { return .signIn }
        if let error = error as? MerchantContentFailure {
            switch error {
            case .denied: return .denied
            case .rejected(_, let message):
                let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return .failed(text.isEmpty ? nil : text)
            default: return .failed(nil)
            }
        }
        if let error = error as? OfficialReadFailure, error == .forbidden || error == .noPublisherPermission { return .denied }
        return .failed(nil)
    }
}

@MainActor struct MerchantCoopCenterView: View {
    @StateObject private var model: MerchantCoopCenterModel
    @State private var tab: MerchantCoopCenterTab
    @State private var showsInbox = false
    /// MC7-27-4: a failed refresh over a shown list keeps the list and says so.
    @State private var refreshToast: LocalizedStringKey?
    @Environment(\.locale) private var locale
    private let officialActions: OfficialActionCoordinator?
    private let inboxDestination: ((@escaping () -> Void) -> AnyView)?
    /// MC7-27-1: MP `goInbox` pushes the in-app 消息 home (subpackageB/pages/im/list). When the host provides it, the bell
    /// pushes it; otherwise the bell keeps the 协作邀请 sheet.
    private let messagesDestination: (() -> AnyView)?

    init(content: MerchantContentService, official: any OfficialEventReading, initialTab: MerchantCoopCenterTab = .plaza,
         focusTopicID: Int? = nil, officialActions: OfficialActionCoordinator? = nil, now: @escaping () -> Date = { Date() },
         inboxDestination: ((@escaping () -> Void) -> AnyView)? = nil, messagesDestination: (() -> AnyView)? = nil) {
        _model = StateObject(wrappedValue: MerchantCoopCenterModel(content: content, official: official, focusTopicID: focusTopicID, now: now))
        _tab = State(initialValue: initialTab)
        self.officialActions = officialActions; self.inboxDestination = inboxDestination
        self.messagesDestination = messagesDestination
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(selection: $tab) {
                Text(mcc("merchantCoopCenter.tab.official", locale)).tag(MerchantCoopCenterTab.official)
                Text(mcc("merchantCoopCenter.tab.plaza", locale)).tag(MerchantCoopCenterTab.plaza)
            } label: { Text(mcc("merchantCoopCenter.title", locale)) }
            .pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
            .accessibilityIdentifier("merchantCoopCenter.tabs")
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch tab {
                        case .plaza: plaza
                        case .official: officialList
                        }
                    }.padding(16)
                }
                .refreshable { model.loadAll() }
                .onChange(of: model.focusedRouteID) { _, id in
                    guard let id, tab == .plaza else { return }
                    withAnimation { proxy.scrollTo("route." + id, anchor: .top) }
                }
            }
        }
        .navigationTitle(mcc("merchantCoopCenter.title", locale)).navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.merchant)
        .toolbar {
            if let messagesDestination {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { messagesDestination() } label: { Image(systemName: "bell") }
                        .accessibilityLabel(mcc("merchantCoopCenter.inbox", locale))
                        .accessibilityIdentifier("merchantCoopCenter.inbox")
                }
            } else if inboxDestination != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsInbox = true } label: { Image(systemName: "bell") }
                        .accessibilityLabel(mcc("merchantCoopCenter.inbox", locale))
                        .accessibilityIdentifier("merchantCoopCenter.inbox")
                }
            }
        }
        .sheet(isPresented: $showsInbox) {
            inboxDestination?({ showsInbox = false })
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
        }
        .task { model.start() }
        .onChange(of: model.routesIssue) { _, issue in
            if issue != nil, !model.routes.isEmpty { refreshToast = "merchantCoop.coopCenter.refreshFailed" }
        }
        .onChange(of: model.eventsIssue) { _, issue in
            if issue != nil, !model.events.isEmpty { refreshToast = "merchantCoop.coopCenter.refreshFailed" }
        }
        .cyToast(message: $refreshToast)
    }

    // MARK: 广场
    @ViewBuilder private var plaza: some View {
        if model.routesLoading && model.routes.isEmpty {
            MerchantCoopCenterSkeleton()
        } else if let issue = model.routesIssue, model.routes.isEmpty {
            issueView(issue, title: mcc("merchantCoopCenter.plaza.error.title", locale), fallback: mcc("merchantCoopCenter.plaza.error.fallback", locale),
                      id: "merchantCoopCenter.plaza.error") { model.loadRoutes() }
        } else {
            if model.routesLoading {
                Text(mcc("merchantCoopCenter.plaza.refreshing", locale)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("merchantCoopCenter.plaza.refreshing")
            }
            ForEach(Array(model.routes.enumerated()), id: \.offset) { _, route in
                MerchantCoopCenterRouteCard(route: route, focused: model.focusedRouteID == route.id, content: model.content)
                    .id("route." + route.id)
            }
            if let scope = model.routeScope {
                Text(String(format: mcc("merchantCoopCenter.plaza.scope", locale), scope.openCount, scope.shownCount))
                    .cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("merchantCoopCenter.plaza.scope")
            }
            if model.routes.isEmpty {
                emptyView(mcc("merchantCoopCenter.plaza.empty", locale), id: "merchantCoopCenter.plaza.empty")
            }
        }
    }

    // MARK: 官方活动
    @ViewBuilder private var officialList: some View {
        if model.eventsLoading && model.events.isEmpty {
            MerchantCoopCenterSkeleton()
        } else if let issue = model.eventsIssue, model.events.isEmpty {
            issueView(issue, title: mcc("merchantCoopCenter.official.error.title", locale), fallback: mcc("merchantCoopCenter.official.error.fallback", locale),
                      id: "merchantCoopCenter.official.error") { model.loadEvents() }
        } else {
            if model.eventsLoading {
                Text(mcc("merchantCoopCenter.official.refreshing", locale)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("merchantCoopCenter.official.refreshing")
            }
            ForEach(model.events) { event in
                NavigationLink {
                    OfficialEventDetailView(id: event.id, reader: model.official, actions: officialActions)
                } label: { MerchantCoopCenterEventCard(event: event) }
                .buttonStyle(.plain)
                .accessibilityHint(String(format: mcc("merchantCoopCenter.official.openLabel", locale), event.title))
                .accessibilityIdentifier("merchantCoopCenter.event." + String(event.id))
            }
            if model.events.isEmpty {
                emptyView(mcc("merchantCoopCenter.official.empty", locale), id: "merchantCoopCenter.official.empty")
            }
        }
    }

    private func emptyView(_ title: String, id: String) -> some View {
        ContentUnavailableView {
            Label { Text(title) } icon: { Image(systemName: "tray") }
        } actions: {
            Button { model.loadAll() } label: { Text(verbatim: mcc("merchantCoopCenter.refresh", locale)) }
                .buttonStyle(.borderedProminent).frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("merchantCoopCenter.refresh")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }

    /// The source veils load failures; native keeps a visible reason and an explicit retry.
    @ViewBuilder private func issueView(_ issue: MerchantCoopCenterModel.Issue, title: String, fallback: String, id: String,
                                        retry: @escaping () -> Void) -> some View {
        Group {
            switch issue {
            case .signIn:
                ContentUnavailableView {
                    Label { Text(mcc("merchantCoopCenter.signIn.title", locale)) } icon: { Image(systemName: "person.crop.circle.badge.exclamationmark") }
                } description: {
                    Text(mcc("merchantCoopCenter.signIn.reason", locale))
                }
            case .denied:
                ContentUnavailableView {
                    Label { Text(mcc("merchantCoopCenter.denied.title", locale)) } icon: { Image(systemName: "lock") }
                } description: {
                    Text(mcc("merchantCoopCenter.denied.reason", locale))
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label { Text(title) } icon: { Image(systemName: "exclamationmark.triangle") }
                } description: {
                    Text(message ?? fallback)
                } actions: {
                    Button(action: retry) { Text(verbatim: mcc("merchantCoopCenter.retry", locale)) }
                        .buttonStyle(.bordered).frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("merchantCoopCenter.retry")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
}

private struct MerchantCoopCenterSkeleton: View {
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(.quaternary).frame(height: 148)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mcc("merchantCoopCenter.loading", locale))
        .accessibilityIdentifier("merchantCoopCenter.loading")
    }
}

/// 稿 234:276 route card: 模式 / 余席 / 档期 / 地点 / 结算方式 / 招商截止 + 看详情.
struct MerchantCoopCenterRouteCard: View {
    let route: MerchantCoopCenterRoute
    let focused: Bool
    let content: MerchantContentService
    @Environment(\.locale) private var locale
    /// MC7-27-2: the whole card opens the route's chapters (MP coop-center/index.wxml:27-28); 看详情 stays as a label.
    var body: some View {
        if let topicID = route.topicID {
            NavigationLink {
                MerchantContentDocumentView(service: content, query: .chapters(topicID: topicID))
            } label: { card }
            .buttonStyle(.plain)
            .accessibilityHint(Text(String(format: mcc("merchantCoopCenter.detail.label", locale), route.title)))
        } else {
            card
        }
    }
    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let mode = modeText {
                    Text(mode).cyText(.meta, weight: .semibold).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                Spacer()
                if let seat = seatText {
                    Text(seat.text).cyText(.meta, weight: .semibold).foregroundStyle(seat.tight ? Color.orange : Color.green)
                        .accessibilityIdentifier("merchantCoopCenter.route.seat." + route.id)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                cover
                VStack(alignment: .leading, spacing: 4) {
                    if let date = dateText { Text(date).cyText(.meta).foregroundStyle(.secondary) }
                    Text(route.title).cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
                    if let meta = metaText { Text("◎  " + meta).cyText(.meta).foregroundStyle(.secondary) }
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    if let terms = termsText { Text(terms).font(.subheadline) }
                    if let deadline = deadlineText {
                        Text(deadline).cyText(.meta).foregroundStyle(.secondary)
                            .accessibilityIdentifier("merchantCoopCenter.route.deadline." + route.id)
                    }
                }
                Spacer()
                if route.topicID != nil {
                    Text(mcc("merchantCoopCenter.detail", locale))
                        .cyText(.label, weight: .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                        .background(Color.accentColor, in: Capsule())
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("merchantCoopCenter.route.detail." + route.id)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .overlay { if focused { RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).stroke(Color.accentColor, lineWidth: 2) } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("merchantCoopCenter.route." + route.id + (focused ? ".focused" : ""))
    }
    @ViewBuilder private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous)
        if let url = QuestifyCardArtwork.safeURL(route.cover) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { shape.fill(.quaternary) }
            }.frame(width: 72, height: 72).clipShape(shape).accessibilityHidden(true)
        } else { shape.fill(.quaternary).frame(width: 72, height: 72).accessibilityHidden(true) }
    }
    private var modeText: String? {
        switch route.mode {
        case .cityOrienteering: return mcc("merchantCoopCenter.mode.city", locale)
        case .freeExploration: return mcc("merchantCoopCenter.mode.free", locale)
        case nil: return nil
        }
    }
    private var seatText: (text: String, tight: Bool)? {
        switch route.seat {
        case .full: return (mcc("merchantCoopCenter.seat.full", locale), true)
        case .remaining(let count, let tight): return (String(format: mcc("merchantCoopCenter.seat.remaining", locale), count), tight)
        case nil: return nil
        }
    }
    private func monthDay(_ value: MerchantCoopCenterMonthDay) -> String {
        String(format: mcc("merchantCoopCenter.date.monthDay", locale), value.month, value.day)
    }
    private var dateText: String? {
        guard let range = route.dateRange else { return nil }
        guard let end = range.1 else { return monthDay(range.0) }
        return String(format: mcc("merchantCoopCenter.date.range", locale), monthDay(range.0), monthDay(end))
    }
    private var metaText: String? {
        let parts = [route.city, route.stationCount.map { String(format: mcc("merchantCoopCenter.meta.stations", locale), $0) }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    private func shortTerms(_ mode: MerchantCoopCenterRoute.TermsMode) -> String {
        switch mode {
        case .perk: return mcc("merchantCoopCenter.terms.perk", locale)
        case .revshare: return mcc("merchantCoopCenter.terms.revshare", locale)
        case .traffic: return mcc("merchantCoopCenter.terms.trafficShort", locale)
        }
    }
    private var termsText: String? {
        switch route.terms {
        case .none: return nil
        case .mixed(let modes): return modes.map(shortTerms).joined(separator: " / ")
        case .single(let mode, let amount):
            switch mode {
            case .perk:
                guard let amount else { return mcc("merchantCoopCenter.terms.perk", locale) }
                return String(format: mcc("merchantCoopCenter.terms.perkAmount", locale), amount)
            case .revshare:
                guard let amount else { return mcc("merchantCoopCenter.terms.revshare", locale) }
                return String(format: mcc("merchantCoopCenter.terms.revshareAmount", locale), amount)
            case .traffic: return mcc("merchantCoopCenter.terms.traffic", locale)
            }
        }
    }
    private var deadlineText: String? {
        switch route.deadline {
        case .open(let day): return String(format: mcc("merchantCoopCenter.deadline.open", locale), monthDay(day))
        case .closed: return mcc("merchantCoopCenter.deadline.closed", locale)
        case nil: return nil
        }
    }
}

/// Official recruitment card with the source copy (全城 fallback, 信息不全 gap marker, 查看活动).
struct MerchantCoopCenterEventCard: View {
    let event: OfficialEvent
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            Text(cityText).cyText(.meta, weight: .semibold).foregroundStyle(CYColor.textSecondary)
            Text(event.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            if let subtitle = event.subtitle, !subtitle.isEmpty {
                Text(subtitle).cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            if event.recruitmentBlocked == true {
                VStack(alignment: .leading, spacing: 2) {
                    Label(mcc("merchantCoopCenter.official.gap", locale), systemImage: "exclamationmark.triangle").cyText(.meta, weight: .semibold)
                    Text(event.recruitmentWarningReason ?? mcc("merchantCoopCenter.official.gapFallback", locale)).cyText(.meta)
                }
                .foregroundStyle(CYColor.warningText).fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchantCoopCenter.event.gap." + String(event.id))
            }
            HStack(spacing: CYSpacing.xs) {
                Text(mcc("merchantCoopCenter.official.open", locale))
                Image(systemName: "chevron.forward").accessibilityHidden(true)
            }.cyText(.meta, weight: .semibold).foregroundStyle(CYColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard()
    }
    private var cityText: String {
        if let city = event.city, !city.isEmpty { return city }
        return mcc("merchantCoopCenter.official.cityAll", locale)
    }
}
