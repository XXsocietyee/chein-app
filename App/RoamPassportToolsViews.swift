import Charts
import SwiftUI
import UIKit
import Charts

/// Mini-program subpackageTools/anniversary and monthly-recap. Read-only; identity changes reset all private rows.
@MainActor struct RoamPassportToolsSection: View {
    let reader: (any RoamPassportToolsReading)?
    var routeDestination: ((String) -> AnyView)? = nil
    /// 导出探索记录 (scene-roam-history tools `export`).
    var privateTools: (any RoamPrivateToolsServing)? = nil
    private let pageOwner: RoamPassportToolsPageOwner
    private let isConfigured: Bool?
    private let privateScope: RoamPrivatePageScope?
    private let privateConfigured: Bool?
    @EnvironmentObject private var navigation: RoamPassportToolsNavigation
    init(
        reader: (any RoamPassportToolsReading)?,
        routeDestination: ((String) -> AnyView)? = nil,
        privateTools: (any RoamPrivateToolsServing)? = nil
    ) {
        self.reader = reader
        self.routeDestination = routeDestination
        self.privateTools = privateTools
        self.pageOwner = RoamPassportToolsPageOwner(reader)
        self.isConfigured = reader?.isConfigured
        self.privateScope = privateTools.map { RoamPrivatePageScope($0) }
        self.privateConfigured = privateTools?.isConfigured
        RoamHostedScopeTracker.shared.observePassport(reader)
        RoamHostedScopeTracker.shared.observePrivate(privateTools)
    }
    var body: some View {
        let _ = (pageOwner, isConfigured, privateScope, privateConfigured)
        Section("roam.tools.title") {
            NavigationLink { RoamAnniversaryView(reader: reader, routeDestination: routeDestination) } label: {
                Label("roam.tools.anniversary", systemImage: "calendar")
                    .background {
                        if navigation.openedTool == nil {
                            RoamHostedAccessibilityAnchor(
                                identifier: "roam.tools.anniversary.open",
                                action: { navigation.openedTool = RoamPassportOpenedTool(tool: .anniversary) }
                            )
                        }
                    }
            }.accessibilityIdentifier("roam.tools.anniversary.open")
            NavigationLink { RoamMonthlyRecapView(reader: reader, routeDestination: routeDestination) } label: {
                Label("roam.tools.recap", systemImage: "chart.bar")
                    .background {
                        if navigation.openedTool == nil {
                            RoamHostedAccessibilityAnchor(
                                identifier: "roam.tools.recap.open",
                                action: { navigation.openedTool = RoamPassportOpenedTool(tool: .recap) }
                            )
                        }
                    }
            }.accessibilityIdentifier("roam.tools.recap.open")
            NavigationLink { RoamExplorationExportView(tools: privateTools) } label: {
                Label("roam.export.title", systemImage: "square.and.arrow.down")
                    .background {
                        if navigation.openedTool == nil {
                            RoamHostedAccessibilityAnchor(
                                identifier: "roam.export.open",
                                action: { navigation.openedTool = RoamPassportOpenedTool(tool: .export) }
                            )
                        }
                    }
            }.accessibilityIdentifier("roam.export.open")
        }
        .onAppear { navigation.openedTool = nil }
    }
}

/// Shared by the tools rows and the list-level destination. A `navigationDestination(item:)`
/// on the section itself is inside the List and collapses those rows into one cramped line.
@MainActor private final class RoamPassportToolsNavigation: ObservableObject {
    @Published var openedTool: RoamPassportOpenedTool?
}

private struct RoamPassportOpenedTool: Identifiable, Hashable {
    let id = UUID()
    let tool: RoamPassportTool
}

private enum RoamPassportTool: Hashable { case anniversary, recap, export }

extension View {
    /// Hoist the tools push onto the List or NavigationStack. Do not call this from a row.
    func roamPassportToolsDestinations(
        reader: (any RoamPassportToolsReading)?,
        routeDestination: ((String) -> AnyView)?,
        privateTools: (any RoamPrivateToolsServing)?
    ) -> some View {
        modifier(RoamPassportToolsDestinationModifier(reader: reader, routeDestination: routeDestination, privateTools: privateTools))
    }
}

private struct RoamPassportToolsDestinationModifier: ViewModifier {
    let reader: (any RoamPassportToolsReading)?
    let routeDestination: ((String) -> AnyView)?
    let privateTools: (any RoamPrivateToolsServing)?
    @StateObject private var navigation = RoamPassportToolsNavigation()
    private var openedTool: Binding<RoamPassportOpenedTool?> {
        Binding(get: { navigation.openedTool }, set: { navigation.openedTool = $0 })
    }
    func body(content: Content) -> some View {
        content
            .environmentObject(navigation)
            .navigationDestination(item: openedTool) { item in
                switch item.tool {
                case .anniversary:
                    RoamAnniversaryView(reader: reader, routeDestination: routeDestination)
                case .recap:
                    RoamMonthlyRecapView(reader: reader, routeDestination: routeDestination)
                case .export:
                    RoamExplorationExportView(tools: privateTools)
                }
            }
    }
}

