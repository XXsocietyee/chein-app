import SwiftUI

/// Masks sensitive financial/wallet/payout screens whenever the scene leaves `.active` (including `.inactive` app switcher snapshots).
private struct AppSwitcherPrivacyShieldModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content
            .privacySensitive()
            .redacted(reason: scenePhase == .active ? [] : .privacy)
            .overlay {
                if scenePhase != .active {
                    ZStack {
                        Rectangle().fill(.background).ignoresSafeArea()
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    func appSwitcherPrivacyShield() -> some View { modifier(AppSwitcherPrivacyShieldModifier()) }
}

/// A denied capability is unavailable; transient/business failures remain retryable.
enum WalletReadFailurePresentation {
    static func isUnavailable(_ error: Error) -> Bool {
        (error as? APIError) == .notConfigured || (error as? WalletCommerceSafetyError) == .unavailable
    }
    static func isForbidden(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            return apiError == .httpStatus(403) || apiError == .businessCode(403)
        }
        return false
    }
    static func incomeSourceBadge(for row: WalletLedgerRow) -> String? {
        switch row.eventType {
        case 1: return "创"
        case 2, 5: return "品"
        default: return nil
        }
    }
}

/// Why a wallet read failed; drives `WalletIssueView` (login prompt vs unavailable vs retry).
struct WalletReadFailure: Equatable { var requiresLogin: Bool; var unavailable: Bool }

@MainActor final class WalletScreen<Value>: ObservableObject {
    /// One load lifecycle instead of `value` / `failed` / `loading` / `requiresLogin` / `unavailable`
    /// (docs/release/state-machines/views.md). Impossible combinations (loading with a value, failed with a value) cannot exist.
    @Published private(set) var phase: CYPhase<Value, WalletReadFailure> = .idle
    @Published var loadedScope: WalletCommerceScope?
    var value: Value? { phase.value }
    var failed: Bool { phase.isFailed }
    var loading: Bool { phase.isLoading }
    var requiresLogin: Bool { phase.failure?.requiresLogin ?? false }
    var unavailable: Bool { phase.failure?.unavailable ?? false }
    private var generation = UUID()
    func cancel() { generation = UUID(); if phase.isLoading { phase = .idle } }
    func clear() { generation = UUID(); phase = .idle; loadedScope = nil }
    /// Shows the skeleton immediately (a caller retired old results and a load is scheduled).
    func markLoading() { phase = .loading }
    func load(_ reader: WalletCommerceReader, operation: (WalletCommerceService, String) async throws -> Value) async {
        let stamp = UUID(); generation = stamp; phase = .loading
        let scope = reader.scope
        loadedScope = nil
        defer { if stamp == generation, phase.isLoading { phase = .idle } }
        do {
            let result = try await reader.read(operation)
            guard stamp == generation else { return }
            guard scope == reader.scope else { clear(); return }
            phase = .loaded(result); loadedScope = scope
        } catch {
            guard stamp == generation else { return }
            guard scope == reader.scope else { clear(); return }
            if error is CancellationError { return }
            if (error as? WalletCommerceSafetyError) == .staleSession { clear(); return }
            phase = .failed(WalletReadFailure(requiresLogin: (error as? APIError) == .unauthorized,
                                              unavailable: WalletReadFailurePresentation.isUnavailable(error)), retry: nil)
        }
    }
}
/// The account earnings overview uses the same owner-scoped read as withdrawal support.
/// It does not load fund stages or authorize any payout operation.
extension WalletScreen where Value == WithdrawalBalance {
    func loadEarnings(_ reader: WalletCommerceReader) async {
        guard let owner = reader.scope?.accountID else { clear(); return }
        await load(reader) { service, token in
            try await service.withdrawalBalance(memberID: owner, token: token)
        }
    }
}
@MainActor private struct WalletIssueView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    var requiresLogin = false
    var unavailable = false
    /// FIN-18-3: the points ledger says 积分明细加载失败 (MP points-history/index.wxml:11).
    var failedKey = "wallet.failed"
    /// Round 4 copy (MP scene-asset-earnings:7, scene-asset-income-detail:41): page wording for the signed-out and
    /// no-permission states. nil keeps the shared 登录后可查看 / 暂时无法显示.
    var loginKey: String? = nil
    var deniedKey: String? = nil
    var retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey((reader.scope == nil || requiresLogin) ? (loginKey ?? "wallet.login")
                : reader.isConfigured && !unavailable ? failedKey
                : reader.isConfigured ? (deniedKey ?? "wallet.unavailable") : "wallet.unavailable")).accessibilityIdentifier("wallet.issue")
            if reader.isConfigured && reader.scope != nil && !requiresLogin && !unavailable {
                Button("wallet.retry", action: retry)
                    .buttonStyle(.bordered)
            }
        }
    }
}
/// Additive destination only. Host must keep existing entry gates and reset .id(reader.scope)
/// whenever deployment/account/epoch changes; no new root navigation entry is installed here.
/// Withdraw / payout entries follow the withdrawal switch. Owner 2026-11-25: money is on for Release and
/// DEBUG/TEST when an API host is installed, including www.chengyinhub.com. A missing host stays off.
/// Unknown amounts still render as an em dash.
enum WalletPayoutCapability {
    /// A present host opens payout. A missing host stays closed. `testOrDebug` does not close Release.
    static func decision(testOrDebug: Bool, apiHost: String?) -> Bool {
        ReviewedAreaSwitch.payout(apiHost: apiHost, testOrDebug: testOrDebug)
    }
    /// Follows the Core withdrawal switch, which the composition derives from its API host (`installReleaseMoneyDerivation`).
    static var isOn: Bool { ReleaseMoneyWriteSwitch.withdrawalEnabled }
}

