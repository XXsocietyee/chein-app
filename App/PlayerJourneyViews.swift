import SwiftUI

enum PlayerJourneyRoute: Hashable {
    case play(ParticipationPlayEntry), history(PlaySessionScope), memberTemplate(MemberPlayTemplateID), verification, support, ticketWallet
    /// MP mycanyu「查看报名凭证」→ `signup/index?focusId=` (PLY-22-1).
    case ticket(registrationID: Int)
    /// MP mycanyuinfo「我的角色卡」→ `character/index?topicId=` (PLY-23-2). Activity id 0 / nil is a topic registration.
    case characterCard(topicID: Int, activityID: Int?)
    /// MP mycanyuinfo「自由探索权益」→ `free-explore/index?registrationId=` (flows-g1 member, PLY-23-3): that order's
    /// detail, which hosts the bundle read.
    case freeExploreBundle(registrationID: Int)
}

/// PLY-23-3: whether the 自由探索权益 entry may show. MP gates it on `features.freeExploreBundle`; the app gates it on
/// the session's bundle read provider (nil while the bundle read is not approved). Default off.
private struct ParticipationBundleEntryEnabledKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var participationBundleEntryEnabled: Bool {
        get { self[ParticipationBundleEntryEnabledKey.self] }
        set { self[ParticipationBundleEntryEnabledKey.self] = newValue }
    }
}

@MainActor struct PlayerJourneyAccountLinks: View {
    var body: some View {
        Section("playerJourney.library") {
            NavigationLink { SessionPlayerJourneyView(destination: .participations) } label: {
                Label("playerJourney.participations", systemImage: "ticket")
            }.accessibilityIdentifier("playerJourney.open.participations")
            NavigationLink { SessionPlayerJourneyView(destination: .completed) } label: {
                Label("playerJourney.completed", systemImage: "figure.walk.circle")
            }.accessibilityIdentifier("playerJourney.open.completed")
        }
    }
}
@MainActor struct SessionPlayerJourneyView: View {
    enum Destination { case participations, completed }
    let destination: Destination
    @EnvironmentObject private var session: AppSession
    @State private var route: PlayerJourneyRoute?
    @State private var login = false
    var body: some View {
        Group {
            switch destination {
            case .participations:
                ParticipationHistoryView(reader: session.playerJourneyReader, lifecycle: session.orderLifecycleCoordinator,
                    open: { route = $0 }, signIn: { login = true })
            case .completed:
                CompletedPlayHistoryView(reader: session.playerJourneyReader, open: { route = .history($0) }, signIn: { login = true })
            }
        }.id(session.sessionRevision).privacySensitive()
        .environment(\.participationBundleEntryEnabled, session.freeExploreBundleReadProvider != nil)
        .navigationDestination(item: $route) { route in PlayerJourneyRouteDestination(route: route) }
        .sheet(isPresented: $login) { Group { LoginView(intent: .player) }.cySheet(detents: [.large]) }
        .modifier(MerchantVerificationPopupCompanionModifier(flow: session.nativeVerificationFlow))
        .onChange(of: session.sessionRevision) { _, _ in route = nil; login = false }
    }
}

/// MP deep link `subpackageMember/mycanyuinfo/mycanyuinfo?id=` (PLY-23-1): the participation detail as a pushed page,
/// with the same routes as the 我的参与 sheet.
@MainActor struct SessionParticipationDetailHost: View {
    let id: Int
    @EnvironmentObject private var session: AppSession
    @State private var route: PlayerJourneyRoute?
    var body: some View {
        ParticipationDetailView(id: id, reader: session.playerJourneyReader, lifecycle: session.orderLifecycleCoordinator,
                                open: { route = $0 })
            .environment(\.participationBundleEntryEnabled, session.freeExploreBundleReadProvider != nil)
            .id(session.sessionRevision).privacySensitive()
            .cyPushedChrome(domain: .player)
            .navigationDestination(item: $route) { route in PlayerJourneyRouteDestination(route: route) }
            .modifier(MerchantVerificationPopupCompanionModifier(flow: session.nativeVerificationFlow))
            .onChange(of: session.sessionRevision) { _, _ in route = nil }
    }
}