/// The original reader's selected read grant, not a new capability. Non-session examples
/// retain their existing identity contract; live pages cannot inherit another grant's rows.
struct RoamPassportToolsPageOwner: Hashable {
    let readerID: ObjectIdentifier?
    let identity: RoamExperienceIdentity?
    let readScope: UUID?
    @MainActor init(_ reader: (any RoamPassportToolsReading)?) {
        readerID = reader.map { ObjectIdentifier($0) }; identity = reader?.identity
        readScope = (reader as? RoamPassportToolsSessionReader)?.readScope
    }
    @MainActor func matches(_ reader: (any RoamPassportToolsReading)?) -> Bool { self == Self(reader) }
}

@MainActor struct RoamAnniversaryView: View {
    let reader: (any RoamPassportToolsReading)?
    var routeDestination: ((String) -> AnyView)? = nil
    private let initialOwner: RoamPassportToolsPageOwner
    private let initialConfigured: Bool?
    @ObservedObject private var scopeTracker = RoamHostedScopeTracker.shared
    init(reader: (any RoamPassportToolsReading)?, routeDestination: ((String) -> AnyView)? = nil) {
        self.reader = reader
        self.routeDestination = routeDestination
        self.initialOwner = RoamPassportToolsPageOwner(reader)
        self.initialConfigured = reader?.isConfigured
        RoamHostedScopeTracker.shared.observePassport(reader)
    }
    var body: some View {
        let _ = (scopeTracker.tick, initialOwner, initialConfigured)
        let owner = RoamPassportToolsPageOwner(reader)
        let _ = RoamHostedScopeTracker.shared.observePassport(reader)
        RoamAnniversaryContent(reader: reader, routeDestination: routeDestination, pageOwner: owner)
            .appNavigationTitle("roam.tools.anniversary").navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.player)
    }
}

/// Frozen UI read intent. Existing Core generations still own pagination and request completion.
struct RoamAnniversaryReadIntent {
    let intent: RoamAnniversaryListState.Intent
    private let readerID: ObjectIdentifier?
    private let owner: RoamExperienceIdentity?
    private let pageOwner: RoamPassportToolsPageOwner
    private let listGeneration: UInt64
    private let routeGeneration: UInt64
    private let visit: UUID
    @MainActor init(intent: RoamAnniversaryListState.Intent, reader: (any RoamPassportToolsReading)?,
                    state: RoamAnniversaryListState, navigation: RoamAnniversaryNavigationState, visit: UUID) {
        self.intent = intent; readerID = reader.map { ObjectIdentifier($0) }; owner = reader?.identity
        pageOwner = RoamPassportToolsPageOwner(reader)
        listGeneration = state.generation; routeGeneration = navigation.generation; self.visit = visit
    }
    @MainActor func matches(reader: (any RoamPassportToolsReading)?, state: RoamAnniversaryListState,
                            navigation: RoamAnniversaryNavigationState, visit: UUID) -> Bool {
        pageOwner.matches(reader) && self.visit == visit && readerID == reader.map { ObjectIdentifier($0) } && owner == reader?.identity &&
        listGeneration == state.generation && routeGeneration == navigation.generation
    }
}