@MainActor struct WalletCommerceHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var earnings = WalletScreen<WithdrawalBalance>()
    @StateObject private var funds = WalletScreen<WalletFundsStages>()
    @StateObject private var monthModel = WalletPagerScreen()
    @State private var isVisible = false
    @State private var showsMore = false
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }
    let reader: WalletCommerceReader
    let visibility: WalletCommerceVisibility
    let onCooperationFinance: () -> Void
    var invitationHistory: WalletInvitationHistoryAccess? = nil
    var showsWithdrawalSupport = true
    var showsCooperationFinance = true
    var organizerFinance: WalletOrganizerFinanceAccess? = nil
    /// R7-PC-D5-2 (MP scene-asset-earnings 更多): 本人俱乐部结算 / 个人收款, supplied by a session host.
    var clubSettlement: (() -> AnyView)? = nil
    var personalPayout: (() -> AnyView)? = nil
    /// MP `theme === 'merchant'`: the zero-balance empty state is not shown on the merchant entry.
    var merchantView = false
    /// R7-PC-D5-3 (MP scene-asset-earnings/index.wxml:22): a loaded zero balance shows only 还没有收益 + 去发布路线.
    private var showsZeroBalanceOnly: Bool {
        guard !merchantView, visibility.income, let value = earnings.value, earnings.loadedScope == reader.scope,
              reader.scope != nil else { return false }
        return value.balance.value == 0
    }
    var body: some View {
        List {
            if visibility.income {
                Section {
                    if earnings.loading {
                        ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("wallet.earnings.loading")
                    } else if let value = earnings.value, reader.isConfigured,
                              earnings.loadedScope == reader.scope, reader.scope != nil {
                        // PC-D-5-3: MP label 账户收益 (the currency symbol is drawn beside the number).
                        WalletEarningsHero(label: appLocalized("wallet.earnings.balance", locale: locale),
                                           number: WalletNumberLocalization.money(value.balance.text, locale: locale),
                                           symbol: WalletCurrencySymbol.symbol(value.currency))
                            .privacySensitive()
                            .accessibilityIdentifier("wallet.earnings.balance")
                        if value.balance.value == 0 { WalletEarningsEmptyNote() }
                    } else {
                        WalletIssueView(reader: reader, requiresLogin: earnings.requiresLogin,
                            unavailable: earnings.unavailable, failedKey: "wallet.earnings.loadFailed",
                            loginKey: "wallet.earnings.signInRequired", deniedKey: "wallet.earnings.denied") { Task { await loadEarnings() } }
                    }
                }.accessibilityIdentifier("wallet.earnings.overview")
            }
            quickActions
            if !showsZeroBalanceOnly {
                if visibility.income { monthIncomeSection }
                if visibility.assets { assetsSection }
            }
        }.listStyle(.insetGrouped)
            .cyPageTitle("wallet.title") // PC-D-5-5
            .cyHideTabBar()
            .task(id: reader.scope) {
                isVisible = true
                earnings.clear()
                funds.clear()
                monthModel.reset()
                await loadEarnings()
                await loadFunds()
                await loadMonth()
            }
            .cySheet(isPresented: $showsMore) { moreSheet }
            .onDisappear { isVisible = false; earnings.clear(); funds.clear(); monthModel.cancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { earnings.clear(); funds.clear() }
                else if isVisible { Task { await loadEarnings(); await loadFunds(); await loadMonth() } }
            }
            .refreshable { await loadEarnings(); await loadFunds(); monthModel.reset(); await loadMonth() }
            .onChange(of: earnings.loading) { _, isLoading in
                if WalletLoadAnnouncement.shouldAnnounce(wasLoading: true, isLoading: isLoading, hasValue: earnings.value != nil) {
                    AccessibilityNotification.Announcement(WalletLoadAnnouncement.text(locale: locale)).post()
                }
            }
            .appSwitcherPrivacyShield()
    }
    /// Four quick actions (system bordered buttons, symbol over label): the first available one is the single
    /// prominent action (withdraw), the last opens More.
    @ViewBuilder private var quickActions: some View {
        let items = quickItems
        if !items.isEmpty {
            Section {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        item.primary(index == 0)
                    }
                    WalletQuickAction(title: appLocalized("wallet.more", locale: locale), icon: "ellipsis", id: "wallet.more.open") { showsMore = true }
                }.frame(maxWidth: .infinity)
            }
        }
    }
    private var quickItems: [WalletQuickAction] {
        var out: [WalletQuickAction] = []
        if visibility.withdrawalRecords {
            // R11-PC-D-1 / R9-PC-D5-1 MP-first: 提现 always runs the 暂无提现权限 gate, then the platform CS popup, whether
            // payout is on or off. MP removed the bank form (PG-033; subpackageA/pages/assetcenter/earnings/index.js:61-76).
            if showsWithdrawalSupport {
                out.append(.init(title: "withdrawal.support.title", icon: "arrow.up.right", id: "wallet.withdrawalSupport.open", destination: { AnyView(WalletWithdrawPermissionGate()) }))
            }
            // FIN-19-2: 提现记录 is a read; only the apply entry follows the withdrawal switch.
            out.append(.init(title: "wallet.withdrawals", icon: "list.bullet.rectangle", id: "wallet.withdrawals.open", destination: { AnyView(WithdrawalHistoryView(reader: reader)) }))
        }
        if visibility.income { out.append(.init(title: "wallet.income", icon: "list.bullet.indent", id: "wallet.income.open", destination: { AnyView(incomeDestination) })) }
        // Source assetcenter/earnings quick row: 提现 / 明细 / 分析 / 更多. Points history moves into 更多.
        if visibility.income { out.append(.init(title: "wallet.analysis.title", icon: "chart.bar.xaxis", id: "wallet.analysis.quick", destination: { AnyView(WalletIncomeAnalysisView(reader: reader)) })) }
        return out
    }
    private var incomeDestination: WalletIncomeView {
        WalletIncomeView(reader: reader, onCooperationFinance: onCooperationFinance, showsCooperationFinance: showsCooperationFinance, organizerFinance: organizerFinance)
    }
    private var calendar: Calendar { WalletIncomeDay.serverCalendar }
    private var monthPrefix: String {
        let c = calendar.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
    private var monthTitle: String {
        let month = calendar.component(.month, from: Date())
        if locale.language.languageCode?.identifier == "zh" { return "\(month)月" }
        return calendar.shortMonthSymbols[month - 1]
    }
    private var monthRows: [WalletLedgerRow] {
        monthModel.pager.rows.filter { $0.incomeDirection == .income && ($0.createTime ?? "").hasPrefix(monthPrefix) }
    }
    /// 本月收入明细: this month's income rows, or the empty card. "All" opens the full income detail.
    private var monthIncomeSection: some View {
        Section {
            if monthModel.pager.hasLoadedPage, monthModel.pager.loadedScope == reader.scope {
                if monthRows.isEmpty {
                    Text("wallet.monthIncome.empty")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("wallet.month.empty")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(monthRows.prefix(3).enumerated()), id: \.element.id) { index, row in
                            if index > 0 { Divider() }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: row.changeReason ?? appLocalized("wallet.entry", locale: locale))
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let day = WalletIncomeDay.make(row.createTime) {
                                        WalletIncomeDayText(day: day).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                Text(verbatim: format.signed(row, points: false, income: true) + " " + (row.currency.flatMap { WalletCurrencySymbol.symbol($0) } ?? ""))
                                    .monospacedDigit().privacySensitive()
                            }.padding(.vertical, 8)
                        }
                    }.accessibilityIdentifier("wallet.month.rows")
                }
            } else if monthModel.pager.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(verbatim: WalletIncomeDetailPageModel.unknownMoney).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("wallet.monthIncome.title")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink { incomeDestination } label: {
                    Text(verbatim: monthTitle + " ") + Text("wallet.all")
                }.buttonStyle(.borderless).accessibilityIdentifier("wallet.month.all")
            }.textCase(nil)
        }
    }
    /// 我的资产: icon rows with trailing amounts (— while unknown), all opening the existing assets screen.
    private var assetsSection: some View {
        Section {
            let phase = WalletFundsStageClassifier.phase(WalletFundsStageClassifier.input(reader: reader, funds: funds))
            let stages = WalletFundsStageClassifier.showsAmounts(phase) ? funds.value : nil
            if WalletFundsStageClassifier.showsAmounts(phase) {
            NavigationLink { WalletAssetsView(reader: reader) } label: {
                VStack(spacing: 0) {
                    assetRow("creditcard", "wallet.assets.withdrawableLabel", stages.map { assetAmount($0.withdrawable, $0.currency) })
                    Divider()
                    assetRow("clock.arrow.circlepath", "wallet.pendingSettlement", stages.map { assetAmount($0.pendingSettlement, $0.currency) })
                    Divider()
                    assetRow("exclamationmark.bubble", "wallet.assets.disputedLabel", stages.map { assetAmount($0.disputed, $0.currency) })
                }
            }.accessibilityIdentifier("wallet.assets.open")
            } else {
                WalletFundsStagesInline(reader: reader, funds: funds) { Task { await loadFunds() } }
            }
        } header: {
            Text("wallet.assets")
                .accessibilityAddTraits(.isHeader).textCase(nil)
        }.accessibilityIdentifier("wallet.earnings.stages.home")
    }
    private func assetAmount(_ amount: WalletAmount, _ currency: String?) -> String {
        guard let symbol = WalletCurrencySymbol.symbol(currency) else { return format.amount(amount, currency: currency) }
        return symbol + WalletNumberLocalization.money(amount.text, locale: locale)
    }
    private func assetRow(_ icon: String, _ title: LocalizedStringKey, _ value: String?) -> some View {
        LabeledContent {
            Text(verbatim: value ?? WalletIncomeDetailPageModel.unknownMoney)
                .monospacedDigit().privacySensitive()
        } label: {
            Label(title, systemImage: icon)
        }
        .padding(.vertical, 8)
    }
    /// 更多: the navigation rows that are not quick actions (destinations and gates unchanged).
    private var moreSheet: some View {
        NavigationStack {
            List {
                // R7-PC-D5-2: MP order 本人俱乐部结算 · 个人收款 · 提现记录 · 邀请记录. 分析 is a quick action and 我的资产 is
                // on the page, so neither repeats here.
                if let clubSettlement {
                    walletRow("wallet.more.clubSettlement", icon: "list.bullet", id: "wallet.clubSettlement.open") { clubSettlement() }
                }
                if let personalPayout {
                    walletRow("wallet.more.personalPayout", icon: "creditcard", id: "wallet.personalPayout.open") { personalPayout() }
                }
                if visibility.withdrawalRecords {
                    walletRow("wallet.withdrawals", icon: "list.bullet.rectangle", id: "wallet.withdrawals.open") { WithdrawalHistoryView(reader: reader) }
                }
                if visibility.income, let invitationHistory {
                    walletRow("social.invites.title", icon: "person.2.badge.plus", id: "wallet.inviteHistory") {
                        SocialInviteHistoryView(reader: invitationHistory.reader,
                            squareReader: invitationHistory.squareReader, actions: invitationHistory.actions)
                            .id(invitationHistory.reader.identity)
                    }
                }
                // FIN-18-1: one 积分明细 contract on every entry, the MP points-history read (`api/points/list`).
                if visibility.points { walletRow("wallet.points", icon: "star.circle", id: "wallet.points.open") { WalletLedgerView(reader: reader, kind: .assetPoints) } }
                if visibility.mall { walletRow("wallet.mall", icon: "bag", id: "wallet.mall.open") { WalletProductsView(reader: reader) } }
            }.listStyle(.insetGrouped)
                .appNavigationTitle(key: "wallet.title").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    private func walletRow<D: View>(_ title: LocalizedStringKey, icon: String, id: String, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink { destination() } label: {
            Label(title, systemImage: icon)
        }
        .accessibilityIdentifier(id)
    }
    private func loadMonth() async {
        guard visibility.income, isVisible, scenePhase == .active else { return }
        await monthModel.load(reader, kind: .income(.all))
    }
    private func loadEarnings() async {
        guard visibility.income, isVisible, scenePhase == .active else { return }
        await earnings.loadEarnings(reader)
    }
    private func loadFunds() async {
        guard visibility.assets, isVisible, scenePhase == .active else { return }
        await funds.load(reader) { try await $0.stages(token: $1) }
    }
}
@MainActor struct WalletAssetsView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    @StateObject private var funds = WalletScreen<WalletFundsStages>()
    var body: some View {
        List {
            Section("wallet.fundStages") {
                if funds.loading { ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("wallet.assets.loading") }
                else if let value = funds.value, funds.loadedScope == reader.scope {
                    if !value.amountsKnown {
                        Text("wallet.amountsUnknown").accessibilityIdentifier("wallet.assets.unknown")
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: appLocalized("wallet.assets.availableBalanceLabel", locale: locale))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(verbatim: format.amount(value.withdrawable, currency: value.currency))
                                .cyText(.data2XL, monospacedDigit: true)
                                .privacySensitive()
                        }
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("wallet.assets.revolutCard")
                        if value.pendingSettlement.value > 0 { LabeledContent("wallet.pendingSettlement", value: format.amount(value.pendingSettlement, currency: value.currency)) }
                        ForEach(Array(value.complaintPeriod.enumerated()), id: \.offset) { _, item in
                            LabeledContent { Text(format.amount(item.amount, currency: value.currency)) } label: {
                                Text("wallet.complaintPeriod"); Text(verbatim: WalletCivilDateLocalization.text(item.availableDate, locale: locale))
                            }
                        }
                        if value.disputed.value > 0 { LabeledContent("wallet.disputed", value: format.amount(value.disputed, currency: value.currency)) }
                        LabeledContent("wallet.available", value: format.amount(value.withdrawable, currency: value.currency))
                            .accessibilityIdentifier("wallet.assets.available")
                    }
                    Text("wallet.notPayout")
                } else { WalletIssueView(reader: reader, requiresLogin: funds.requiresLogin, unavailable: funds.unavailable) { Task { await load() } } }
            }
            Section {
                // R11-PC-D-1: same 暂无提现权限 gate + CS popup as the quick row (MP earnings/index.js:61-76).
                if WalletPayoutCapability.isOn { NavigationLink("withdrawal.support.title") { WalletWithdrawPermissionGate() }.accessibilityIdentifier("wallet.assets.withdraw") }
                NavigationLink("wallet.balanceLedger") { WalletLedgerView(reader: reader, kind: .balance) }
                    .accessibilityIdentifier("wallet.assets.balanceLedger")
                NavigationLink("wallet.pointsLedger") { WalletLedgerView(reader: reader, kind: .assetPoints) }
                    .accessibilityIdentifier("wallet.assets.pointsLedger")
            }
        }.appNavigationTitle("wallet.assets").navigationBarTitleDisplayMode(.inline).cyHideTabBar().task(id: reader.scope) { funds.clear(); await load() }
            .onChange(of: funds.loading) { _, isLoading in
                if WalletLoadAnnouncement.shouldAnnounce(wasLoading: true, isLoading: isLoading, hasValue: funds.value != nil) {
                    AccessibilityNotification.Announcement(WalletLoadAnnouncement.text(locale: locale)).post()
                }
            }
            .onDisappear { funds.cancel() }.refreshable { await load() }
            .appSwitcherPrivacyShield()
            .cyDomainScreen(.player)
    }
    private func load() async { await funds.load(reader) { try await $0.stages(token: $1) } }
}
@MainActor private final class WalletPagerScreen: ObservableObject {
    @Published var revision = 0
    private(set) var pager = WalletLedgerPager()
    func reset() { pager.reset(); revision += 1 }
    func cancel() { pager.cancel(); revision += 1 }
    func load(_ reader: WalletCommerceReader, kind: WalletLedgerKind) async {
        revision += 1; await pager.load(reader: reader, kind: kind); revision += 1
    }
    /// FIN-18-2: MP points-history load(fromPull) reads into a fresh page and swaps it in on success. A retryable
    /// failure over loaded rows keeps them and returns false (the page toasts 刷新失败，稍后再试); a sign-in or
    /// availability failure still retires the rows, as the pager does.
    func refresh(_ reader: WalletCommerceReader, kind: WalletLedgerKind) async -> Bool {
        guard pager.hasLoadedPage, !pager.rows.isEmpty else { reset(); await load(reader, kind: kind); return true }
        let fresh = WalletLedgerPager()
        revision += 1
        await fresh.load(reader: reader, kind: kind)
        if Task.isCancelled { return true }
        if fresh.hasLoadedPage && !fresh.failed || fresh.requiresLogin || fresh.unavailable {
            pager.cancel(); pager = fresh; revision += 1
            return true
        }
        revision += 1
        return !fresh.failed
    }
}
/// Continuity r1 (10): true when the ledger was pushed with a zoom out of a balance card, so the balance header arrives
/// with the zoom and the history fades in after its midpoint. Default false: every other entry is unchanged.
private struct WalletLedgerZoomArrivalKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var walletLedgerZoomArrival: Bool {
        get { self[WalletLedgerZoomArrivalKey.self] }
        set { self[WalletLedgerZoomArrivalKey.self] = newValue }
    }
}