/// One destination table for every participation route (list sheet, deep-linked detail).
@MainActor struct PlayerJourneyRouteDestination: View {
    let route: PlayerJourneyRoute
    @EnvironmentObject private var session: AppSession
    var body: some View {
            switch route {
            case .play(let entry):
                SessionPlayRuntimeView(session: session, destination: .journey(entry.scope))
                    .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                TicketWalletDetailView(id: entry.registrationID, reader: session.ticketWalletReader,
                                    lifecycleCoordinator: session.orderLifecycleCoordinator)
                                    .environment(\.ticketWalletPlayProvider, nil)
                                    .id(session.ticketWalletReader.scope)
                            } label: { Label("ticketWallet.detail", systemImage: "ticket") }
                            .accessibilityIdentifier("playerJourney.play.ticket")
                        }
                    }
            case .support: ParticipationSupportView()
            // Source mycanyuinfo 开始玩 without topic/activity ids falls back to the ticket wallet (signup).
            case .ticketWallet:
                SessionTicketWalletHost(isPushed: true)
            case .verification: SessionNativeVerificationView()
            case .memberTemplate(let id): SessionMemberTemplateDetailView(id: id)
            case .history(let scope):
                switch scope {
                case .topic(let id): SessionTopicDetailView(id: id, session: session)
                case .activity(let id): ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
                }
            case .ticket(let registrationID):
                SessionTicketWalletHost(isPushed: true, focusRegistrationID: registrationID)
            case .freeExploreBundle(let registrationID):
                // Same host as the `orderinfo?id=` deep link, so the order's bundle read provider is in the environment.
                SessionOwnedOrderDetailView(session: session, id: registrationID)
            case .characterCard(let topicID, let activityID):
                let scoped = (activityID ?? 0) > 0 ? activityID : nil
                if let card = session.characterCardReadback(topicID: topicID, activityID: scoped,
                                                            scope: scoped.map { PlaySessionScope.activity($0) } ?? PlaySessionScope.topic(topicID)) {
                    CharacterCardReadbackView(session: session, model: card)
                } else {
                    CYEmptyState(systemImage: "person.text.rectangle", "characterCard.unavailable", messageIdentifier: "characterCard.unavailable")
                        .cyPageTitle("characterCard.title")
                }
            }
    }
}