@MainActor private struct RoamAnniversaryContent: View {
    let pageOwner: RoamPassportToolsPageOwner
    let reader: (any RoamPassportToolsReading)?
    let routeDestination: ((String) -> AnyView)?
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var visit = UUID()
    @State private var pickerDate = Date()
    @State private var state = RoamAnniversaryListState()
    @State private var navigation = RoamAnniversaryNavigationState()
    init(reader: (any RoamPassportToolsReading)?, routeDestination: ((String) -> AnyView)?,
         pageOwner: RoamPassportToolsPageOwner) {
        self.reader = reader; self.routeDestination = routeDestination; self.pageOwner = pageOwner
    }
    private static let shanghai: Calendar = {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: RoamShanghaiCalendar.offsetSeconds)!; return calendar
    }()
    private var dateLabel: String {
        if let day = state.displayedDay { return "\(day.month)." + String(format: "%02d", day.day) }
        let today = RoamShanghaiCalendar.today()
        return "\(today.month)." + String(format: "%02d", today.day)
    }
    private var unavailableError: Error? {
        guard let reader else { return APIError.notConfigured }
        guard reader.identity != nil else { return APIError.unauthorized }
        return reader.isConfigured && pageOwner.matches(reader) ? nil : APIError.notConfigured
    }
    var body: some View {
        let retry = readIntent(state.retryIntent), more = readIntent(.more), refresh = readIntent(.refresh)
        List {
            // TANNIV-1: no second 那年今日 under the bar title (the cover header drew the page-type title again).
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: dateLabel).cyText(.pageTitle).monospacedDigit()
                        .accessibilityIdentifier("roam.tools.anniversary.date")
                    Spacer()
                    DatePicker("roam.tools.anniversary.change", selection: $pickerDate, displayedComponents: .date)
                        .environment(\.timeZone, Self.shanghai.timeZone)
                        .environment(\.calendar, Self.shanghai)
                        .disabled(state.isLoading || unavailableError != nil)
                        .accessibilityLabel(Text("roam.tools.anniversary.change"))
                        .accessibilityIdentifier("roam.tools.anniversary.change")
                }
            }
            if let reader, reader.isOfflineExample { Section { RoamExperienceNotice(offline: true) } }
            if let error = unavailableError ?? state.error {
                Section {
                    if RoamHistoryErrorPresentation.resolve(error: error) == .denied {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text("roam.tools.anniversary.denied").cyText(.body)
                                .accessibilityIdentifier("roam.tools.anniversary.denied")
                            Button("action.retry") { enqueue(retry) }
                                .accessibilityIdentifier("roam.experience.retry")
                        }
                    } else { RoamExperienceIssue(error: error) { enqueue(retry) } }
                }
                .accessibilityIdentifier("roam.tools.anniversary.error")
            }
            if state.isLoading {
                // mp-states r3: MP wxml:13 cy-skeleton loading → one labelled system loader (the words are shown and spoken).
                Section {
                    ProgressView { Text("roam.tools.anniversary.loading") }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CYSpacing.xs)
                }
            }
            ForEach(unavailableError == nil ? state.rows : []) { item in
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("roam.tools.anniversary.yearsAgo \(item.yearsAgo)").cyText(.cardTitle).foregroundStyle(.tint)
                        if let title = anniversaryField(item.title) {
                            Text(verbatim: title).cyText(.sectionTitle)
                        }
                        if let completed = anniversaryField(item.completedMinuteText) {
                            Text("roam.tools.anniversary.completed \(completed)").cyText(.body).foregroundStyle(.secondary)
                        }
                    }.accessibilityElement(children: .combine)
                        .accessibilityIdentifier("roam.tools.anniversary.row")
                    switch RoamAnniversaryRouteAvailability.resolve(memory: item, hasDestination: routeDestination != nil) {
                    case .available(let target):
                        if routeDestination != nil {
                            Button {
                                guard isVisible, scenePhase == .active, unavailableError == nil else { return }
                                _ = navigation.open(target, memory: item, currentRows: state.rows, owner: reader?.identity)
                            } label: { Text("roam.tools.anniversary.openRoute") }
                                .disabled(state.isLoading)
                                // MP aria-label 查看当前路线 {title}; a blank title stays off the label.
                                .accessibilityLabel(anniversaryRouteLabel(item.title))
                                .accessibilityIdentifier("roam.tools.anniversary.openRoute")
                        }
                    case .invalidTopicID, .noDestination:
                        Label("topic.unavailable", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("roam.tools.anniversary.routeUnavailable")
                    }
                }
            }
            if unavailableError == nil && state.page != nil && !state.isLoading && state.rows.isEmpty && state.error == nil {
                Section { ContentUnavailableView("roam.tools.anniversary.empty", systemImage: "calendar") }
                    .accessibilityIdentifier("roam.tools.anniversary.empty")
            }
            if unavailableError == nil, let page = state.page, page.hasMore, !state.isLoading, state.error == nil {
                Button("roam.tools.loadMore") { enqueue(more) }
                    .accessibilityLabel(Text("roam.tools.anniversary.more.a11y"))
                    .accessibilityIdentifier("roam.tools.anniversary.more")
            }
        }.cyGroupedSurface()
        .navigationDestination(item: routeBinding(navigation.openedPresentation, owner: reader?.identity)) { lease in
            if let routeDestination {
                RoamAnniversaryRouteHost(presentation: lease, owner: reader?.identity,
                                         reader: reader, pageOwner: pageOwner, destination: routeDestination, navigation: $navigation)
            }
        }
        .onAppear {
            isVisible = true; visit = UUID()
            navigation.bind(to: reader?.identity)
            state.bind(to: reader?.identity)
            if state.page == nil, navigation.openedPresentation == nil { state.requestRefresh() }
            enqueueRefreshIfNeeded()
        }
        .onChange(of: pageOwner) { _, _ in
            navigation.invalidate()
            state.bind(to: nil)
            state.bind(to: reader?.identity)
            if reader?.isConfigured != true {
                state.revokeAccess(unavailableError ?? APIError.notConfigured)
            } else {
                state.requestRefresh()
                enqueueRefreshIfNeeded()
            }
        }
        .onChange(of: reader.map { ObjectIdentifier($0) }) { _, _ in
            // A replacement reader with the same account cannot inherit the old reader's rows/tasks.
            navigation.invalidate(); state.bind(to: nil); state.bind(to: reader?.identity)
            enqueueRefreshIfNeeded()
        }
        .onChange(of: reader?.identity) { _, newOwner in
            navigation.bind(to: newOwner)
            state.bind(to: newOwner)
            enqueueRefreshIfNeeded()
        }
        .onChange(of: reader?.isConfigured) { _, configured in
            if configured != true {
                navigation.invalidate()
                state.revokeAccess(unavailableError ?? APIError.notConfigured)
            } else {
                state.requestRefresh()
                enqueueRefreshIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                visit = UUID()
                state.requestRefresh()
                state.suspend()
            } else {
                enqueueRefreshIfNeeded()
            }
        }
        .onChange(of: state.displayedDay) { _, day in
            if let date = day?.pickerDate(referenceYear: state.page?.referenceYear ?? RoamShanghaiCalendar.today().year) {
                pickerDate = date
            }
        }
        .onChange(of: pickerDate) { _, value in
            let parts = Self.shanghai.dateComponents([.month, .day], from: value)
            guard let month = parts.month, let day = parts.day else { return }
            guard let selected = RoamAnniversaryListState.Day(month: month, day: day), state.select(selected) else { return }
            navigation.invalidate()
            enqueue(readIntent(.refresh))
        }
        .refreshable { await load(refresh) }
        .onDisappear { isVisible = false; visit = UUID(); state.suspend() }
        .background { RoamHostedAccessibilityGroup(items: anniversaryAccessibilityItems(more: more)) }
        .accessibilityIdentifier("roam.tools.anniversary")
    }
    private func anniversaryAccessibilityItems(more: RoamAnniversaryReadIntent) -> [RoamHostedAccessibilityItem] {
        guard navigation.openedPresentation == nil else { return [] }
        var items: [RoamHostedAccessibilityItem] = []
        if (unavailableError ?? state.error) != nil {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.anniversary.error"))
        }
        if unavailableError == nil, let item = state.rows.first {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.anniversary.row"))
            switch RoamAnniversaryRouteAvailability.resolve(memory: item, hasDestination: routeDestination != nil) {
            case .available(let target):
                if routeDestination != nil && !state.isLoading {
                    items.append(
                        RoamHostedAccessibilityItem(
                            identifier: "roam.tools.anniversary.openRoute",
                            action: {
                                guard isVisible, scenePhase == .active, unavailableError == nil else { return }
                                _ = navigation.open(target, memory: item, currentRows: state.rows, owner: reader?.identity)
                            }
                        )
                    )
                }
            case .invalidTopicID, .noDestination:
                items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.anniversary.routeUnavailable"))
            }
        }
        if unavailableError == nil && state.page != nil && !state.isLoading && state.rows.isEmpty && state.error == nil {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.anniversary.empty"))
        }
        if unavailableError == nil, let page = state.page, page.hasMore, !state.isLoading, state.error == nil {
            items.append(
                RoamHostedAccessibilityItem(
                    identifier: "roam.tools.anniversary.more",
                    action: { enqueue(more) }
                )
            )
        }
        return items
    }
    /// Capture the lease in the binding, not when a delayed pop callback runs.
    /// SwiftUI sets this item to nil for the actual pop, not for child coverage.
    private func routeBinding(_ lease: RoamAnniversaryRoutePresentation?,
                              owner: RoamExperienceIdentity?) -> Binding<RoamAnniversaryRoutePresentation?> {
        Binding(get: {
            unavailableError == nil && navigation.mayRemainOpen(lease, owner: owner) ? lease : nil
        }, set: { value in
            guard value == nil, pageOwner.matches(reader), owner == reader?.identity,
                  navigation.completeReturn(presentation: lease, owner: owner) else { return }
            state.requestRefresh()
            // The exact original pop lease already earned this refresh. Its queued read must
            // also keep the same source list generation and visit until dispatch.
            enqueueRefreshIfNeeded()
        })
    }
    private func readIntent(_ intent: RoamAnniversaryListState.Intent) -> RoamAnniversaryReadIntent {
        .init(intent: intent, reader: reader, state: state, navigation: navigation, visit: visit)
    }
    /// Blank title or completed text is absent on the row. A dash would look like another memory.
    private func anniversaryField(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    private func anniversaryRouteLabel(_ title: String?) -> Text {
        guard let title = anniversaryField(title) else { return Text("roam.tools.anniversary.openRoute") }
        return Text("roam.tools.anniversary.openRoute.a11y \(title)")
    }
    private func enqueue(_ offered: RoamAnniversaryReadIntent) {
        Task { await load(offered) }
    }
    private func enqueueRefreshIfNeeded() {
        guard state.needsRefresh else { return }
        enqueue(readIntent(.refresh))
    }
    private func load(_ offered: RoamAnniversaryReadIntent) async {
        guard !Task.isCancelled, isVisible, scenePhase == .active, navigation.openedPresentation == nil,
              pageOwner.matches(reader), offered.matches(reader: reader, state: state, navigation: navigation, visit: visit) else { return }
        guard unavailableError == nil else {
            state.revokeAccess(unavailableError ?? APIError.notConfigured)
            return
        }
        guard let reader, let request = state.begin(offered.intent, owner: reader.identity) else { return }
        do {
            var pages: [RoamAnniversaryPage] = []
            var query = request.query
            var boundary = request.boundary
            while pages.count < request.pageCount {
                guard pageOwner.matches(reader), state.isCurrent(request, owner: reader.identity) else { return }
                let value = try await reader.anniversary(query, boundary: boundary)
                try Task.checkCancellation()
                guard pageOwner.matches(reader), state.isCurrent(request, owner: reader.identity) else { return }
                guard reader.isConfigured else {
                    state.revokeAccess(APIError.notConfigured)
                    return
                }
                pages.append(value)
                guard value.hasMore else { break }
                query = RoamAnniversaryQuery(month: value.month, day: value.day, limit: request.query.limit,
                    cursor: value.nextCursor, referenceYear: value.referenceYear)
                boundary = value.items.last
            }
            _ = try state.accept(pages, for: request, owner: reader.identity)
        } catch {
            guard pageOwner.matches(reader) else { return }
            state.fail(error, for: request, owner: reader.identity, isConfigured: reader.isConfigured)
        }
    }
}