@MainActor struct WalletLedgerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.walletLedgerZoomArrival) private var zoomArrival
    @QuestifyReduceMotion private var reduceMotion
    @State private var historyArrived = false
    /// The zoom only runs on iOS 18 without Reduce Motion; anywhere else the history is there from the first frame.
    private var historyWaitsForZoom: Bool {
        guard zoomArrival, !reduceMotion else { return false }
        if #available(iOS 18.0, *) { return true } else { return false }
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    let kind: WalletLedgerKind
    @StateObject private var model = WalletPagerScreen()
    @State private var direction = "all"
    @State private var incomeDetail: WalletIncomeDetailSelection?
    /// FIN-18-8: MP points-history reveals the full list 20 rows at a time (rows.js PAGE_SIZE).
    @State private var shownCount = WalletLedgerView.pointsPageSize
    @State private var refreshToast: LocalizedStringKey?
    static let pointsPageSize = 20
    private var points: Bool { kind == .points || kind == .assetPoints }
    private var shownRows: [WalletLedgerRow] { points ? Array(filtered.prefix(shownCount)) : filtered }
    private var hasLocalMore: Bool { points && shownCount < filtered.count }
    private var income: Bool { if case .income = kind { return true }; return false }
    private var filtered: [WalletLedgerRow] {
        model.pager.rows.filter { row in
            direction == "all" || (income ? row.incomeDirection : row.assetDirection).rawValue == direction
        }
    }
    var body: some View {
        List {
            balanceHero
            // Everything below the balance header exists only at the end of the zoom: it fades in from about 50% of it.
            Group {
            // R7-PC-D4-3: 收益明细 has one filter row (全部 / 创作 / 品牌); no second 收入 / 支出 picker.
            if !income && !(points && model.pager.hasLoadedPage && model.pager.rows.isEmpty) {
            Picker("wallet.direction", selection: $direction) {
                // Source points-history chips read 全部 / 获得 / 使用; money ledgers keep 收入 / 支出.
                Text("wallet.all").tag("all")
                Text(points ? "u9cde.points.earned" : "wallet.inflow").tag("income")
                Text(points ? "u9cde.points.used" : "wallet.outflow").tag("expense")
            }.pickerStyle(.segmented)
            }
            if points { NavigationLink("wallet.tasks") { WalletPointsTasksView(reader: reader) } }
            if model.pager.hasLoadedPage && model.pager.loadedScope == reader.scope {
                if filtered.isEmpty && !model.pager.isLoading && !model.pager.failed {
                    if income || points {
                        ContentUnavailableView(LocalizedStringKey(WalletPointsLedgerEmptyState.key(direction: direction, isIncomeLedger: income, isPointsLedger: points)), systemImage: "tray")
                            .accessibilityIdentifier("wallet.ledger.empty")
                    } else {
                        Text(LocalizedStringKey(WalletPointsLedgerEmptyState.key(direction: direction, isIncomeLedger: income, isPointsLedger: points))).accessibilityIdentifier("wallet.ledger.empty")
                    }
                }
                if points || kind == .balance {
                    ForEach(WalletPointsMonthGroup.group(shownRows)) { group in
                        Text(verbatim: group.headerText(isEnglish: locale.language.languageCode?.identifier == "en"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("wallet.ledger.monthGroup.\(group.id)")
                        ForEach(group.rows) { row in ledgerRowButton(row) }
                    }
                } else {
                    ForEach(WalletIncomeDay.group(filtered)) { group in
                        Text(verbatim: group.headerText(isEnglish: locale.language.languageCode?.identifier == "en"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("wallet.ledger.dateGroup.\(group.id)")
                        ForEach(group.rows) { row in ledgerRowButton(row) }
                    }
                }
                // FIN-18-8: 已经到底了 only once the list was paged (more than one page of 20), as MP `paged`.
                if points && filtered.count > Self.pointsPageSize && !hasLocalMore && !model.pager.hasMore && !model.pager.isLoading && !model.pager.failed {
                    Text("wallet.points.endOfList").font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("wallet.ledger.endOfList")
                }
            }
            if points && !model.pager.hasLoadedPage && !model.pager.isLoading && !model.pager.failed && reader.isConfigured && reader.scope != nil {
                // No page accepted yet and no failure: unknown, never an empty ledger.
                Text(verbatim: PointsHistoryPageModel.unknownMark).foregroundStyle(.secondary)
                    .accessibilityIdentifier(PointsHistoryPageModel.unknownIdentifier)
            }
            if model.pager.failed || !reader.isConfigured || reader.scope == nil {
                WalletIssueView(reader: reader, requiresLogin: model.pager.requiresLogin, unavailable: model.pager.unavailable,
                                failedKey: points ? "wallet.points.failed" : income ? "wallet.income.loadFailed" : "wallet.failed",
                                loginKey: income ? "wallet.income.signInRequired" : nil,
                                deniedKey: income ? "wallet.income.denied" : nil) { Task { await model.load(reader, kind: kind) } }
            }
            if model.pager.isLoading {
                if income { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("wallet.loading")) }
                else { ProgressView().frame(maxWidth: .infinity) }
            }
            else if hasLocalMore && model.pager.hasLoadedPage && reader.isConfigured && reader.scope != nil {
                Button("wallet.loadMore") { shownCount += Self.pointsPageSize }
                    .accessibilityIdentifier("wallet.ledger.loadMore")
            }
            else if model.pager.hasLoadedPage && model.pager.hasMore && !model.pager.failed && reader.isConfigured && reader.scope != nil {
                Button("wallet.loadMore") { Task { await model.load(reader, kind: kind) } }
                    .accessibilityIdentifier("wallet.ledger.loadMore")
                    // R7-PC-D4-4 (MP income-detail.js:39-42 onReachBottom): the next page loads when the end scrolls in;
                    // the button stays as the fallback.
                    .onAppear { if income, !model.pager.isLoading { Task { await model.load(reader, kind: kind) } } }
            }
            }
            .opacity(historyArrived || !historyWaitsForZoom ? 1 : 0)
        }
            .onAppear {
                guard historyWaitsForZoom, !historyArrived else { return }
                withAnimation(.easeOut(duration: CYMotion.Duration.quick).delay(0.25)) { historyArrived = true }
            }
            .appNavigationTitle(key: income ? "wallet.income" : points ? "wallet.pointsLedger" : "wallet.balanceLedger").navigationBarTitleDisplayMode(.inline)
            .cyHideTabBar()
            .task(id: reader.scope) { model.reset(); await model.load(reader, kind: kind) }
            .onDisappear { if incomeDetail == nil { model.cancel() } }
            .refreshable {
                incomeDetail = nil
                if await model.refresh(reader, kind: kind) { shownCount = Self.pointsPageSize }
                else { refreshToast = "profile.refreshFailed" }
            }
            .cyToast(message: $refreshToast, tone: .warning)
            .onChange(of: reader.scope) { _, _ in incomeDetail = nil; shownCount = Self.pointsPageSize }
            .onChange(of: direction) { _, _ in incomeDetail = nil; shownCount = Self.pointsPageSize }
            .onChange(of: scenePhase) { _, phase in if phase != .active { incomeDetail = nil } }
            .appSwitcherPrivacyShield()
            .cySheet(item: $incomeDetail) { selection in
                NavigationStack {
                    List {
                        if let row = (income ? model.pager.incomeDetailRow(selection, reader: reader) : model.pager.ledgerTransactionDetailRow(selection, reader: reader)) {
                            Section { ledgerRow(row) }
                            Section {
                                LabeledContent {
                                    Text(verbatim: "#\(row.id)")
                                } label: {
                                    Text(verbatim: appLocalized("wallet.ledger.referenceID", locale: locale))
                                }
                                if let createTime = row.createTime, !createTime.isEmpty {
                                    LabeledContent {
                                        Text(verbatim: createTime)
                                    } label: {
                                        Text(verbatim: appLocalized("wallet.ledger.timestamp", locale: locale))
                                    }
                                }
                            }
                        } else {
                            Text(LocalizedStringKey(reader.scope == nil ? "wallet.login" : "wallet.failed"))
                                .accessibilityIdentifier("wallet.income.detail.retired")
                        }
                    }
                    .privacySensitive()
                    .appNavigationTitle("wallet.income").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button("action.close") { incomeDetail = nil }
                            .accessibilityIdentifier("wallet.income.detail.close")
                    } }
                    .accessibilityIdentifier("wallet.income.detail")
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
    /// Large balance hero (points or money). Unknown stays an em dash, never zero.
    @ViewBuilder private var balanceHero: some View {
        if !income, model.pager.hasLoadedPage, model.pager.loadedScope == reader.scope {
            let first = model.pager.rows.first
            let value = points ? first?.afterPoints : first?.afterBalance
            let unit = points ? format.pointsUnit(for: value) : (first?.currency ?? "")
            VStack(alignment: .leading, spacing: 4) {
                Text(points ? "wallet.pointsBalance" : "wallet.balanceLedger")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: value.map { points ? WalletNumberLocalization.text($0.text, locale: locale) : WalletNumberLocalization.money($0.text, locale: locale) } ?? "—")
                        .cyText(.data2XL, monospacedDigit: true)
                        .fixedSize(horizontal: false, vertical: true)
                    if value != nil { Text(verbatim: unit).font(.headline).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .accessibilityIdentifier("wallet.ledger.hero")
        }
    }
    @ViewBuilder private func ledgerRowButton(_ row: WalletLedgerRow) -> some View {
        if points {
            // FIN-18-4: MP 积分明细 rows are plain records, with no detail sheet.
            ledgerRow(row).accessibilityElement(children: .combine)
                .accessibilityIdentifier("wallet.ledger.row.\(row.id)")
        } else {
        Button {
            incomeDetail = income ? model.pager.incomeDetail(rowID: row.id, reader: reader)
                                  : model.pager.ledgerTransactionDetail(rowID: row.id, reader: reader)
        } label: {
            HStack {
                ledgerRow(row)
                Spacer()
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(income ? "wallet.income.detail.open.\(row.id)" : "wallet.ledger.detail.open.\(row.id)")
        }
    }
    /// Mini-program 积分明细 row: reason and time on the left, signed amount on the right.
    private func ledgerRow(_ row: WalletLedgerRow) -> some View {
        let direction = income ? row.incomeDirection : row.assetDirection
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        let isIn = direction.rawValue == "income"
        return layout {
            if !stacked {
                Image(systemName: isIn ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isIn ? Color.green : Color.secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if income, let badge = WalletReadFailurePresentation.incomeSourceBadge(for: row) {
                        Text(verbatim: badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("wallet.income.badge.\(row.id)")
                    }
                    Text(verbatim: row.changeReason ?? (points ? appLocalized("wallet.points.entryFallback", locale: locale) : appLocalized("wallet.entry", locale: locale)))
                }
                if income { Text(LocalizedStringKey(row.incomeEventKey)).font(.subheadline).foregroundStyle(.secondary) }
                if income, let day = WalletIncomeDay.make(row.createTime) { WalletIncomeDayText(day: day).font(.footnote).foregroundStyle(.secondary) }
                else if let date = row.createTime {
                    // FIN-18-6: MP rows.js shortTimeText (10月27日 10:30); the month is already the group title.
                    Text(verbatim: points ? WalletPointsShortTime.text(date, isEnglish: locale.language.languageCode?.identifier == "en") : date)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if points, !income { Text(verbatim: appLocalized("wallet.points.balanceAfter", locale: locale) + " " + (row.afterPoints.map { format.points($0) } ?? PointsHistoryPageModel.unknownMark)).font(.footnote).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            VStack(alignment: stacked ? .leading : .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Text(verbatim: format.signed(row, points: points, income: income))
                    if points, row.changePoints != nil { Text(verbatim: format.pointsUnit(for: row.changePoints)) }
                    else if !points { Text(verbatim: row.currency ?? appLocalized("wallet.currencyUnknown", locale: locale)) }
                }
                .font(.body.weight(.medium)).monospacedDigit()
                // FIN-18-8: MP `.is-income` uses the brand colour on 积分明细 (the system accent).
                .foregroundStyle(isIn ? (points ? Color.accentColor : Color.green) : Color.primary)
                if !points, let balance = row.afterBalance {
                    Text(verbatim: format.amount(balance, currency: row.currency)).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(LocalizedStringKey("wallet.direction." + direction.rawValue)))
        .accessibilityIdentifier("wallet.ledger.\(row.id)")
    }
}

@MainActor struct WalletIncomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    let reader: WalletCommerceReader
    let onCooperationFinance: () -> Void
    var showsCooperationFinance = true
    var organizerFinance: WalletOrganizerFinanceAccess? = nil
    /// R7-PC-D4-5 (MP income-detail.js:15-18 `theme=merchant`): merchant chrome, and no 分佣 tabs.
    var merchantView = false
    @State private var filter = WalletIncomeFilter.all
    @State private var hold = WalletEarningsTabHold()
    /// R7-PC-D4-2 (MP income-detail.wxml:14-18): 收益 / 分佣 tabs while the server has an own allocation projection.
    @Environment(\.g6Capabilities) private var g6
    @State private var revenue = G6RevenueAllocationsModel()
    @State private var showsAllocations = false
    #if DEBUG
    @StateObject private var debugFinance = WalletEarningsDebugFinance()
    @StateObject private var debugStages = WalletScreen<WalletFundsStages>()
    #endif
    private var financeAccess: WalletOrganizerFinanceAccess? {
        #if DEBUG
        if WalletEarningsDebugFinance.enabled { return debugFinance.access }
        #endif
        // R7-PC-D4-1 (P1): no coop-finance read grant means no 主办分润 tab at all, never a tab that can only show "—".
        guard let organizerFinance, organizerFinance.allowsRead() else { return nil }
        return organizerFinance
    }
    private var showIncome: Bool { financeAccess == nil || hold.tab == .income }
    var body: some View {
        VStack(spacing: 0) {
            if financeAccess != nil {
                WalletEarningsTabBar(tab: hold.tab) { hold.select($0) }
                #if DEBUG
                if WalletEarningsDebugFinance.enabled {
                    Text(verbatim: String(debugFinance.financeReads))
                        .accessibilityIdentifier("wallet.earnings.finance.reads")
                    WalletFundsStagesInline(reader: reader, funds: debugStages) { Task { await loadDebugStages() } }
                }
                #endif
            }
            ZStack {
                incomeBody
                    .opacity(showIncome ? 1 : 0)
                    .allowsHitTesting(showIncome)
                    .accessibilityHidden(!showIncome)
                    .zIndex(showIncome ? 1 : 0)
                // ponytail: finance stays mounted across tab switches so the finance task does not restart; background drops it.
                if let access = financeAccess, hold.mounted {
                    WalletOrganizerFinancePane(access: access, mounted: hold.mounted)
                        .opacity(hold.tab == .organizer ? 1 : 0)
                        .allowsHitTesting(hold.tab == .organizer)
                        .accessibilityHidden(hold.tab != .organizer)
                        .zIndex(hold.tab == .organizer ? 1 : 0)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.appNavigationTitle("wallet.income").navigationBarTitleDisplayMode(.inline).themeDomain(merchantView ? .merchant : .player).cyHideTabBar()
            .onChange(of: scenePhase) { _, phase in
                guard financeAccess != nil else { return }
                if phase != .active { hold.background() } else { hold.foreground() }
            }
            #if DEBUG
            .task(id: reader.scope) {
                guard WalletEarningsDebugFinance.enabled else { return }
                debugStages.clear(); await loadDebugStages()
            }
            #endif
            .appSwitcherPrivacyShield()
    }
    private var showsRevenueTabs: Bool {
        if merchantView { return false }
        if case .hidden = revenue.state { return false }
        return true
    }
    private var incomeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsRevenueTabs {
                Picker("wallet.income", selection: $showsAllocations) {
                    Text("wallet.income.tab.income").tag(false)
                    Text("g6.revenue.tab").tag(true)
                }
                .pickerStyle(.segmented).padding(.horizontal).padding(.top)
                .accessibilityIdentifier("wallet.income.revenueTabs")
            }
            ZStack(alignment: .top) {
                // MP L09-121: the income list stays mounted while 分佣 is shown, so switching back keeps its pages.
                incomeLedger
                    .opacity(showsAllocations && showsRevenueTabs ? 0 : 1)
                    .allowsHitTesting(!(showsAllocations && showsRevenueTabs))
                    .accessibilityHidden(showsAllocations && showsRevenueTabs)
                if showsAllocations && showsRevenueTabs { allocationsPane }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: merchantView) { if !merchantView { await revenue.load(g6) } }
    }
    @ViewBuilder private var allocationsPane: some View {
        switch revenue.state {
        case .ready(let rows): G6RevenueAllocationsView(rows: rows)
        case .error:
            ContentUnavailableView {
                Label("g6.revenue.unavailable", systemImage: "exclamationmark.circle")
            } actions: {
                Button("action.retry") { Task { await revenue.load(g6) } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("g6.revenue.retry")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default: EmptyView()
        }
    }
    private var incomeLedger: some View {
        VStack(alignment: .leading, spacing: 12) {
            // PC-D-4-3 (MC-41): 收益明细 is drawn once, by the bar; no second in-content title.
            Picker("wallet.income", selection: $filter) {
                Text("wallet.all").tag(WalletIncomeFilter.all)
                Text("wallet.creationIncome").tag(WalletIncomeFilter.create)
                Text("wallet.brandIncome").tag(WalletIncomeFilter.brand)
            }.pickerStyle(.segmented).padding()
            if financeAccess == nil, showsCooperationFinance {
                Button(action: onCooperationFinance) {
                    Text("wallet.clubFinance").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
                .padding(.horizontal)
            }
            WalletLedgerView(reader: reader, kind: .income(filter)).id(filter.rawValue)
        }
    }
    #if DEBUG
    private func loadDebugStages() async {
        guard WalletEarningsDebugFinance.enabled else { return }
        await debugStages.load(reader) { try await $0.stages(token: $1) }
    }
    #endif
}
@MainActor struct WalletProductsView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    @StateObject private var model = WalletScreen<WalletPage<WalletProduct>>()
    @State private var keyword = ""
    @State private var submittedKeyword = ""
    @State private var sort = 0
    @State private var isVisible = false
    @State private var pendingLoad: Task<Void, Never>?
    var body: some View {
        List {
            NavigationLink("wallet.cart") { WalletCartView(reader: reader) }
            Picker("wallet.sort", selection: $sort) {
                ForEach(0..<5) { value in Text(LocalizedStringKey("wallet.sort." + String(value))).tag(value) }
            }.onChange(of: sort) { _, _ in scheduleLoad() }
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            else if let page = model.value, model.loadedScope == reader.scope {
                if page.rows.isEmpty { Text("wallet.empty") }
                ForEach(page.rows) { item in
                    NavigationLink { WalletProductView(reader: reader, productID: item.id) } label: {
                        VStack(alignment: .leading) {
                            Text(verbatim: item.productName ?? appLocalized("wallet.product", locale: locale))
                            Text(format.points(item.price)).font(.subheadline).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                }
                if let total = page.total, total > page.rows.count { Text("wallet.sourceLimited") }
            } else if model.failed || !reader.isConfigured || reader.scope == nil {
                WalletIssueView(reader: reader, requiresLogin: model.requiresLogin, unavailable: model.unavailable) { scheduleLoad() }
            } else {
                // An interrupted read is retryable, not a reported business failure.
                Button("wallet.retry") { scheduleLoad() }.frame(minHeight: 44)
            }
        }.appNavigationTitle("wallet.mall").navigationBarTitleDisplayMode(.inline).cyHideTabBar().searchable(text: $keyword)
            .onSubmit(of: .search) { submitSearch() }
            .onChange(of: keyword) { _, value in
                // Clearing or cancelling search must restore the unfiltered catalogue.
                guard value.isEmpty, !submittedKeyword.isEmpty else { return }
                submitSearch()
            }
            .task(id: reader.scope) {
                guard !Task.isCancelled else { return }
                pendingLoad?.cancel()
                isVisible = true
                model.clear()
                await load()
            }
            .onDisappear {
                isVisible = false
                pendingLoad?.cancel()
                model.cancel()
            }.refreshable {
                guard isVisible, !Task.isCancelled else { return }
                pendingLoad?.cancel()
                await load()
            }
        .cyDomainScreen(.player)
    }
    private func submitSearch() {
        submittedKeyword = keyword
        scheduleLoad()
    }
    private func scheduleLoad() {
        guard isVisible else { return }
        pendingLoad?.cancel()
        // Retire old results synchronously, without painting an interim failure.
        model.clear()
        model.markLoading()
        let scope = reader.scope
        pendingLoad = Task {
            guard !Task.isCancelled, isVisible, scope == reader.scope else { return }
            await load()
        }
    }
    private func load() async {
        guard isVisible, !Task.isCancelled else { return }
        // Draft edits do not change refresh, retry, or sorting until submitted.
        let search = submittedKeyword; let order = sort
        await model.load(reader) { try await $0.products(sortType: order, keyword: search, token: $1) }
    }
}
@MainActor struct WalletProductView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    let productID: Int
    @StateObject private var model = WalletScreen<WalletProduct>()
    var body: some View {
        List {
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            else if let item = model.value, model.loadedScope == reader.scope {
                Text(verbatim: item.productName ?? appLocalized("wallet.product", locale: locale)).font(.title3.bold())
                LabeledContent("wallet.price", value: format.points(item.price))
                LabeledContent("wallet.stock", value: format.count(item.stock))
                ForEach(item.skuList ?? []) { sku in
                    VStack(alignment: .leading) {
                        Text(verbatim: sku.skuName ?? appLocalized("wallet.sku", locale: locale))
                        Text(format.points(sku.price))
                        LabeledContent("wallet.stock", value: format.count(sku.stock))
                    }.accessibilityElement(children: .combine)
                }
                if let html = item.detailHtml {
                    // Plain accessible text only: never execute HTML or load remote resources.
                    Text(verbatim: html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression))
                }
                Text("wallet.dormant").accessibilityIdentifier("wallet.dormant")
            } else { WalletIssueView(reader: reader, requiresLogin: model.requiresLogin) { Task { await load() } } }
        }.appNavigationTitle("wallet.product").navigationBarTitleDisplayMode(.inline).cyHideTabBar().task(id: reader.scope) { model.clear(); await load() }.onDisappear { model.cancel() }
        .cyDomainScreen(.player)
    }
    private func load() async { await model.load(reader) { try await $0.product(id: productID, token: $1) } }
}
@MainActor struct WalletCartView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    @StateObject private var model = WalletScreen<WalletPage<WalletCartItem>>()
    @State private var selected = Set<Int>()
    var body: some View {
        List {
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            else if let page = model.value, model.loadedScope == reader.scope {
                if page.rows.isEmpty { ContentUnavailableView("wallet.empty", systemImage: "cart") }
                ForEach(page.rows) { item in
                    Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { yes in
                        if yes { selected.insert(item.id) } else { selected.remove(item.id) }
                    })) {
                        VStack(alignment: .leading) {
                            Text(verbatim: item.productName ?? appLocalized("wallet.product", locale: locale))
                            Text(format.points(item.price))
                            LabeledContent("wallet.quantity", value: format.count(item.quantity))
                            LabeledContent("wallet.subtotal", value: format.points(item.subtotalPoints.map(WalletAmount.init)))
                        }
                    }.accessibilityIdentifier("wallet.cart.\(item.id)")
                }
                if !selected.isEmpty {
                    NavigationLink("wallet.preview") { WalletCheckoutView(reader: reader, cartIDs: selected.sorted()) }
                }
                if let total = page.total, total > page.rows.count { Text("wallet.sourceLimited") }
                Text("wallet.dormant")
            } else { WalletIssueView(reader: reader, requiresLogin: model.requiresLogin) { Task { await load() } } }
        }.appNavigationTitle("wallet.cart").navigationBarTitleDisplayMode(.inline).cyHideTabBar().task(id: reader.scope) { selected = []; model.clear(); await load() }
            .onDisappear { model.cancel() }.refreshable { selected = []; await load() }
        .cyDomainScreen(.player)
    }
    private func load() async { await model.load(reader) { try await $0.cart(token: $1) } }
}
@MainActor struct WalletCheckoutView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    let cartIDs: [Int]
    @StateObject private var model = WalletScreen<WalletCheckoutPreview>()
    var body: some View {
        List {
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            else if let preview = model.value, model.loadedScope == reader.scope {
                LabeledContent("wallet.productAmount", value: format.points(preview.productAmount))
                LabeledContent("wallet.deliveryFee", value: format.points(preview.deliveryFee))
                LabeledContent("wallet.taxFee", value: format.points(preview.taxFee))
                LabeledContent("wallet.total", value: format.points(preview.totalAmount))
                LabeledContent("wallet.requiredPoints", value: format.points(preview.requiredPoints.map(WalletAmount.init)))
                LabeledContent("wallet.pointsBalance", value: format.points(preview.pointBalance))
                if let enough = preview.hasEnoughPoints { Text(LocalizedStringKey(enough ? "wallet.sufficient" : "wallet.insufficient")) }
                else { Text("wallet.balanceUnknown") }
                if let address = preview.address {
                    LabeledContent("wallet.addressReference", value: String(address.id))
                    if let phone = address.maskedPhone { Text(verbatim: phone) }
                } else { Text("wallet.addressMissing") }
                Text("wallet.previewOnly").accessibilityIdentifier("wallet.previewOnly")
                Text("wallet.dormant")
            } else { WalletIssueView(reader: reader, requiresLogin: model.requiresLogin) { Task { await load() } } }
        }.appNavigationTitle("wallet.preview").navigationBarTitleDisplayMode(.inline).cyHideTabBar().task(id: reader.scope) { model.clear(); await load() }.onDisappear { model.cancel() }
        .cyDomainScreen(.player)
    }
    private func load() async { await model.load(reader) { try await $0.checkout(cartIDs: cartIDs, token: $1) } }
}
@MainActor struct WalletWithdrawalsView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    var showsSupportContact = true
    @StateObject private var model = WalletScreen<WalletPage<WalletWithdrawalRecord>>()
    @State private var showContact = false
    var body: some View {
        List {
            Label("bank.withdrawal.historyNotice", systemImage: "info.circle")
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            else if let page = model.value, model.loadedScope == reader.scope {
                if page.rows.isEmpty { ContentUnavailableView("wallet.withdrawals.emptyTitle", systemImage: "tray").accessibilityIdentifier("wallet.withdrawals.empty") }
                ForEach(page.rows) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("wallet.withdrawal.rowTitle").font(.headline)
                        Text(format.amount(item.amount, currency: item.currency)).monospacedDigit()
                        Text(LocalizedStringKey(item.statusKey)).font(.subheadline).foregroundStyle(.secondary)
                        if let received = item.receivedAmount {
                            LabeledContent { Text(verbatim: format.amount(received, currency: item.currency)) } label: {
                                Text("member.wallet.received", tableName: "MemberProfile")
                            }
                        }
                        if let date = item.createTime { Text(verbatim: date).font(.footnote).foregroundStyle(.secondary) }
                        if let account = item.maskedAccount { Text(verbatim: account).font(.footnote).foregroundStyle(.secondary) }
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("wallet.withdrawal.\(item.id)")
                }
                if let total = page.total, total > page.rows.count { Text("wallet.sourceLimited") }
            } else { WalletIssueView(reader: reader, requiresLogin: model.requiresLogin, unavailable: model.unavailable) { Task { await load() } } }
            if showsSupportContact {
                Section {
                    Button("withdrawal.support.contact") { showContact = true }
                        .accessibilityIdentifier("wallet.withdrawals.support")
                }
            }
        }.appNavigationTitle("wallet.withdrawals").navigationBarTitleDisplayMode(.inline).cyHideTabBar().task(id: reader.scope) { showContact = false; model.clear(); await load() }
            .onDisappear { model.cancel() }.refreshable { await load() }
            // Uses the inherited, independently reviewed support reader. History access
            // does not supply a contact or authorize support configuration/copying.
            .cySheet(isPresented: $showContact) {
                WithdrawalSupportContactView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .appSwitcherPrivacyShield()
            .cyDomainScreen(.player)
    }
    private func load() async { await model.load(reader) { try await $0.withdrawals(token: $1) } }
}

@MainActor struct WalletPointsTasksView: View {
    @Environment(\.locale) private var locale
    private var format: WalletFormatting { .init(locale: locale) }
    let reader: WalletCommerceReader
    @StateObject private var model = WalletScreen<[WalletPointsTask]>()
    var body: some View {
        List {
            if model.loading { ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("wallet.tasks.loading") }
            else if let rows = model.value, model.loadedScope == reader.scope {
                // OWN-D-01.a: earn rules, then eventType 14 as 「积分消耗」 (`mp:subpackageMember/components/cy/profile/index.wxml:658-686`).
                let rules = WalletPointsRules(rows)
                if rules.earn.isEmpty && rules.spend.isEmpty { Text("wallet.empty").accessibilityIdentifier("wallet.tasks.empty") }
                ForEach(rules.earn) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: item.title ?? appLocalized("wallet.entry", locale: locale))
                        if let description = item.description { Text(verbatim: description) }
                        Text(verbatim: item.value.map { format.points($0) } ?? PointsHistoryPageModel.unknownMark)
                        LabeledContent("wallet.doneCount", value: item.pointsNum == nil ? PointsHistoryPageModel.unknownMark : format.count(item.pointsNum))
                    }.accessibilityElement(children: .combine)
                }
                if !rules.spend.isEmpty {
                    Section("wallet.points.spendRules") {
                        ForEach(rules.spend) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: item.title ?? appLocalized("wallet.entry", locale: locale))
                                if let description = item.description { Text(verbatim: description) }
                                // The value is the server rule, per use; the client never writes in a number.
                                Text(verbatim: item.value.map { "−" + format.points($0) } ?? PointsHistoryPageModel.unknownMark)
                                LabeledContent("wallet.points.spendUsedCount", value: item.pointsNum == nil ? PointsHistoryPageModel.unknownMark : format.count(item.pointsNum))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("wallet.points.spendRule")
                        }
                    }
                }
            } else { WalletIssueView(reader: reader, requiresLogin: model.requiresLogin, unavailable: model.unavailable) { Task { await load() } } }
        }.appNavigationTitle("wallet.tasks").navigationBarTitleDisplayMode(.inline).cyHideTabBar().task(id: reader.scope) { model.clear(); await load() }.onDisappear { model.cancel() }
        .cyDomainScreen(.player)
    }
    private func load() async { await model.load(reader) { try await $0.pointsTasks(token: $1) } }
    @ViewBuilder private func pointsRuleRow(_ item: WalletPointsTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: item.title ?? appLocalized("wallet.entry", locale: locale))
            if let description = item.description { Text(verbatim: description) }
            Text(verbatim: item.value.map { format.points($0) } ?? PointsHistoryPageModel.unknownMark)
            LabeledContent("wallet.doneCount", value: item.pointsNum == nil ? PointsHistoryPageModel.unknownMark : format.count(item.pointsNum))
        }.accessibilityElement(children: .combine)
    }
}

/// Author revenue tab (OWN-D-10). Empty and non-participants hide the tab.
/// A failed read says 「收益暂不可用」 and never draws 0.
enum WalletAuthorRevenueTab {
    static let unavailable = OwnerDecisionRevenueGate.unavailable
    static func phase(readFailed: Bool, participant: Bool, isEmpty: Bool) -> OwnerDecisionRevenueGate.Phase {
        OwnerDecisionRevenueGate.phase(readFailed: readFailed, participant: participant, isEmpty: isEmpty)
    }
}

/// Wallet figures appear after a spinner; VoiceOver users get one generic announcement (never the amount, which is privacy sensitive).
enum WalletLoadAnnouncement {
    static func shouldAnnounce(wasLoading: Bool, isLoading: Bool, hasValue: Bool) -> Bool {
        wasLoading && !isLoading && hasValue
    }
    static func text(locale: Locale) -> String {
        ChannelCopy.text("钱包数据已更新", "Wallet figures updated", locale: locale)
    }
}

/// Quick action: a system bordered button with the SF Symbol over a short label (the Contacts action-button pattern).
/// The primary action is `.borderedProminent` (one per screen); the rest are `.bordered`.
private struct WalletQuickAction: View {
    let title: LocalizedStringKey
    let icon: String
    let id: String
    var isPrimary = false
    var destination: (() -> AnyView)?
    var action: (() -> Void)?
    init(title: LocalizedStringKey, icon: String, id: String, destination: @escaping () -> AnyView) {
        self.title = title; self.icon = icon; self.id = id; self.destination = destination
    }
    init(title: String, icon: String, id: String, action: @escaping () -> Void) {
        self.title = LocalizedStringKey(title); self.icon = icon; self.id = id; self.action = action
    }
    func primary(_ on: Bool) -> Self { var copy = self; copy.isPrimary = on; return copy }
    private var label: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).accessibilityHidden(true)
            Text(title).font(.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }
    @ViewBuilder private var control: some View {
        if let destination { NavigationLink { destination() } label: { label }.questifyHidesLinkIndicator() }
        else { Button { action?() } label: { label } }
    }
    var body: some View {
        Group {
            if isPrimary { control.buttonStyle(.borderedProminent) }
            else { control.buttonStyle(.bordered) }
        }
        .accessibilityIdentifier(id)
    }
}
extension WalletQuickAction: Identifiable {}

enum WalletCurrencySymbol {
    /// nil only when the currency is truly unknown (nil/blank); a known code without a glyph shows the code.
    static func symbol(_ currency: String?) -> String? {
        guard let code = currency?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !code.isEmpty else { return nil }
        switch code {
        case "CNY", "RMB": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return code
        }
    }
}

/// Centered earnings hero: grey label above a large tabular amount. An unknown currency shows a small grey dash in the symbol slot.
private struct WalletEarningsHero: View {
    let label: String
    let number: String
    let symbol: String?
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let symbol {
                    Text(symbol).font(.title.bold())
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.secondary).padding(.trailing, 4)
                        .accessibilityLabel(Text(verbatim: ""))
                }
                Text(number).cyText(.data2XL, monospacedDigit: true)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// FIN-18-6: MP points-history rows.js `shortTimeText`: `YYYY-MM-DD HH:MM…` → `M月D日 HH:MM`; anything else verbatim.
enum WalletPointsShortTime {
    static func text(_ value: String, isEnglish: Bool = false) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let chars = Array(text)
        guard chars.count >= 16, chars[4] == "-", chars[7] == "-", chars[10] == " " || chars[10] == "T", chars[13] == ":",
              let month = Int(String(chars[5...6])), let day = Int(String(chars[8...9])),
              (1...12).contains(month), (1...31).contains(day),
              chars[11...12].allSatisfy(\.isNumber), chars[14...15].allSatisfy(\.isNumber) else { return text }
        let time = String(chars[11...15])
        return isEnglish ? "\(month)/\(day) \(time)" : "\(month)月\(day)日 \(time)"
    }
}

/// R9-PC-D5-1: MP assetcenter/earnings/index.js:61-76 opens the 提现 customer-service popup only when role/info
/// `permission.withdrawable` is true; otherwise it says 暂无提现权限. No write either way.
private struct WalletWithdrawPermissionKey: EnvironmentKey {
    static let defaultValue: (@MainActor () async throws -> Bool?)? = nil
}
extension EnvironmentValues {
    /// nil result: role/info is not readable here, so the page keeps the plain contact view.
    var walletWithdrawPermission: (@MainActor () async throws -> Bool?)? {
        get { self[WalletWithdrawPermissionKey.self] }
        set { self[WalletWithdrawPermissionKey.self] = newValue }
    }
}

@MainActor struct WalletWithdrawPermissionGate: View {
    @Environment(\.walletWithdrawPermission) private var readPermission
    private enum Phase: Equatable { case loading, allowed, denied, failed }
    @State private var phase: Phase = .loading
    var body: some View {
        Group {
            switch phase {
            case .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .allowed: WithdrawalSupportContactView()
            case .denied:
                ContentUnavailableView("wallet.withdraw.noPermission", systemImage: "lock")
                    .accessibilityIdentifier("wallet.withdraw.noPermission")
            case .failed:
                ContentUnavailableView {
                    Label("wallet.withdraw.permissionFailed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("action.retry") { Task { await load() } }.buttonStyle(.bordered)
                }
            }
        }
        .task { await load() }
    }
    private func load() async {
        guard let readPermission else { phase = .allowed; return }
        phase = .loading
        do {
            switch try await readPermission() {
            case .some(true), .none: phase = .allowed
            case .some(false): phase = .denied
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}
