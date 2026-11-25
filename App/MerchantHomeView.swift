import SwiftUI
import UIKit

/// Inject an observable session adapter; this view deliberately does not own root navigation.
@MainActor
struct MerchantHomeView<Reader: MerchantReading>: View {
    @ObservedObject var reader: Reader
    var marketingModel: MerchantMarketingCoordinator? = nil
    var marketingDestination: ((MerchantInsightDestination) -> AnyView)? = nil
    var openApplication: (() -> Void)? = nil
    /// Parity merchant/index P1: the signed-out gate's 登录 (source `index.wxml:12-14`). Nil hides the button.
    var openSignIn: (() -> Void)? = nil
    var operationsReader: (any MerchantOperationsReading)? = nil
    var operationsDestinationFactory: ((MerchantOperationsDestination, MerchantOperationsAccess) -> AnyView)? = nil
    var businessReader: (any MerchantBusinessReading)? = nil
    var businessJournal: (any MerchantBusinessIntentStore)? = nil
    var contentService: (any MerchantContentServing)? = nil
    var cooperationFlowReader: (any CoopFlowReading)? = nil
    var engagementReader: (any MerchantEngagementReading)? = nil
    var exportRecovery: (any MerchantExportRecoveryStoring)? = nil
    var showsRecordLinks = true
    var predictionReader: MerchantPredictionReader? = nil
    @Environment(\.merchantAccessObserver) private var merchantAccessObserver
    @StateObject private var access = MerchantLoadModel<MerchantAccess>()
    @StateObject private var dashboard = MerchantLoadModel<MerchantDashboard>()
    @StateObject private var todo = MerchantLoadModel<MerchantTodo>()
    @StateObject private var events = MerchantLoadModel<[MerchantEvent]>()
    @State private var childReturnRevision: UInt64 = 0
    /// True while a pushed child covers this root. SwiftUI may report the child leaving before or after the root
    /// re-appears; either way a return must cause exactly one fresh access read.
    @State private var coveredByChild = false
    /// Uptime at which the root re-appeared and its `.task` restarted. A child reported as leaving within the same
    /// pop transition is already covered by that read; any later return still refreshes.
    @State private var returnReadStartedAt: TimeInterval?