/// Pushes the host's existing topic detail for one validated card, under the
/// lease minted when the card was tapped. Disappearing is NOT a return: the
/// detail may only be covered (e.g. it drilled into a child page), so it just
/// notes the cover and keeps the lease. Only the navigation item's pop binding
/// completes the return, carrying this same immutable lease.
@MainActor private struct RoamAnniversaryRouteHost: View {
    let presentation: RoamAnniversaryRoutePresentation?
    let owner: RoamExperienceIdentity?
    let reader: (any RoamPassportToolsReading)?
    let pageOwner: RoamPassportToolsPageOwner
    let destination: (String) -> AnyView
    @Binding var navigation: RoamAnniversaryNavigationState
    @ObservedObject private var scopeTracker = RoamHostedScopeTracker.shared
    var body: some View {
        let _ = scopeTracker.tick
        let isValid = presentation != nil && pageOwner.matches(reader) && reader?.identity == owner &&
            reader?.isConfigured == true && navigation.mayRemainOpen(presentation, owner: owner)
        Group {
            if isValid, let presentation {
                destination(presentation.target.topicID)
            } else {
                Label("topic.unavailable", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("roam.tools.anniversary.routeUnavailable")
            }
        }
        .background {
            RoamHostedAccessibilityGroup(
                items: [
                    isValid
                        ? RoamHostedAccessibilityItem(identifier: "passport.scope.route")
                        : RoamHostedAccessibilityItem(identifier: "roam.tools.anniversary.routeUnavailable")
                ]
            )
        }
        .onDisappear { navigation.noteCovered(presentation, owner: owner) }
    }
}

@MainActor struct RoamMonthlyRecapView: View {
    @Environment(\.themeDomain) private var domain
    let reader: (any RoamPassportToolsReading)?
    var routeDestination: ((String) -> AnyView)? = nil
    private let initialOwner: RoamPassportToolsPageOwner
    private let initialConfigured: Bool?
    @ObservedObject private var scopeTracker = RoamHostedScopeTracker.shared
    init(reader: (any RoamPassportToolsReading)?, routeDestination: ((String) -> AnyView)? = nil) {
        self.reader = reader
        self.routeDestination = routeDestination
        self.initialOwner = RoamPassportToolsPageOwner(reader)
        self.initialConfigured = reader?.isConfigured
        RoamHostedScopeTracker.shared.observePassport(reader)
    }
    var body: some View {
        let _ = (scopeTracker.tick, initialOwner, initialConfigured)
        let owner = RoamPassportToolsPageOwner(reader)
        let _ = RoamHostedScopeTracker.shared.observePassport(reader)
        RoamMonthlyRecapContent(reader: reader, routeDestination: routeDestination).id(owner)
            .cyText(.body)   // TRECAP-3 residue
            .tint(Theme.Color.accent(in: domain))
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bgPage(in: domain))
            .themeDomain(domain)
            .appNavigationTitle("roam.tools.recap").navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.player)
    }
}