/// Rows survive ordinary refresh failure; stale authentication never preserves private data.
@MainActor struct ParticipationHistoryView: View {
    let reader: any PlayerJourneyReading
    let lifecycle: OrderLifecycleCoordinator
    let open: (PlayerJourneyRoute) -> Void
    let signIn: () -> Void
    @State private var rows: [ParticipationRecord]?
    @State private var rowsScope: UUID?
    @State private var filter: ParticipationFilter = .all
    private struct Selection: Identifiable {
        let record: ParticipationRecord
        let scope: UUID
        var id: Int { record.id }
    }
    @State private var selected: Selection?
    private struct PendingRoute { let target: PlayerJourneyRoute; let scope: UUID }
    @State private var nextRoute: PendingRoute?
    @State private var returnFocusID: Int?
    @AccessibilityFocusState private var focusedParticipationID: Int?
    @State private var loading = false
    @State private var issue: ParticipationLoadIssue?
    @State private var generation = UUID()
    /// R7-MEM-22-1: MP mycanyu onShow reloads after a pushed play or wallet route; that reload keeps rows and shows no pill.
    @State private var hasAppeared = false
    @State private var quietReload = false
    @Environment(\.participationBundleEntryEnabled) private var bundleEntryEnabled
    var body: some View {
        List {
            Section {
                // Source mycanyu uses fill tabs over one client-side read.
                Picker("playerJourney.filter", selection: $filter) {
                    ForEach(ParticipationFilter.allCases) { value in Text(LocalizedStringKey("playerJourney.filter." + value.rawValue)).tag(value) }
                }.pickerStyle(.segmented).accessibilityIdentifier("playerJourney.filter")
            }
            if !reader.isAuthenticated { PlayerJourneyLogin(key: "playerJourney.parity.login", signIn: signIn) }
            else if loading && (rows == nil || rowsScope != reader.scope) {
                // PLY-22-4: first load shows skeleton rows (MP cy-skeleton), not a spinner.
                CYSkeleton().listRowBackground(Color.clear)
                    .accessibilityLabel(Text("playerJourney.parity.loading"))
                    .accessibilityIdentifier("playerJourney.loading")
            }
            else if let rows, rowsScope == reader.scope {
                let visible = rows.filter { filter.matches($0) }
                if loading && !quietReload {
                    Text("playerJourney.parity.refreshing").cyText(.bodyCompact).foregroundStyle(.secondary)
                        .accessibilityIdentifier("playerJourney.refreshing")
                }
                if visible.isEmpty {
                    CYEmptyState(systemImage: "tray", LocalizedStringKey(filter.emptyTitleKey), detail: LocalizedStringKey(filter.emptyDetailKey), messageIdentifier: "playerJourney.empty", kind: .orders)
                        .listRowBackground(Color.clear)
                }
                ForEach(visible) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Button { returnFocusID = row.id; selected = Selection(record: row, scope: reader.scope) } label: { ParticipationRow(record: row) }
                            .buttonStyle(.plain).accessibilityIdentifier("playerJourney.participation.\(row.id)")
                            .accessibilityFocused($focusedParticipationID, equals: row.id)
                        // MP mycanyu「查看报名凭证」→ 票夹 focused on this registration (PLY-22-1).
                        Button { open(.ticket(registrationID: row.id)) } label: {
                            Text("playerJourney.viewVoucher").cyText(.label, weight: .semibold)
                                .padding(.horizontal, CYSpacing.md)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                                .background(CYColor.bgRaised, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("playerJourney.viewVoucher.\(row.id)")
                    }
                }
            } else if let issue { ParticipationIssueView(issue: issue, retry: { Task { await load() } }) }
        }.cyGroupedSurface()
        .cyDomainScreen(.player)
        .cyPageTitle("playerJourney.participations")
        // A re-run of this task on return (same scope, rows loaded) leaves the quiet onAppear reload to keep the rows.
        .task(id: reader.scope) {
            guard rows == nil || rowsScope != reader.scope else { return }
            resetPresentation(); rows = nil; await load()
        }
        .onChange(of: reader.scope) { _, _ in resetPresentation() }
        .refreshable { await load() }
        .onAppear {
            defer { hasAppeared = true }
            guard hasAppeared, rows != nil, rowsScope == reader.scope, selected == nil, !loading else { return }
            Task { quietReload = true; await load(); quietReload = false }
        }
        .onDisappear { generation = UUID() }
        .sheet(item: $selected, onDismiss: {
            let pending = nextRoute; nextRoute = nil
            if let pending {
                returnFocusID = nil
                guard pending.scope == reader.scope, reader.isAuthenticated else { return }
                open(pending.target)
            } else {
                focusedParticipationID = returnFocusID
                returnFocusID = nil
            }
        }) { selected in
            NavigationStack {
                ParticipationDetailView(id: selected.id, reader: reader, lifecycle: lifecycle,
                    open: { target in
                        guard selected.scope == reader.scope, reader.isAuthenticated else { resetPresentation(); return }
                        nextRoute = PendingRoute(target: target, scope: selected.scope); self.selected = nil
                    })
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { self.selected = nil }.accessibilityIdentifier("playerJourney.detail.close") } }
            }
            .environment(\.participationBundleEntryEnabled, bundleEntryEnabled)
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }
    private func resetPresentation() {
        nextRoute = nil; returnFocusID = nil; focusedParticipationID = nil; selected = nil
    }
    private func load() async {
        let request = UUID(); generation = request; let scope = reader.scope
        loading = true; issue = nil
        defer { if generation == request { loading = false } }
        do {
            let values = try await reader.participations()
            guard generation == request, scope == reader.scope, !Task.isCancelled else { return }
            rows = values; rowsScope = scope
        } catch {
            guard generation == request, scope == reader.scope, !Task.isCancelled else { return }
            if error as? APIError == .unauthorized { rows = nil; resetPresentation() }
            // Source mycanyu keeps an existing snapshot silently when a refresh fails.
            issue = rows == nil ? ParticipationLoadIssue(error, detail: false) : nil
        }
    }
}
private struct ParticipationRow: View {
    let record: ParticipationRecord
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        // Source mycanyu card: cover on the left, then state badge, name, "MM.DD – MM.DD" and "type · address" on the right.
        // Accessibility sizes stack the cover above the text so the name never squeezes.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md))
                                                  : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.md))
        layout {
            // Source cover: imgUrl || imgArr, else the default route cover; iOS shows a neutral placeholder.
            Group {
                if let url = QuestifyCardArtwork.safeURL(record.cover) {
                    QuestifyCardArtwork(url: url, height: 136).accessibilityIdentifier("playerJourney.row.cover")
                } else {
                    ParticipationCoverPlaceholder()
                }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 150)
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                ParticipationStatusBadge(status: record.participationStatus(), detail: false)
                Group {
                    if let name = record.name { Text(verbatim: name) } else { Text("playerJourney.sourceUntitled") }
                }
                .cyText(.cardTitle).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Label {
                    if let range = ParticipationDateText.range(start: record.order.ownerStartDate, end: record.order.ownerEndDate) { Text(verbatim: range).monospacedDigit() }
                    else { Text("playerJourney.timeTBD") }
                } icon: { ParticipationMPGlyph(image: MPAsset.BrandLogo.dCyIcon) }
                .cyText(.meta).foregroundStyle(.secondary)
                Label {
                    Text(LocalizedStringKey(record.modeKey))
                        + Text(verbatim: " · ")
                        + (record.address.map { Text(verbatim: $0) } ?? Text("playerJourney.placeTBD"))
                } icon: { ParticipationMPGlyph(image: MPAsset.BrandLogo.dCyIcon2) }
                .cyText(.meta).foregroundStyle(.secondary)
                // MP verification badge 已核销 / 未核销 / — (mycanyu.js:113-114, PLY-22-2).
                CYStatusChip(LocalizedStringKey(record.verificationKey))
                    .accessibilityIdentifier("playerJourney.row.verification")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
private extension ParticipationRecord {
    var verificationKey: String {
        switch order.verificationStatus {
        case 1?: return "playerJourney.verification.done"
        case 0?: return "playerJourney.verification.pending"
        default: return "playerJourney.verification.unknown"
        }
    }
}
/// Never invented artwork: the MP default cover (`/images/route_city_cover.png`, mycanyu.wxml:22) when the source
/// cover is absent or not https.
private struct ParticipationCoverPlaceholder: View {
    var body: some View {
        MPAsset.BannerCover.routeCityCover.resizable().scaledToFill()
            .frame(height: 136).frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true).accessibilityIdentifier("playerJourney.row.coverPlaceholder")
    }
}
/// Internal so the `mycanyuinfo?id=` deep link can push it through `SessionParticipationDetailHost`.
@MainActor struct ParticipationDetailView: View {
    let id: Int
    let reader: any PlayerJourneyReading
    let lifecycle: OrderLifecycleCoordinator
    let open: (PlayerJourneyRoute) -> Void
    @Environment(\.participationBundleEntryEnabled) private var bundleEntryEnabled
    @State private var detail: ParticipationDetail?
    @State private var issue: ParticipationLoadIssue?
    @State private var loading = false
    @State private var generation = UUID()
    var body: some View {
        List {
            if loading { ProgressView("playerJourney.parity.detailLoading") }
            if let issue { ParticipationIssueView(issue: issue, retry: { Task { await load() } }) }
            if let detail {
                // PLY-23-6: MP mycanyuinfo `picUrl` cover (cmsTopic/cmsActivity imgUrl || imgArr), https only, none when absent.
                ParticipationDetailGapSections(coverURL: QuestifyCardArtwork.safeURL(detail.record.cover)?.absoluteString)
                ParticipationDetailHeader(detail: detail)
                // PLY-23-3 (flows-g1 member): 自由探索权益 under the info card (MP wxml:64-66, `_bundleEntry`: ownerType 1 +
                // cmsTopic + purchaseKind 3 or productType 2), behind the bundle switch.
                ParticipationDetailGapSections(
                    isFreeExplore: bundleEntryEnabled && detail.record.isFreeExplore && detail.record.order.id > 0,
                    onOpenFreeExploreBundle: { open(.freeExploreBundle(registrationID: detail.record.order.id)) })
                ProfileParticipationScheduleSection(start: detail.record.order.ownerStartDate,
                    end: detail.record.order.ownerEndDate)
                if detail.nodeName != nil || detail.cooperateDate != nil {
                    Section {
                        if let node = detail.nodeName {
                            LabeledContent { Text(verbatim: node) } label: {
                                Label { Text("playerJourney.parity.finalNode") } icon: { ParticipationMPGlyph(image: MPAsset.FeatureIcon.dCyinfo1) }
                            }
                        }
                        if let date = detail.cooperateDate {
                            LabeledContent { Text(verbatim: date) } label: {
                                Label { Text("playerJourney.cooperateDate") } icon: { ParticipationMPGlyph(image: MPAsset.FeatureIcon.dCyinfo2) }
                            }
                        }
                    }
                }
                // Source result cards sit above the verification stats.
                OrientScoreParticipationEntry(detail: detail)
                // MP「我的角色卡」card → character/index?topicId (PLY-23-2). The card page reads and gates itself.
                if let topicID = detail.topicID, topicID > 0, (detail.record.order.memberID ?? 0) > 0 {
                    Section {
                        Button { open(.characterCard(topicID: topicID, activityID: detail.activityID)) } label: {
                            Label("characterCard.title", systemImage: "person.text.rectangle")
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityIdentifier("playerJourney.characterCard.entry")
                    }
                }
                if detail.showOrderStats {
                    Section("playerJourney.verification") {
                        // Source shows two cells in 人 and 0 for unknown statistics.
                        LabeledContent("playerJourney.pending") { Text("playerJourney.parity.people \(detail.pendingText)").monospacedDigit() }
                            .accessibilityIdentifier("playerJourney.stats.pending")
                        LabeledContent("playerJourney.parity.verifiedOfTotal") {
                            Text("playerJourney.parity.peopleRatio \(detail.verifiedText) \(detail.totalText)").monospacedDigit()
                        }.accessibilityIdentifier("playerJourney.stats.verified")
                        NavigationLink { SessionNativeVerificationView() } label: {
                            Label("verification.title", systemImage: "qrcode.viewfinder")
                        }.accessibilityIdentifier("playerJourney.verification")
                    }
                }
                if detail.rules != nil {
                    // Source mycanyuinfo renders its fixed exit/pause text whenever ruleInstructions is present.
                    Section("playerJourney.rules") {
                        // MP mycanyuinfo wxml:110 puts the shipped `d_cyinfo4.png` figure beside the fixed rule text.
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            MPAsset.FeatureIcon.dCyinfo4.resizable().scaledToFit().frame(width: 36, height: 36).accessibilityHidden(true)
                            Text("playerJourney.parity.fixedRules").fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("playerJourney.rules")
                        }
                    }
                }
                if let rawID = detail.templateID, let id = MemberPlayTemplateID(rawValue: rawID) {
                    Section("playerJourney.template") {
                        if let templateName = detail.templateName { Text(verbatim: templateName) }
                        NavigationLink { SessionMemberTemplateDetailView(id: id) } label: {
                            Label("memberTemplate.title", systemImage: "doc.text.magnifyingglass")
                        }.accessibilityIdentifier("playerJourney.template")
                    }
                }
                Section {
                    NavigationLink { OrderLifecycleView(id: id, coordinator: lifecycle).id(lifecycle.scope) } label: {
                        Label(detail.sourceCanCancel() ? "playerJourney.cancellation" : "playerJourney.orderProgress", systemImage: "list.bullet.rectangle")
                    }.accessibilityIdentifier("playerJourney.orderLifecycle")
                    if detail.needsModification {
                        // Player registration IDs cannot address the separate merchant-registration table.
                        Text("playerJourney.modifyNeedsReview").foregroundStyle(.secondary)
                    }
                    if detail.showsContactService() {
                        NavigationLink { ParticipationSupportView() } label: {
                            Label("participationSupport.title", systemImage: "message")
                        }.accessibilityIdentifier("playerJourney.support")
                    }
                }
            }
        }.cyGroupedSurface().cyPageTitle("playerJourney.detail")
        // Source mycanyuinfo: 开始游戏 is the one filled action, pinned to the bottom of the page.
        .safeAreaInset(edge: .bottom) {
            if let detail {
                Group {
                    if let target = detail.record.playEntry {
                        Button("playerJourney.start", systemImage: "play.fill") { open(.play(target)) }
                            .accessibilityIdentifier("playerJourney.start")
                    } else {
                        Button("playerJourney.start", systemImage: "ticket") { open(.ticketWallet) }
                            .accessibilityIdentifier("playerJourney.start.ticketWallet")
                    }
                }
                .buttonStyle(.cyPrimary).controlSize(.large).frame(maxWidth: .infinity)
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.sm)
                .background(.bar)
            }
        }
        .task(id: reader.scope) { detail = nil; await load() }
        .refreshable { await load() }
        .onDisappear { generation = UUID() }
    }
    private func load() async {
        let request = UUID(); generation = request; let scope = reader.scope
        loading = true; issue = nil
        defer { if generation == request { loading = false } }
        do {
            let value = try await reader.detail(id: id)
            guard generation == request, scope == reader.scope, !Task.isCancelled else { return }
            detail = value
        } catch {
            guard generation == request, scope == reader.scope, !Task.isCancelled else { return }
            detail = nil; issue = ParticipationLoadIssue(error, detail: true)
        }
    }
}
@MainActor struct CompletedPlayHistoryView: View {
    let reader: any PlayerJourneyReading
    let open: (PlaySessionScope) -> Void
    let signIn: () -> Void
    @State private var rows: [CompletedPlayRecord]?
    @State private var issue: String?
    @State private var loading = false
    @State private var generation = UUID()
    var body: some View {
        List {
            if !reader.isAuthenticated { PlayerJourneyLogin(signIn: signIn) }
            else if loading && rows == nil { ProgressView("playerJourney.loading") }
            else if let rows {
                if rows.isEmpty { CYEmptyState(systemImage: "figure.walk", "playerJourney.completed.empty") }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Button { if let destination = row.destination { open(destination) } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if let name = row.name { Text(verbatim: name).cyText(.cardTitle) } else { Text("playerJourney.untitled") }
                            if let total = row.total, total > 0 {
                                let done = row.doneCount
                                if row.completed == true || (done.map { $0 >= total } ?? false) { Label("playerJourney.finished", systemImage: "checkmark.circle") }
                                else if done == 0 { Text("playerJourney.notStarted") }
                                Text(verbatim: "\(done.map(String.init) ?? "—") / \(total)").monospacedDigit()
                            } else if row.total == nil {
                                Text(verbatim: "—").monospacedDigit().accessibilityIdentifier("playerJourney.completed.unknown")
                            } else {
                                Text(verbatim: "0").monospacedDigit()
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                    }.buttonStyle(.plain).disabled(row.destination == nil)
                }
                if let issue { Text(LocalizedStringKey(issue)).cyText(.bodyCompact).foregroundStyle(.secondary) }
            } else if let issue { PlayerJourneyIssue(key: issue, retry: { Task { await load() } }) }
        }.cyGroupedSurface().navigationTitle("playerJourney.completed").navigationBarTitleDisplayMode(.inline)
        .task(id: reader.scope) { rows = nil; await load() }.refreshable { await load() }
        .onDisappear { generation = UUID() }
    }
    private func load() async {
        let request = UUID(); generation = request; let scope = reader.scope
        loading = true; issue = nil
        defer { if generation == request { loading = false } }
        do {
            let values = try await reader.completed()
            guard request == generation, scope == reader.scope, !Task.isCancelled else { return }
            rows = values
        } catch {
            guard request == generation, scope == reader.scope, !Task.isCancelled else { return }
            if error as? APIError == .unauthorized { rows = nil }
            issue = rows == nil ? PlayerJourneyIssue.key(error) : "playerJourney.refreshFailed"
        }
    }
}
private struct PlayerJourneyCount: View {
    let label: LocalizedStringKey
    let value: Int?
    var body: some View { LabeledContent(label) { if let value { Text(verbatim: String(value)) } else { Text("playerJourney.unknown") } } }
}
private struct PlayerJourneyLogin: View {
    var key: LocalizedStringKey = "playerJourney.login"
    let signIn: () -> Void
    var body: some View { ContentUnavailableView { Label(key, systemImage: "lock") } actions: { Button("auth.signIn", action: signIn) } }
}
private struct PlayerJourneyIssue: View {
    let key: String
    let retry: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 12) { Text(LocalizedStringKey(key)); Button("action.retry", action: retry) } }
    static func key(_ error: Error) -> String {
        if error as? APIError == .unauthorized { return "playerJourney.login" }
        if error as? APIError == .notConfigured { return "playerJourney.notConfigured" }
        return "playerJourney.failed"
    }
}

/// MP mycanyu wxml:34/37 and participation-detail wxml:45/56 draw the shipped row icons
/// (`d_cyIcon` date, `d_cyIcon2` mode · place, `d_cyinfo1` node, `d_cyinfo2` reception time) as images.
struct ParticipationMPGlyph: View {
    let image: Image
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 14
    var body: some View {
        image.resizable().scaledToFit().frame(width: side, height: side).accessibilityHidden(true)
    }
}