    var body: some View {
        ZStack {
            if !reader.isConfigured {
                merchantGate(systemImage: "network.slash", message: "auth.notConfigured")
            } else if !reader.isSignedIn {
                // MP index.wxml:12 cy-empty title="登录后查看经营台" cta="登录".
                merchantGate(systemImage: "person.crop.circle.badge.exclamationmark", message: "merchant.home.signIn", signIn: openSignIn)
            } else if access.loadedRevision == reader.sessionRevision, let identity = access.value {
                if identity.active {
                    MerchantWorkbench(reader: reader, access: identity, marketingModel: marketingModel, marketingDestination: marketingDestination, operationsReader: operationsReader, operationsDestinationFactory: operationsDestinationFactory, businessReader: businessReader, businessJournal: businessJournal, contentService: contentService, cooperationFlowReader: cooperationFlowReader, engagementReader: engagementReader, exportRecovery: exportRecovery, showsRecordLinks: showsRecordLinks, predictionReader: predictionReader, childReturnRevision: childReturnRevision, refreshAccess: reload, dashboard: dashboard, todo: todo, events: events, onChildReturn: { childReturned() })
                        .id("\(reader.sessionRevision):\(identity.merchantID ?? 0):\(identity.role?.rawValue ?? "")")
                } else {
                    List {
                        Section {
                            let named = identity.merchantName?.isEmpty == false
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                if let name = identity.merchantName, !name.isEmpty {
                                    Text(name)
                                        .cyText(.cardTitle)
                                        .foregroundStyle(CYColor.textPrimary)
                                }
                                Text(LocalizedStringKey(identity.application?.titleKey ?? "merchant.access.inactive"))
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textSecondary)
                                    .accessibilityIdentifier("merchant.access.inactive")
                            }
                            .padding(.vertical, CYSpacing.xs)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(named ? [.isHeader, .isStaticText] : .isStaticText)
                        }
                        Section {
                            if let openApplication {
                                Button(action: openApplication) {
                                    Text("merchant.onboarding.openApplication").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.borderedProminent)
                                .pageTemplateControl(label: Text("merchant.onboarding.openApplication"), traits: .isButton)
                                .accessibilityIdentifier("merchant.onboarding.entry")
                                Button { Task { await reload() } } label: {
                                    Text("merchant.refreshAccess").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.bordered)
                                .pageTemplateControl(label: Text("merchant.refreshAccess"), traits: .isButton)
                                .accessibilityIdentifier("merchant.access.refresh")
                            } else {
                                Button { Task { await reload() } } label: {
                                    Text("merchant.refreshAccess").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.borderedProminent)
                                .pageTemplateControl(label: Text("merchant.refreshAccess"), traits: .isButton)
                                .accessibilityIdentifier("merchant.access.refresh")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await reload() }
                }
            } else if let error = access.errorKey {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    CYHeroHeader("merchant.title")
                    // Native restyle R3: the system unavailable state, one prominent action.
                    // MP index.wxml:16 当前身份不能查看经营台 + 申请入驻; :21-24 商家工作台加载失败 + reason + 重新加载.
                    ContentUnavailableView {
                        Label(LocalizedStringKey(error == "merchant.access.denied" ? "merchant.home.denied"
                                                 : (error == "auth.expired" ? error : "merchant.home.loadFailed")),
                              systemImage: error == "merchant.access.denied" ? "lock" : "exclamationmark.triangle")
                            .accessibilityIdentifier("merchant.access.error")
                    } description: {
                        if error != "merchant.access.denied" && error != "auth.expired" { Text(LocalizedStringKey(error)) }
                    } actions: {
                        if error != "merchant.access.denied" && error != "auth.expired" {
                            Button("merchant.gate.reload") { Task { await reload() } }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("merchant.access.retry")
                        } else if error == "merchant.access.denied", let openApplication {
                            // Parity merchant/index P1: no merchant identity → 申请入驻 in place (source index.wxml:16-18).
                            Button("merchant.gate.apply", action: openApplication)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("merchant.access.apply")
                        } else if error == "auth.expired", let openSignIn {
                            Button("auth.signIn", action: openSignIn)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("merchant.access.signIn")
                        }
                    }
                }
                .padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                CYSkeleton(variant: .merchantMetric)
                    .padding(CYSpacing.pageHorizontal)
                    .accessibilityIdentifier("merchant.access.loading")
                    .accessibilityLabel(Text("merchant.checkingAccess"))
            }
        }
        .appNavigationTitle("merchant.title")
        // verify-r1 2.8 / N-07: no centred 商家工作台 above the shop name (two titles). The title stays for the back
        // button of pages pushed from here.
        .modifier(MerchantHomeHiddenNavigationTitle())
        .cyDomainPageBackground()
        .themeDomain(.merchant)
        .tint(CYDomainPalette(.merchant).brand)
        // fix/r3-merchant-coop-b: brand-center / team / city-node dead-end states reuse these CTAs.
        .environment(\.merchantOpenApplication, openApplication)
        .environment(\.merchantOpenSignIn, openSignIn)
        .task(id: [reader.sessionRevision, childReturnRevision]) { await reload() }
        .onDisappear { coveredByChild = true; returnReadStartedAt = nil }
        .onAppear { if coveredByChild { coveredByChild = false; returnReadStartedAt = ProcessInfo.processInfo.systemUptime } }
    }
    private func childReturned() {
        if coveredByChild {
            // The child left first; the root's re-appearance starts the task once with the new id.
            coveredByChild = false; childReturnRevision &+= 1
        } else if let started = returnReadStartedAt, ProcessInfo.processInfo.systemUptime - started < 1 {
            returnReadStartedAt = nil
        } else {
            childReturnRevision &+= 1
        }
    }
    private func reload() async {
        await Self.refreshWorkbenchOnChildReturn(accessModel: access, dashboard: dashboard, todo: todo, events: events,
            reader: reader, businessReader: businessReader, observer: merchantAccessObserver)
    }

    @discardableResult
    static func reloadAccess(
        into access: MerchantLoadModel<MerchantAccess>,
        reader: Reader,
        observer: MerchantAccessObservationHook
    ) async -> MerchantLoadDisposition {
        // The old grant is not usable while access is being checked again.
        let observationToken = observer.begin()
        let disposition = await access.load(reader: reader, discardOldValue: true) { try await reader.merchantAccess() }
        if disposition == .completed, !access.isLoading, let observationToken {
            observer.complete(observationToken, access.value, access.errorKey)
        }
        return disposition
    }

    @discardableResult
    static func refreshWorkbenchOnChildReturn(
        accessModel: MerchantLoadModel<MerchantAccess>,
        dashboard: MerchantLoadModel<MerchantDashboard>,
        todo: MerchantLoadModel<MerchantTodo>,
        events: MerchantLoadModel<[MerchantEvent]>,
        reader: Reader,
        businessReader: (any MerchantBusinessReading)?,
        observer: MerchantAccessObservationHook
    ) async -> MerchantLoadDisposition {
        dashboard.clear(); todo.clear(); events.clear()
        let disposition = await reloadAccess(into: accessModel, reader: reader, observer: observer)
        guard disposition == .completed,
              reader.isConfigured,
              reader.isSignedIn,
              accessModel.loadedRevision == reader.sessionRevision,
              let identity = accessModel.value,
              identity.active else {
            return disposition
        }
        let revision = reader.sessionRevision
        func current() -> Bool {
            !Task.isCancelled && reader.isConfigured && reader.isSignedIn && reader.sessionRevision == revision &&
                !accessModel.isLoading && accessModel.loadedRevision == revision && accessModel.value == identity
        }
        guard current() else { return .cancelled }
        if identity.canReadDashboard {
            await dashboard.load(reader: reader) { try await reader.merchantDashboard(access: identity) }
            guard current() else { return .cancelled }
        }
        if identity.isOwner || identity.canReadAftercare {
            await MerchantWorkbenchTodoLoader.load(into: todo, reader: reader, access: identity, businessReader: businessReader)
            guard current() else { return .cancelled }
        }
        if identity.canReadEvents {
            await events.load(reader: reader) { try await reader.merchantEvents(access: identity) }
        }
        return current() ? disposition : .cancelled
    }

    private func merchantGate(systemImage: String, message: LocalizedStringKey, signIn: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYHeroHeader("merchant.title")
            ContentUnavailableView {
                Label(message, systemImage: systemImage)
            } actions: {
                if let signIn {
                    Button("auth.signIn", action: signIn)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("merchant.gate.signIn")
                }
            }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private struct MerchantWorkbench<Reader: MerchantReading>: View {
    @Environment(\.locale) private var locale
    @Environment(\.merchantCoopCenterDestination) private var coopCenterDestination
    @ObservedObject var reader: Reader
    let access: MerchantAccess
    let marketingModel: MerchantMarketingCoordinator?
    let marketingDestination: ((MerchantInsightDestination) -> AnyView)?
    let operationsReader: (any MerchantOperationsReading)?
    let operationsDestinationFactory: ((MerchantOperationsDestination, MerchantOperationsAccess) -> AnyView)?
    let businessReader: (any MerchantBusinessReading)?
    let businessJournal: (any MerchantBusinessIntentStore)?
    let contentService: (any MerchantContentServing)?
    let cooperationFlowReader: (any CoopFlowReading)?
    let engagementReader: (any MerchantEngagementReading)?
    let exportRecovery: (any MerchantExportRecoveryStoring)?
    let showsRecordLinks: Bool
    let predictionReader: MerchantPredictionReader?
    let childReturnRevision: UInt64
    let refreshAccess: () async -> Void
    @ObservedObject var dashboard: MerchantLoadModel<MerchantDashboard>
    @ObservedObject var todo: MerchantLoadModel<MerchantTodo>
    @ObservedObject var events: MerchantLoadModel<[MerchantEvent]>
    let onChildReturn: () -> Void
    @Environment(\.merchantAuthoringDestination) private var merchantAuthoringDestination
    @Environment(\.coopFlowPreviewWrite) private var coopFlowWrite
    @Environment(\.merchantCoopInboxDestination) private var coopInboxDestination
    @Environment(\.merchantInboxSources) private var inboxSources
    @Environment(\.merchantCouponManagementDestination) private var couponManagementDestination
    @State private var operationsAccess: MerchantOperationsAccess?
    @State private var businessStatus: MerchantBusinessStatus?

    private var aftercareRoute: MerchantWorkbenchBusinessRoute? {
        guard access.canReadAftercare, let businessReader, let businessJournal else { return nil }
        return MerchantWorkbenchBusinessRoute(shortcut: .aftercare, reader: businessReader, journal: businessJournal)
    }

    /// Signed-in member id, not the merchant archive id. Coordinates stay nil:
    /// a refused location still queries candidates with topicId alone.
    private func chapterReplacementContext(access: MerchantAccess) -> MerchantChapterReplacementHostContext? {
        guard let contentService, let actor = (reader as? AppSession)?.account?.id, actor > 0 else { return nil }
        let scope: ChapterReplacementInvitationScope = (access.isOwner && access.allows(.projects)) ? .merchant : .currentMember
        return MerchantChapterReplacementHostContext(
            makeEffects: { contentService.chapterReplacementInvitationEffects(scope: scope, publisherProof: $0) },
            actorAccountID: actor, scope: scope, merchantAccess: access,
            loadPublisherProof: { topic in
                await contentService.chapterReplacementPublisherProof(topicID: topic, actorAccountID: actor, access: access)
            },
            coordinates: nil)
    }
    private func customerQueryDestination(source: any MerchantBusinessReading, journal: any MerchantBusinessIntentStore)
        -> (@MainActor (MerchantCustomerAppliedQuery) -> AnyView)? {
        guard let engagementReader, let exportRecovery else { return nil }
        let revision = reader.sessionRevision, merchant = access.merchantID
        return { selection in
            AnyView(MerchantCustomerQueryDestinationView(root: reader, source: source, engagement: engagementReader,
                journal: journal, exports: exportRecovery, selection: selection, revision: revision, merchantID: merchant))
        }
    }
    @Environment(\.nativeVerificationDestination) private var nativeVerificationDestination
    @State private var quickRoute: MerchantWorkbenchBusinessRoute?
    @State private var showsScan = false
    @State private var toastMessage: String?
    @State private var confirmsPause = false
    @State private var statusBusy = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var quickShortcuts: [MerchantWorkbenchBusinessShortcut] {
        guard let businessReader, let businessJournal else { return [] }
        return [.customers, .finance].filter {
            $0.isVisible(for: access) && MerchantWorkbenchBusinessRoute(shortcut: $0, reader: businessReader, journal: businessJournal) != nil
        }
    }
    private var showsScanAction: Bool { access.allows(.verify) && nativeVerificationDestination != nil }

    /// 品牌中心 (MerchantOperationsHomeView), shared by the header avatar and the 更多 row.
    @ViewBuilder private func operationsHome(_ operationsReader: any MerchantOperationsReading) -> some View {
        MerchantOperationsHomeView(reader: operationsReader, destinationFactory: operationsDestinationFactory)
            .environment(\.merchantPerkTemplatesDestination, cooperationFlowReader.map { flowReader in
                { AnyView(MerchantPerkTemplatesHost(reader: flowReader, executor: coopFlowWrite?.executor())) }
            })
            .environment(\.merchantReviewsDestination, businessReader.flatMap { reader in businessJournal.map { journal in
                { AnyView(MerchantBusinessPage(reader: reader, journal: journal, query: .reviews(page: 1)).cyPushedChrome(domain: .merchant)) }
            } })
            .id(operationsReader.scope)
            .onDisappear(perform: onChildReturn)
            .cyPushedChrome(domain: .merchant)
    }

    var body: some View {
        // Source pages/merchant/index order: hero (name, revenue), quick actions (scan, customers,
        // finance), due reminders, projects, then the remaining tools ("更多") and recent activity.
        ScrollViewReader { scrollProxy in
        List {
            Section {
                VStack(spacing: CYSpacing.md) {
                    let displayName = access.merchantName.flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("merchant.store", locale: locale)
                    // Figma 182:7328 · Merchant/Root Header: the shop name as the 28 Bold title, 营业中 under it.
                    MerchantRootHeader(Text(verbatim: displayName), id: "merchant.store.name") {
                        if let businessStatus {
                            let chip = CYStatusChip(
                                LocalizedStringKey(businessStatus.titleKey),
                                tone: businessStatus == .open ? .success : .neutral
                            ).singleLine()
                                .accessibilityLabel(Text(LocalizedStringKey(businessStatus.titleKey)))
                                .accessibilityValue(Text(LocalizedStringKey(businessStatus.titleKey)))
                                .accessibilityHint(Text(verbatim: displayName))
                            if canToggleStatusInPlace {
                                // Parity merchant/index P1: 营业中/已打烊 toggles in place (source index.js:168-236):
                                // closing asks once (暂停营业？), opening goes straight through; the value is read back.
                                Button {
                                    if businessStatus == .open { confirmsPause = true } else { Task { await setBusinessStatus(.open) } }
                                } label: {
                                    chip.opacity(statusBusy ? 0.5 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(statusBusy)
                                .accessibilityHint(Text(businessStatus == .open ? "merchant.status.pauseHint" : "merchant.status.openHint"))
                                .accessibilityIdentifier("merchant.store.businessStatus")
                            } else if let operationsAccess, operationsAccess.allows(.businessStatus), let factory = operationsDestinationFactory {
                                NavigationLink {
                                    factory(.businessStatus, operationsAccess)
                                        .onDisappear(perform: onChildReturn)
                                } label: {
                                    chip
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("merchant.store.businessStatus")
                            } else {
                                chip
                                    .accessibilityIdentifier("merchant.store.businessStatus")
                            }
                        }
                    } trailing: {
                        // MC7-01-5: MP header store avatar (index.wxml:62) opens 品牌中心 for roles that can write the profile.
                        if access.allows(.profileWrite), let operationsReader {
                            NavigationLink {
                                operationsHome(operationsReader)
                            } label: {
                                CYAvatarView(name: displayName, size: .md)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("merchant.operations.title"))
                            .accessibilityIdentifier("merchant.header.brandCenter")
                        }
                    }
                    if access.canReadDashboard {
                        // MP index.wxml:82-85 收入没更新成功 + 重新加载此部分.
                        MerchantSectionState(model: dashboard, retry: { Task { await loadDashboard() } },
                                             failureTitle: "merchant.home.dashboardFailed", retryTitle: "merchant.home.reloadPart") { value in
                            // HANDOFF-R1 MR-20 (owner Q-C): the hero is today — 今日核销 · 今日收入 · 待处理.
                            // The cumulative 累计收入 moved to 账本 (MerchantLedgerSettlementOverview).
                            MerchantR1TodayCard(today: .make(revenue7d: value.revenue7d, pendingOrders: value.pendingOrders))
                                .accessibilityIdentifier("merchant.dashboard.revenue")
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.xs, bottom: CYSpacing.md, trailing: CYSpacing.xs))
            }
            if showsScanAction || !quickShortcuts.isEmpty {
                Section {
                    // At accessibility sizes the four circles wrap to two columns instead of clipping.
                    (dynamicTypeSize.isAccessibilitySize ? AnyLayout(GridFlowLayout()) : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Space.s2))) {
                        if showsScanAction {
                            MerchantQuickCircleAction(title: "merchant.workbench.scan", systemImage: "qrcode.viewfinder", primary: true) { showsScan = true }
                                .accessibilityIdentifier("merchant.workbench.scan")
                        }
                        ForEach(Array(quickShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                            MerchantQuickCircleAction(title: LocalizedStringKey(shortcut.shortTitleKey), systemImage: shortcut.symbol, primary: !showsScanAction && index == 0) {
                                if let businessReader, let businessJournal {
                                    quickRoute = MerchantWorkbenchBusinessRoute(shortcut: shortcut, reader: businessReader, journal: businessJournal)
                                }
                            }
                            .accessibilityIdentifier("merchant.workbench.direct." + shortcut.rawValue)
                        }
                        // Source 更多: jumps to the remaining tools group below.
                        MerchantQuickCircleAction(title: "merchant.workbench.more", systemImage: "ellipsis") {
                            withAnimation(.easeOut(duration: 0.25)) { scrollProxy.scrollTo("merchant.workbench.moreSection", anchor: .top) }
                        }
                        .accessibilityIdentifier("merchant.workbench.more.action")
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
                .listRowBackground(Color.clear)
            }
            MerchantWorkbenchReminders(todo: todo, access: access,
                aftercareRoute: aftercareRoute,
                predictionReader: predictionReader)
            if access.isOwner || access.canReadAftercare {
                Section("merchant.todo") {
                    MerchantSectionState(model: todo, retry: { Task { await loadTodo() } },
                                         failureTitle: "merchant.home.projectsFailed") { value in
                        if !value.hasPendingWork {
                            CYEmptyState(systemImage: "checkmark.circle", "merchant.todo.empty")
                        }
                        if access.isOwner, value.pendingVerify > 0 { MerchantCountRow("merchant.todo.verify", value: value.pendingVerify) }
                        if access.isOwner, value.pendingScanConfirm > 0 { MerchantCountRow("merchant.todo.scan", value: value.pendingScanConfirm) }
                        if access.isOwner, value.pendingOrders > 0 { MerchantCountRow("merchant.todo.orders", value: value.pendingOrders) }
                        // Parity merchant/index P1: refunds and predictions are said once, by MerchantWorkbenchReminders above.
                        if access.isOwner, value.verifiedCount > 0 { MerchantCountRow("merchant.todo.verified", value: value.verifiedCount) }
                    }
                }
            }
            if showsRecordLinks && (access.allows(.orders) || access.allows(.projects)) {
                Section("merchant.records") {
                    if access.allows(.orders) {
                        NavigationLink {
                            MerchantOrdersView(reader: reader)
                                .onDisappear(perform: onChildReturn)
                                .cyPushedChrome(domain: .merchant)
                        } label: { Label("merchant.orders", systemImage: "receipt") }
                            .accessibilityIdentifier("merchant.orders.entry")
                    }
                    if access.allows(.projects) {
                        NavigationLink {
                            MerchantProjectsView(reader: reader, contentService: contentService)
                                .onDisappear(perform: onChildReturn)
                                .cyPushedChrome(domain: .merchant)
                        } label: { Label("merchant.projects", systemImage: "calendar") }
                            .accessibilityIdentifier("merchant.projects.entry")
                    }
                }
            } else if !access.isOwner && !access.canReadAftercare {
                Text("merchant.access.noReadSurfaces").foregroundStyle(.secondary)
            }
            // Source "更多" sheet plus the remaining tools, as one native group. A section with no visible rows renders nothing.
            if access.allows(.finance) {
                Section {
                    NavigationLink {
                        MerchantPayoutAccountView()
                            .cyPushedChrome(domain: .merchant)
                    } label: {
                        Label {
                            Text("payoutAccount.title", tableName: "PayoutReceiver")
                        } icon: { Image(systemName: "building.columns") }
                    }.accessibilityIdentifier("merchant.payoutAccount.open")
                }
            }
            Section("merchant.workbench.more") {
                Color.clear.frame(height: 0).id("merchant.workbench.moreSection").accessibilityHidden(true)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                if let aftercareRoute {
                    NavigationLink(value: aftercareRoute) {
                        Label(LocalizedStringKey(MerchantWorkbenchBusinessShortcut.aftercare.query.titleKey), systemImage: MerchantWorkbenchBusinessShortcut.aftercare.symbol)
                    }.accessibilityIdentifier("merchant.workbench.direct.aftercare")
                }
                if let businessReader, let businessJournal, access.allows(.verify) || access.allows(.verifyRecordRead) {
                    // Parity verify-records P1 / bundle-reservations P0: MP 更多 › 核销记录 and 套票到店 are one tap away.
                    NavigationLink {
                        MerchantBusinessPage(reader: businessReader, journal: businessJournal, query: .verificationRecords)
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label { Text("merchant.business.verifications") } icon: { MerchantMPIcon(image: MPAsset.FeatureIcon.iconCalendar) } }
                        .accessibilityIdentifier("merchant.workbench.verifyRecords")
                    if access.allows(.verify) {
                        NavigationLink {
                            MerchantBundleReservationsView(reader: businessReader)
                                .onDisappear(perform: onChildReturn)
                                .cyPushedChrome(domain: .merchant)
                        } label: { Label("merchant.bundleReservations.entry", systemImage: "calendar.badge.clock") }
                            .accessibilityIdentifier("merchant.workbench.bundleReservations")
                    }
                }
                // MC7-01-4: MP 更多 › 管理优惠券 (index.wxml:308) for roles holding merchant:coupon:manage.
                if access.allows(.couponManage), let couponManagementDestination {
                    NavigationLink {
                        couponManagementDestination()
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label("merchant.workbench.coupons", systemImage: "ticket") }
                        .accessibilityIdentifier("merchant.workbench.coupons")
                }
                if let businessReader, let businessJournal {
                    NavigationLink {
                        MerchantBusinessHomeView(reader: businessReader, journal: businessJournal)
                            .environment(\.merchantAftercareEvidenceDependencies, aftercareEvidenceDependencies(journal: businessJournal))
                            .environment(\.merchantCustomerQueryDestination, customerQueryDestination(source: businessReader, journal: businessJournal))
                            .id(businessReader.scope)
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label("merchant.business.title", systemImage: "building.2.crop.circle") }
                        .accessibilityIdentifier("merchant.business.open")
                }
                if let marketingModel {
                    // Source merchant tools expose this entry. Visibility is separate from service/AI/settlement grants.
                    MerchantMarketingEntry(model: marketingModel, isSourceVisible: true, suggestionDestination: marketingDestination,
                        recommendationOrigin: .init(merchantID: access.merchantID, readerScope: operationsReader?.scope))
                }
                if let merchantAuthoringDestination {
                    // Store AI drafts. Hidden until composition supplies an adopted authoring coordinator.
                    NavigationLink {
                        merchantAuthoringDestination()
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label { Text("orphanMount.merchantAuthoring.entry", tableName: "OrphanMounts") } icon: { Image(systemName: "sparkles.rectangle.stack") } }
                    .accessibilityIdentifier("merchant.authoring.open")
                }
                if let operationsReader {
                    NavigationLink {
                        operationsHome(operationsReader)
                    } label: { Label { Text("merchant.operations.title") } icon: { MerchantMPIcon(image: MPAsset.FeatureIcon.iconShop) } }
                    .accessibilityIdentifier("merchant.operations.open")
                }
                if let engagementReader, let businessJournal, let exportRecovery {
                    NavigationLink {
                        MerchantEngagementHomeView(reader: engagementReader, journal: businessJournal,
                            exportRecovery: exportRecovery, businessReader: businessReader)
                            .id(engagementReader.scope)
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label("merchant.engagement.title", systemImage: "person.2.crop.square.stack") }
                    .accessibilityIdentifier("merchant.engagement.open")
                }
                // MC7-12-2: 触达记录 (pages/merchant/crm-campaigns) as its own read-only page.
                if let engagementReader, let businessJournal, let exportRecovery, access.allows(.crmRead) {
                    NavigationLink {
                        MerchantCampaignHistoryHost(reader: engagementReader, journal: businessJournal, exports: exportRecovery)
                            .id(engagementReader.scope)
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label("merchant.campaigns.title", systemImage: "paperplane") }
                    .accessibilityIdentifier("merchant.campaigns.open")
                }
                if let contentService {
                    NavigationLink { MerchantContentHomeView(service: contentService)
                        .environment(\.merchantContentSupplyDestination, cooperationFlowReader.map { flowReader in
                            { source in AnyView(MerchantCooperationSupplyView(source: source, reader: flowReader)) }
                        })
                        .environment(\.merchantOfferWithdrawalDestination, cooperationFlowReader.map { flowReader in
                            let executor = (reader as? AppSession)?.offerWithdrawalExecutor
                            return { source in AnyView(MerchantOfferWithdrawalHostView(source: source, reader: flowReader, contentService: contentService, executor: executor)) }
                        })
                        .environment(\.merchantChapterReplacementContext, chapterReplacementContext(access: access))
                        .id(contentService.scope)
                        .onDisappear(perform: onChildReturn)
                        .cyPushedChrome(domain: .merchant)
                    } label: { Label("merchant.content.title", systemImage: "map") }
                        .accessibilityIdentifier("merchant.content.open")
                }
                if let coopCenterDestination {
                    NavigationLink {
                        coopCenterDestination(.plaza, nil)
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label(mcc("merchantCoopCenter.title", locale), systemImage: "person.2.wave.2") }
                        .accessibilityIdentifier("merchant.coopCenter.open")
                }
                // Parity coop/list P1: 协作邀请 opens the invitation list (MP pages/coop/list), not the tools workbench.
                if let coopInboxDestination {
                    NavigationLink {
                        coopInboxDestination()
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label { Text("merchant.workbench.coopInvites") } icon: { MerchantMPIcon(image: MPAsset.Other.navMsg) } }
                        .accessibilityIdentifier("merchant.coopInbox.open")
                }
                if let cooperationFlowReader {
                    NavigationLink {
                        CooperationFlowWorkbench(reader: cooperationFlowReader, operationScope: "MERCHANT")
                            .onDisappear(perform: onChildReturn)
                            .cyPushedChrome(domain: .merchant)
                    } label: { Label("cooprelation.tools", systemImage: "square.grid.2x2") }
                        .accessibilityIdentifier("merchant.cooperationFlows.open")
                }
            }
            if access.canReadDashboard, let value = dashboard.value, !value.revenue7d.isEmpty {
                Section("merchant.revenue7d") {
                    ForEach(Array(value.revenue7d.enumerated()), id: \.offset) { _, point in
                        LabeledContent {
                            Text(MerchantMoney.display(point.amount))
                                .cyText(.bodyMedium)
                                .monospacedDigit()
                                .foregroundStyle(CYColor.textPrimary)
                        } label: {
                            Text(point.date)
                                .cyText(.body)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
            }
            // Parity merchant/index P1 (我的消息): conversations + received coop invites + business events, newest three.
            // Replaces the owner-only 实时动态 list; the bottom 重新检查经营身份 button is gone (pull to refresh reloads).
            MerchantInboxPreviewSection(
                sources: inboxSources,
                events: access.canReadEvents ? events.value : nil,
                eventsSettled: !access.canReadEvents || events.errorKey != nil,
                eventsFailed: access.canReadEvents && events.errorKey != nil,
                canManageCoop: access.allows(.coopManage),
                reloadToken: childReturnRevision,
                eventDestination: inboxEventDestination)
        }
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .navigationBarTitleDisplayMode(.inline)
        .listSectionSpacing(CYSpacing.xxl)
        .navigationDestination(item: $quickRoute) { route in
            Group {
                if let businessReader, let businessJournal,
                   route.isCurrent(reader: businessReader, journal: businessJournal) {
                    // Source 财务 opens the settlement ledger (pages/merchant/ledger), as the business workspace does.
                    if route.shortcut == .finance {
                        MerchantLedgerSettlementOverview(reader: route.reader, journal: route.journal)
                            .environment(\.merchantR1CumulativeRevenue, dashboard.value.map { $0.revenue })
                            .onDisappear(perform: onChildReturn)
                    } else {
                        MerchantBusinessPage(reader: route.reader, journal: route.journal, query: route.shortcut.query)
                        .environment(\.merchantAftercareEvidenceDependencies, aftercareEvidenceDependencies(journal: route.journal))
                        .environment(\.merchantCustomerQueryDestination, customerQueryDestination(source: route.reader, journal: route.journal))
                        .id(route)
                        .onDisappear(perform: onChildReturn)
                    }
                } else {
                    Text("merchant.business.stale")
                }
            }
            .cyPushedChrome(domain: .merchant)
        }
        .navigationDestination(isPresented: $showsScan) {
            if let nativeVerificationDestination {
                nativeVerificationDestination()
                    .onDisappear(perform: onChildReturn)
                    .cyPushedChrome(domain: .merchant)
            }
        }
        .confirmationDialog(Text("merchant.status.pauseTitle"), isPresented: $confirmsPause, titleVisibility: .visible) {
            Button("merchant.status.pauseConfirm", role: .destructive) { Task { await setBusinessStatus(.closed) } }
            Button("merchant.status.keepOpen", role: .cancel) {}
        } message: {
            Text("merchant.status.pauseMessage")
        }
        .cyToast(verbatimMessage: $toastMessage)
        .navigationDestination(for: MerchantWorkbenchBusinessRoute.self) { route in
            Group {
                if let businessReader, let businessJournal,
                   route.isCurrent(reader: businessReader, journal: businessJournal) {
                    MerchantBusinessPage(reader: route.reader, journal: route.journal, query: route.shortcut.query)
                        .environment(\.merchantAftercareEvidenceDependencies, aftercareEvidenceDependencies(journal: route.journal))
                        .environment(\.merchantCustomerQueryDestination, customerQueryDestination(source: route.reader, journal: route.journal))
                        .id(route)
                        .onDisappear(perform: onChildReturn)
                } else {
                    Text("merchant.business.stale")
                }
            }
            .cyPushedChrome(domain: .merchant)
        }
        .refreshable {
            await refreshAccess()
            await loadBusinessStatus()
        }
        .task(id: "\(operationsReader?.scope.uuidString ?? "none"):\(childReturnRevision)") {
            await loadBusinessStatus()
        }
        }
    }
    private var canToggleStatusInPlace: Bool {
        guard let operationsReader, operationsReader.canSave, !operationsReader.isOfflineExample,
              let operationsAccess, operationsAccess.allows(.businessStatus),
              let merchantID = access.merchantID, merchantID > 0 else { return false }
        return true
    }
    private func setBusinessStatus(_ next: MerchantBusinessStatus) async {
        guard let operationsReader, let current = businessStatus, let merchantID = access.merchantID,
              let draft = try? MerchantStoreBusinessStatus(merchantID: merchantID, status: next),
              let baseline = try? MerchantStoreBusinessStatus(merchantID: merchantID, status: current) else { return }
        statusBusy = true
        defer { statusBusy = false }
        do {
            try await operationsReader.saveReviewed(.businessStatus(draft), baseline: .businessStatus(baseline))
        } catch is CancellationError {
            return
        } catch {
            toastMessage = appLocalized("merchant.status.updateFailed", locale: locale)
        }
        // Read back whatever the server now holds, success or not.
        await loadBusinessStatus()
    }
    private func loadBusinessStatus() async {
        guard let operationsReader, operationsReader.isConfigured, operationsReader.isAuthenticated else {
            operationsAccess = nil
            businessStatus = nil
            return
        }
        let scope = operationsReader.scope
        do {
            let opsAccess = try await operationsReader.access()
            guard !Task.isCancelled, operationsReader.scope == scope else { return }
            operationsAccess = opsAccess
            guard opsAccess.identity.allows(.basicRead) else {
                businessStatus = nil
                return
            }
            let doc = try await operationsReader.document(.businessStatus)
            guard !Task.isCancelled, operationsReader.scope == scope else { return }
            if case .draft(.businessStatus(let state)) = doc {
                businessStatus = state.status
            }
        } catch {
            // Non-fatal on hero header; operations tools remain available below.
        }
    }
    /// Source `goEvent`: an income event opens 账本 › 结算, a verify event 账本 › 核销. Other events have no page.
    private func inboxEventDestination(_ item: MerchantInboxItem) -> AnyView? {
        guard case .event(let type, _) = item.kind, type == "income" || type == "verify",
              access.allows(.finance) || access.allows(.verifyRecordRead), let businessReader else { return nil }
        return AnyView(MerchantLedgerSettlementOverview(reader: businessReader, journal: businessJournal, initialView: type == "income" ? .settlements : .redemptions)
            .environment(\.merchantR1CumulativeRevenue, dashboard.value.map { $0.revenue })
            .onDisappear(perform: onChildReturn)
            .cyPushedChrome(domain: .merchant))
    }
    private func aftercareEvidenceDependencies(journal: any MerchantBusinessIntentStore) -> MerchantAftercareEvidenceDependencies? {
        guard let engagementReader, let exportRecovery else { return nil }
        return .init(reader: engagementReader, journal: journal, recovery: exportRecovery)
    }
    private func loadDashboard() async {
        guard access.canReadDashboard else { return }
        await dashboard.load(reader: reader) { try await reader.merchantDashboard(access: access) }
    }
    private func loadTodo() async {
        await MerchantWorkbenchTodoLoader.load(into: todo, reader: reader, access: access, businessReader: businessReader)
    }
    private func loadEvents() async {
        guard access.canReadEvents else { return }
        await events.load(reader: reader) { try await reader.merchantEvents(access: access) }
    }
}

@MainActor enum MerchantWorkbenchTodoLoader {
    static func load<Reader: MerchantReading>(
        into model: MerchantLoadModel<MerchantTodo>,
        reader: Reader,
        access: MerchantAccess,
        businessReader: (any MerchantBusinessReading)?
    ) async {
        guard access.isOwner || access.canReadAftercare else { return }
        if !access.isOwner {
            guard access.canReadAftercare,
                  let businessReader,
                  businessReader.isConfigured,
                  businessReader.scope != nil else {
                await model.load(reader: reader, discardOldValue: true) {
                    throw APIError.notConfigured
                }
                return
            }
            let revision = reader.sessionRevision
            await model.load(reader: reader, discardOldValue: true) {
                let snapshot = try await businessReader.snapshot(.aftercare(.pending, page: 1), isCurrent: {
                    reader.isConfigured && reader.isSignedIn && reader.sessionRevision == revision
                })
                guard snapshot.access.merchantID == access.merchantID,
                      snapshot.access.allows("merchant:aftercare:read") else {
                    throw MerchantBusinessFailure.denied
                }
                guard let total = snapshot.document.total else { throw APIError.malformedResponse }
                return MerchantTodo(aftercareRefundCount: total)
            }
            return
        }
        await model.load(reader: reader) { try await reader.merchantTodo(access: access) }
    }
}

struct MerchantCountRow: View {
    let title: LocalizedStringKey
    let value: Int
    init(_ title: LocalizedStringKey, value: Int) { self.title = title; self.value = value }
    var body: some View {
        LabeledContent {
            Text(value, format: .number)
                .cyText(.sectionTitle, monospacedDigit: true)
                .foregroundStyle(CYColor.textPrimary)
        } label: {
            Text(title)
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
        }
    }
}

#Preview("MerchantCountRow · light") {
    List { MerchantCountRow("merchant.todo.verify", value: 12) }.preferredColorScheme(.light)
}
#Preview("MerchantCountRow · dark sanity") {
    List { MerchantCountRow("merchant.todo.verify", value: 12) }.preferredColorScheme(.dark)
}

@MainActor
struct MerchantSectionState<Value, Content: View>: View {
    @ObservedObject var model: MerchantLoadModel<Value>
    let retry: () -> Void
    let content: (Value) -> Content
    /// MP section-specific inline error title (cy-inline-error title=…); nil keeps the server reason only.
    var failureTitle: LocalizedStringKey? = nil
    var retryTitle: LocalizedStringKey = "action.retry"
    init(model: MerchantLoadModel<Value>, retry: @escaping () -> Void,
         failureTitle: LocalizedStringKey? = nil, retryTitle: LocalizedStringKey = "action.retry",
         @ViewBuilder content: @escaping (Value) -> Content) {
        self.model = model; self.retry = retry; self.content = content
        self.failureTitle = failureTitle; self.retryTitle = retryTitle
    }
    var body: some View {
        if let value = model.value {
            if model.isLoading { ProgressView("merchant.refreshing").cyText(.meta) }
            if let error = model.errorKey {
                Text("merchant.stale").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                MerchantInlineFailure(errorKey: error, retry: retry, title: failureTitle, retryTitle: retryTitle)
            }
            content(value)
        } else if let error = model.errorKey {
            MerchantInlineFailure(errorKey: error, retry: retry, title: failureTitle, retryTitle: retryTitle)
        } else { CYSkeleton(variant: .merchantMetric) }
    }
}

/// Source 4-up quick action: borderless circular fill, short label beneath (pages/merchant/index).
private struct MerchantQuickCircleAction: View {
    let title: LocalizedStringKey
    let systemImage: String
    var primary = false
    let action: () -> Void
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .title3) private var diameter: CGFloat = 60 // MP 120rpx

    var body: some View {
        Button(action: action) {
            VStack(spacing: CYSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primary ? palette.actionPrimaryFg : palette.textPrimary)
                    .frame(width: diameter, height: diameter)
                    .background(primary ? palette.actionPrimaryBg : palette.bgSurface, in: Circle())
                Text(title)
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MerchantInlineFailure: View {
    let errorKey: String
    let retry: () -> Void
    var title: LocalizedStringKey? = nil
    var retryTitle: LocalizedStringKey = "action.retry"
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if let title, errorKey != "merchant.access.denied" && errorKey != "auth.expired" {
                Text(title)
                    .cyText(.label)
                    .foregroundStyle(CYColor.textPrimary)
            } else {
                Text(LocalizedStringKey(errorKey))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
            if errorKey != "merchant.access.denied" && errorKey != "auth.expired" {
                Button(retryTitle, action: retry)
                    .buttonStyle(.bordered)
                    .frame(minHeight: CYSpacing.minTouchTarget)
            }
        }
        .padding(.vertical, CYSpacing.xs)
    }
}

struct MerchantFailureView: View {
    let errorKey: String
    let identifier: String
    let retry: () -> Void
    /// MC7-28-4: MP 申请入驻 (`openApplication`) on the denied state. Nil hides it.
    var apply: (() -> Void)? = nil
    var body: some View {
        // Native restyle R3: the system unavailable state with a retry button.
        ContentUnavailableView {
            Label(LocalizedStringKey(errorKey), systemImage: errorKey == "merchant.access.denied" ? "lock" : "exclamationmark.triangle")
                .accessibilityIdentifier(identifier + ".error")
        } actions: {
            if errorKey == "merchant.access.denied", let apply {
                Button("merchant.gate.apply", action: apply)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(identifier + ".apply")
            }
            if errorKey != "merchant.access.denied" && errorKey != "auth.expired" {
                Button("action.retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(identifier + ".retry")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(CYSpacing.pageHorizontal)
    }
}

/// Entry choices carry no grant. The existing page performs its own fresh authorization read.
enum MerchantWorkbenchBusinessShortcut: String, CaseIterable, Identifiable {
    case customers, finance, aftercare
    var id: String { rawValue }
    var query: MerchantBusinessQuery {
        switch self {
        case .customers: return .customers(.init())
        case .finance: return .overview
        case .aftercare: return .aftercare(.pending, page: 1)
        }
    }
    /// Source quick-action labels: 客户, 财务, 退款售后.
    var shortTitleKey: String {
        switch self {
        case .customers: return "merchant.workbench.customers"
        case .finance: return "merchant.workbench.finance"
        case .aftercare: return query.titleKey
        }
    }
    var symbol: String {
        switch self {
        case .customers: return "person.2"
        case .finance: return "list.bullet.rectangle"
        case .aftercare: return "arrow.uturn.backward.circle"
        }
    }
}

/// Freeze the original dependencies, including authorization generation, before navigation.
/// Leaving Home for a child does not replace this route; a changed context invalidates it.
struct MerchantWorkbenchBusinessRoute: Hashable {
    let shortcut: MerchantWorkbenchBusinessShortcut
    private let value: MerchantBusinessHomeRoute
    var reader: any MerchantBusinessReading { value.reader }
    var journal: any MerchantBusinessIntentStore { value.journal }
    @MainActor init?(shortcut: MerchantWorkbenchBusinessShortcut, reader: any MerchantBusinessReading,
                     journal: any MerchantBusinessIntentStore) {
        guard reader.isConfigured, reader.scope != nil else { return nil }
        self.shortcut = shortcut
        value = .init(target: .query(shortcut.query), reader: reader, journal: journal)
    }
    @MainActor func isCurrent(reader: any MerchantBusinessReading, journal: any MerchantBusinessIntentStore) -> Bool {
        value.isCurrent(reader: reader, journal: journal)
    }
}

@MainActor private struct MerchantCustomerQueryDestinationView<Reader: MerchantReading>: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var root: Reader
    let selection: MerchantCustomerAppliedQuery
    let journal: any MerchantBusinessIntentStore
    let exports: any MerchantExportRecoveryStoring
    @StateObject private var reader: MerchantCustomerQueryReader
    init(root: Reader, source: any MerchantBusinessReading, engagement: any MerchantEngagementReading,
         journal: any MerchantBusinessIntentStore, exports: any MerchantExportRecoveryStoring,
         selection: MerchantCustomerAppliedQuery, revision: UInt64, merchantID: Int?) {
        self.root = root; self.selection = selection; self.journal = journal; self.exports = exports
        _reader = StateObject(wrappedValue: .init(selection: selection, base: engagement, source: source, originCurrent: {
            root.isConfigured && root.isSignedIn && root.sessionRevision == revision && merchantID == selection.merchantID
        }))
    }
    var body: some View {
        Group {
            if reader.isCurrent {
                MerchantEngagementHomeView(reader: reader, journal: journal, exportRecovery: exports,
                    filter: selection.filter).id(selection.id)
            } else { Text("merchant.business.stale") }
        }
        .background(MerchantCustomerQueryOwnerAnchor(reader: reader).frame(width: 0, height: 0))
        .onAppear { if scenePhase != .active { reader.retire() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { reader.retire() } }
    }
}


/// Navigation into an existing child does not end this captured query owner.
/// Actual owner removal does, including when a modal covers the parent.
@MainActor struct MerchantCustomerQueryOwnerAnchor: UIViewControllerRepresentable {
    let reader: MerchantCustomerQueryReader
    final class Coordinator {
        weak var reader: MerchantCustomerQueryReader?
        init(_ reader: MerchantCustomerQueryReader) { self.reader = reader }
    }
    func makeCoordinator() -> Coordinator { Coordinator(reader) }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) { coordinator.reader?.retire() }
}


/// Two-column flow for the quick circles when text is at an accessibility size.
private struct GridFlowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320, cell = width / 2
        let heights = subviews.map { $0.sizeThatFits(.init(width: cell, height: nil)).height }
        var total: CGFloat = 0
        for row in stride(from: 0, to: heights.count, by: 2) { total += heights[row..<min(row + 2, heights.count)].max() ?? 0 }
        return CGSize(width: width, height: total)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = bounds.width / 2; var y = bounds.minY
        for row in stride(from: 0, to: subviews.count, by: 2) {
            let slice = subviews[row..<min(row + 2, subviews.count)]
            let height = slice.map { $0.sizeThatFits(.init(width: cell, height: nil)).height }.max() ?? 0
            for (i, v) in slice.enumerated() {
                v.place(at: CGPoint(x: bounds.minX + CGFloat(i) * cell, y: y), anchor: .topLeading, proposal: .init(width: cell, height: height))
            }
            y += height
        }
    }
}


/// verify-r1 2.8: hides the inline navigation title on the workbench root (iOS 18+); earlier systems keep it.
private struct MerchantHomeHiddenNavigationTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