@MainActor private struct RoamMonthlyRecapContent: View {
    let reader: (any RoamPassportToolsReading)?
    let routeDestination: ((String) -> AnyView)?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lifetime: Lifetime
    private var model: RoamMonthlyRecapCoordinator { lifetime.model }
    private var readerID: ObjectIdentifier? { reader.map { ObjectIdentifier($0) } }
    @State private var pickedWeek: Int?
    /// The detail whose route link was activated through the hosted accessibility path (same push as tapping it).
    @State private var openedRouteDetail: UUID?
    init(reader: (any RoamPassportToolsReading)?, routeDestination: ((String) -> AnyView)?) {
        self.reader = reader; self.routeDestination = routeDestination
        _lifetime = StateObject(wrappedValue: Lifetime(reader: reader))
    }
    /// Scope and UI epoch only. The existing coordinator remains the sole query/cursor/detail owner.
    @MainActor private final class Lifetime: ObservableObject {
        @Published private(set) var model: RoamMonthlyRecapCoordinator
        @Published private(set) var active = false
        @Published private(set) var foreground = false
        @Published private(set) var ready = false
        private var source: (any RoamPassportToolsReading)?
        private var identity: RoamExperienceIdentity?
        private var readScope: UUID?
        private var mounted = false
        private var ticket = UUID()
        private var readTask: Task<Void, Never>?
        private var deferredReturn: RoamMonthlyRecapPresentation?
        init(reader: (any RoamPassportToolsReading)?) {
            source = reader; identity = reader?.identity
            readScope = (reader as? RoamPassportToolsSessionReader)?.readScope
            model = RoamMonthlyRecapCoordinator(reader: reader)
        }
        func matches(_ reader: (any RoamPassportToolsReading)?) -> Bool {
            source.map { ObjectIdentifier($0) } == reader.map { ObjectIdentifier($0) } && identity == reader?.identity &&
            readScope == (reader as? RoamPassportToolsSessionReader)?.readScope
        }
        func canPresent(_ reader: (any RoamPassportToolsReading)?) -> Bool { active && foreground && matches(reader) }
        func bind(_ reader: (any RoamPassportToolsReading)?) {
            guard !matches(reader) else { return }
            suspend(); deferredReturn = nil
            source = reader; identity = reader?.identity
            readScope = (reader as? RoamPassportToolsSessionReader)?.readScope
            model = RoamMonthlyRecapCoordinator(reader: reader)
        }
        func appear(_ reader: (any RoamPassportToolsReading)?, foreground: Bool) {
            mounted = true; bind(reader); resume(reader, foreground: foreground)
        }
        func resume(_ reader: (any RoamPassportToolsReading)?, foreground: Bool) {
            self.foreground = foreground
            guard mounted, foreground, !active else { return }
            active = true
            // A background detail dismissal is not permission to read while hidden. Finish that
            // exact original return only now, before allowing a fresh selection from the list.
            let returning = deferredReturn ?? model.presentation; deferredReturn = nil
            if let returning, model.isCurrent(returning) { run(reader) { await $0.completeReturn(returning) } }
            else { run(reader) { await $0.activate() } }
        }
        func suspend() {
            active = false; foreground = false; ready = false; ticket = UUID()
            readTask?.cancel(); readTask = nil; model.suspend()
        }
        func disappear() {
            // A sheet cover must not cancel its queued exact-return read. The attachment below
            // independently catches real parent pop/dismiss/dismantle, including while covered.
            if model.presentation != nil { return }
            leave()
        }
        func leave() { mounted = false; deferredReturn = nil; suspend() }
        func run(_ reader: (any RoamPassportToolsReading)?, _ work: @escaping @MainActor (RoamMonthlyRecapCoordinator) async -> Void) {
            let offered = ticket
            readTask = Task { [self] in
                guard offered == ticket, canPresent(reader), !Task.isCancelled else { return }
                await perform(reader, work)
            }
        }
        func perform(_ reader: (any RoamPassportToolsReading)?, _ work: @MainActor (RoamMonthlyRecapCoordinator) async -> Void) async {
            guard canPresent(reader), !Task.isCancelled else { return }
            ticket = UUID(); let offered = ticket, original = model
            ready = false; original.suspend()
            await work(original)
            guard offered == ticket, canPresent(reader), model === original, !Task.isCancelled else { return }
            ready = true
        }
        func returnFrom(_ lease: RoamMonthlyRecapPresentation, reader: (any RoamPassportToolsReading)?) {
            guard matches(reader), model.isCurrent(lease) else { return }
            if canPresent(reader) { run(reader) { await $0.completeReturn(lease) } }
            else { deferredReturn = lease }
        }
        func accessChanged(_ reader: (any RoamPassportToolsReading)?, foreground: Bool) {
            bind(reader); suspend(); model.synchronizeAccess(); resume(reader, foreground: foreground)
        }
    }
    @MainActor private struct LifetimeAttachment: UIViewControllerRepresentable {
        let lifetime: Lifetime
        func makeUIViewController(context: Context) -> Controller { Controller(lifetime: lifetime) }
        func updateUIViewController(_ controller: Controller, context: Context) {}
        static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.lifetime.leave() }
        @MainActor final class Controller: UIViewController {
            let lifetime: Lifetime
            init(lifetime: Lifetime) { self.lifetime = lifetime; super.init(nibName: nil, bundle: nil) }
            required init?(coder: NSCoder) { return nil }
            override func viewWillDisappear(_ animated: Bool) {
                super.viewWillDisappear(animated)
                var current: UIViewController? = self
                while let value = current {
                    if value.isBeingDismissed || value.isMovingFromParent { lifetime.leave(); return }
                    current = value.parent
                }
            }
        }
    }
    private var month: String { model.month }
    private var kind: RoamRecapKind { model.kind }
    private var page: RoamMonthlyRecapPage? { lifetime.canPresent(reader) && lifetime.ready && model.isLive ? model.page : nil }
    private var error: Error? { model.error }
    private var loading: Bool { model.isLoading }
    private var monthDate: Date {
        let (year, value) = RoamShanghaiCalendar.parseMonth(month) ?? (2000, 1)
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: value, day: 15, hour: 12)) ?? Date()
    }
    private func kindKey(_ value: RoamRecapKind) -> LocalizedStringKey {
        switch value { case .routes: return "roam.tools.recap.kind.routes"; case .places: return "roam.tools.recap.kind.places"; case .stamps: return "roam.tools.recap.kind.stamps" }
    }
    private func weeklyKey(_ value: RoamRecapKind) -> LocalizedStringKey {
        switch value { case .routes: return "roam.tools.recap.weekly.routes"; case .places: return "roam.tools.recap.weekly.places"; case .stamps: return "roam.tools.recap.weekly.stamps" }
    }
    var body: some View {
        List {
            if lifetime.canPresent(reader) {
            // TRECAP-1: the bar already says 月度回顾; no cover header repeating it.
            Section {
                HStack {
                    // TRECAP-4: MP 88rpx round month buttons → a 44 pt circle hit target.
                    Button { lifetime.run(reader) { await $0.shiftMonth(by: -1) } } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            .background(Circle().fill(CYColor.bgRaised)).contentShape(Circle())
                    }
                        .buttonStyle(.borderless).disabled(!model.canGoPrevious)
                        .accessibilityLabel(Text("roam.tools.recap.previous"))
                        .accessibilityIdentifier("roam.tools.recap.previous")
                    Spacer()
                    Text(monthDate, format: .dateTime.year().month(.wide)).cyText(.cardTitle)
                        .accessibilityIdentifier("roam.tools.recap.month")
                    Spacer()
                    // TRECAP-4: MP 88rpx round month buttons → a 44 pt circle hit target.
                    Button { lifetime.run(reader) { await $0.shiftMonth(by: 1) } } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                            .background(Circle().fill(CYColor.bgRaised)).contentShape(Circle())
                    }
                        .buttonStyle(.borderless).disabled(!model.canGoNext)
                        .accessibilityLabel(Text("roam.tools.recap.next"))
                        .accessibilityIdentifier("roam.tools.recap.next")
                }
            }
            if let reader, reader.isOfflineExample { Section { RoamExperienceNotice(offline: true) } }
            if let error {
                Section { RoamExperienceIssue(error: error) { lifetime.run(reader) { await $0.retry() } } }
                    .accessibilityIdentifier("roam.tools.recap.error")
            }
            if (loading || !lifetime.ready) && page == nil { Section { ProgressView("roam.tools.recap.loading") } }
            // TRECAP-2: an all-zero month shows no share hero (MP R11 p1 F-5).
            if let page, page.counts.routes + page.counts.places + page.counts.stamps > 0 {
                Section {
                    RoamRecapShareCard(month: monthDate, routes: page.counts.routes, places: page.counts.places, stamps: page.counts.stamps)
                        .listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.lg, bottom: 0, trailing: CYSpacing.lg)).listRowBackground(Color.clear)
                }
            }
            Section {
                Picker("roam.tools.recap.kind", selection: Binding(get: { model.kind }, set: { value in lifetime.run(reader) { await $0.select(kind: value) } })) {
                    ForEach(RoamRecapKind.allCases) { value in Text(kindKey(value)).tag(value) }
                }.cyAdaptiveSegmented().disabled(loading)
                    .accessibilityIdentifier("roam.tools.recap.kindPicker")
            }
            if let page, !page.weeks.isEmpty {
                Section(header: Text(weeklyKey(kind)).textCase(nil)) {
                    RoamRecapWeekChart(weeks: page.weeks, picked: $pickedWeek)
                }
            }
            if let page {
                if page.items.isEmpty && !loading && error == nil {
                    Section { ContentUnavailableView("roam.tools.recap.empty", systemImage: "chart.bar") }
                        .accessibilityIdentifier("roam.tools.recap.empty")
                } else {
                    Section {
                        ForEach(page.items) { item in
                            Button {
                                guard lifetime.canPresent(reader), lifetime.ready else { return }
                                _ = model.open(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: item.title)
                                    (Text(verbatim: item.dateText + " · ") + Text(kindKey(kind))).cyText(.meta).foregroundStyle(.secondary)
                                }
                            }.accessibilityElement(children: .combine)
                                .accessibilityIdentifier("roam.tools.recap.row")
                        }
                    }
                }
                if page.hasMore, !loading {
                    Button("roam.tools.recap.nextPage") { lifetime.run(reader) { await $0.nextPage() } }
                        .accessibilityLabel(Text("roam.tools.recap.nextPage.a11y"))
                        .accessibilityIdentifier("roam.tools.recap.more")
                }
            }
            }
        }.cyGroupedSurface()
        .disabled(!lifetime.canPresent(reader))
        .privacySensitive()
        .background(LifetimeAttachment(lifetime: lifetime).frame(width: 0, height: 0))
        .cySheet(item: detailBinding(model.presentation)) { presentation in Group {
            RoamMonthlyRecapDetailView(model: model, presentation: presentation, routeDestination: routeDestination,
                routeOpened: Binding(get: { openedRouteDetail == presentation.id },
                                     set: { openedRouteDetail = $0 ? presentation.id : nil }))
        }.cySheet(detents: [.large]) }
        .onAppear { lifetime.appear(reader, foreground: scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { lifetime.resume(reader, foreground: true) }
            else { lifetime.suspend() }
        }
        .onChange(of: (reader as? RoamPassportToolsSessionReader)?.readScope) { _, _ in lifetime.bind(reader); lifetime.resume(reader, foreground: scenePhase == .active) }
        .onChange(of: readerID) { _, _ in lifetime.bind(reader); lifetime.resume(reader, foreground: scenePhase == .active) }
        .onChange(of: model.month) { _, _ in pickedWeek = nil }
        .onChange(of: model.kind) { _, _ in pickedWeek = nil }
        .onChange(of: reader?.identity) { _, _ in lifetime.bind(reader); lifetime.resume(reader, foreground: scenePhase == .active) }
        .onChange(of: reader?.isConfigured) { _, _ in lifetime.accessChanged(reader, foreground: scenePhase == .active) }
        .refreshable { pickedWeek = nil; await lifetime.perform(reader) { await $0.refresh() } }
        .onDisappear { lifetime.disappear() }
        .background { RoamHostedAccessibilityGroup(items: recapAccessibilityItems) }
        .accessibilityIdentifier("roam.tools.recap.screen")
    }
    private var recapAccessibilityItems: [RoamHostedAccessibilityItem] {
        guard lifetime.canPresent(reader) else { return [] }
        var items: [RoamHostedAccessibilityItem] = []
        if error != nil {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.recap.error"))
        }
        if let page {
            if page.items.isEmpty && !loading && error == nil {
                items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.recap.empty"))
            } else if let first = page.items.first {
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.tools.recap.row",
                        action: {
                            guard lifetime.canPresent(reader), lifetime.ready else { return }
                            _ = model.open(first)
                        }
                    )
                )
            }
            if page.hasMore, !loading {
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.tools.recap.more",
                        action: { lifetime.run(reader) { await $0.nextPage() } }
                    )
                )
            }
        }
        if let presentation = model.presentation, model.isCurrent(presentation),
           presentation.topicID != nil, routeDestination != nil {
            // Without an action this probe shadowed the detail's real route link and could never activate it.
            items.append(RoamHostedAccessibilityItem(identifier: "roam.tools.recap.detail.openRoute", action: {
                guard scenePhase == .active, model.isCurrent(presentation) else { return }
                openedRouteDetail = presentation.id
            }))
        }
        return items
    }
    private func detailBinding(_ lease: RoamMonthlyRecapPresentation?) -> Binding<RoamMonthlyRecapPresentation?> {
        Binding(get: {
            lease.flatMap { model.isCurrent($0) ? $0 : nil }
        }, set: { value in
            guard value == nil, let lease else { return }
            lifetime.returnFrom(lease, reader: reader)
        })
    }
}

private struct RoamRecapWeekChart: View {
    let weeks: [RoamRecapWeek]
    @Binding var picked: Int?
    /// The 110pt plot stays put. The chart's minimum height scales with the caption instead of locking at 170.
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 170
    /// Categorical x value for a week (Swift Charts selection works on the plotted value).
    private static func key(_ index: Int) -> String { String(index) }
    /// Plain-String series names (not catalog keys; the axis and marks carry the localized text).
    private static let xSeries: String = "week", ySeries: String = "count"
    private var selection: Binding<String?> {
        Binding(get: { picked.map(Self.key) },
                set: { value in if let value, let index = Int(value) { picked = index } })
    }
    var body: some View {
        // N-TOOLS (r10): Swift Charts BarMark instead of hand-drawn RoundedRectangle bars
        // (MP subpackageTools monthly-recap week bars; TRECAP-6). Tap selects a week like the MP `pickWeek`.
        Chart(weeks) { week in
            BarMark(x: .value(Self.xSeries, Self.key(week.index)), y: .value(Self.ySeries, week.count), width: .fixed(28))
                .foregroundStyle(week.isMax ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.4)))
                .annotation(position: .top) {
                    Text(week.count, format: .number).cyText(.meta, weight: .bold)
                        .opacity(week.isMax || picked == week.index ? 1 : 0)
                }
                .accessibilityLabel(Text("roam.tools.recap.weekCount \(week.index) \(week.count)"))
        }
        .chartYAxis(.hidden)
        .chartXAxis { weekAxis }
        .chartXSelection(value: selection)
        .frame(minHeight: chartHeight)
        // TRECAP-6: one summary of every week first (MP `aria-label`).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: weeks.map { appLocalized("roam.tools.recap.weekCount \($0.index) \($0.count)", locale: .current) }
            .joined(separator: "，")))
        .accessibilityIdentifier("roam.tools.recap.weeks")
    }
    private var weekAxis: some AxisContent {
        AxisMarks { value in
            AxisValueLabel {
                Text("roam.tools.recap.week \(Int(value.as(String.self) ?? "") ?? 0)")
            }
        }
    }
}

/// Share-card stat summary (Spotify Wrapped / Duolingo year-in-review pattern): generated art, month, one big number, two tiles, one Share capsule.
/// Counts come from the recap page; nothing here is invented. The shared image is the same card rendered at 3x.
struct RoamRecapShareCard: View {
    let month: Date
    let routes: Int
    let places: Int
    let stamps: Int
    @Environment(\.displayScale) private var scale
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private var card: some View { RoamRecapShareFace(month: month, routes: routes, places: places, stamps: stamps) }
    var body: some View {
        VStack(spacing: CYSpacing.md) {
            card
            ShareLink(item: renderedImage(), preview: SharePreview(Text("roam.tools.recap"), image: renderedImage())) {
                // TRECAP-5: catalog key, not inline copy.
                Label { Text("roam.tools.recap.shareCard") } icon: { Image(systemName: "square.and.arrow.up") }
                    .cyText(.body, weight: .semibold).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.cySecondary)
            .accessibilityIdentifier("roam.tools.recap.share")
        }
    }
    @MainActor private func renderedImage() -> (Image) {
        let renderer = ImageRenderer(content: card.frame(width: 340).environment(\.locale, locale).environment(\.colorScheme, .dark))
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:)) ?? roamRecapPhotoFallback()
    }
}

struct RoamRecapShareFace: View {
    let month: Date
    let routes: Int
    let places: Int
    let stamps: Int
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(month, format: .dateTime.year().month(.wide)).cyText(.meta, weight: .semibold).foregroundStyle(.white.opacity(0.85)).textCase(.uppercase)
            Text(routes, format: .number).cyText(.data2XL).foregroundStyle(.white)
                .cyWrapText()
            Text("roam.tools.recap.routesDone").cyText(.bodyMedium).foregroundStyle(.white.opacity(0.9))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CYSpacing.sm) { tiles }
                VStack(spacing: CYSpacing.sm) { tiles }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.xl)
        .background {
            ZStack {
                CYCoverArt(seed: "recap", symbol: "figure.walk", showsDebugLabel: true)
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            }.clipShape(RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.tools.recap.routes")
    }
    @ViewBuilder private var tiles: some View {
        tile(places, "roam.tools.recap.kind.places", "mappin.and.ellipse").accessibilityIdentifier("roam.tools.recap.places")
        tile(stamps, "roam.tools.recap.kind.stamps", "seal.fill").accessibilityIdentifier("roam.tools.recap.stamps")
    }
    private func tile(_ n: Int, _ key: String, _ symbol: String) -> some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(.white).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(n, format: .number).cyText(.dataXL).monospacedDigit().foregroundStyle(.white)
                Text(LocalizedStringKey(key)).cyText(.caption).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
}

/// ShareLink item fallback. Kept outside a `View` so the symbol is a value, not a focusable element.
private func roamRecapPhotoFallback() -> Image {
    Image(systemName: "photo")
}
