import SwiftUI

// Mounts the existing bundle screens. Payment, payout, withdrawal, virtual goods,
// purchase, and refund apply stay unmounted. A missing capability removes the row.

private struct BundleCommerceBaseURLKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

extension EnvironmentValues {
    var bundleCommerceBaseURL: URL? {
        get { self[BundleCommerceBaseURLKey.self] }
        set { self[BundleCommerceBaseURLKey.self] = newValue }
    }
}

enum BundleCommerceEntry: String, CaseIterable, Identifiable {
    case shelf
    case orderStatus
    case voucher
    case refundQuote
    case cancel
    case exitSwap
    case transfer
    case review
    case renewal
    case appeal

    var id: String { rawValue }

    var route: String {
        switch self {
        case .shelf: return "/api/free-explore/bundle/shelf"
        case .orderStatus: return "/api/free-explore/bundle/order"
        case .voucher: return "/api/free-explore/bundle/voucher"
        case .refundQuote: return "/api/free-explore/bundle/order/refund-quote"
        case .cancel: return "/api/free-explore/bundle/reservation/{}/cancel-quote"
        case .exitSwap: return "/api/free-explore/bundle/exit-options"
        case .transfer: return "/api/free-explore/bundle/transfer"
        case .review: return "/api/free-explore/bundle/review"
        case .renewal: return "/api/free-explore/bundle/renewal-intent"
        case .appeal: return "/api/free-explore/bundle/voucher/appeal"
        }
    }

    var identifier: String {
        switch self {
        case .shelf: return "bundle.commerce.shelf"
        case .orderStatus: return "bundle.commerce.order"
        case .voucher: return "bundle.commerce.voucher"
        case .refundQuote: return "bundle.commerce.refundQuote"
        case .cancel: return "bundle.commerce.cancel"
        case .exitSwap: return "bundle.commerce.exitSwap"
        case .transfer: return "bundle.commerce.transfer"
        case .review: return "bundle.commerce.review"
        case .renewal: return "bundle.commerce.renewal"
        case .appeal: return "bundle.commerce.appeal"
        }
    }

    func title(_ locale: Locale) -> String {
        switch self {
        case .shelf: return ChannelCopy.text("套餐", "Shelf", locale: locale)
        case .orderStatus: return ChannelCopy.text("订单状态", "Order status", locale: locale)
        case .voucher: return ChannelCopy.text("核销码", "Voucher", locale: locale)
        case .refundQuote: return ChannelCopy.text("可退金额", "Refund quote", locale: locale)
        case .cancel: return ChannelCopy.text("取消预约", "Cancel reservation", locale: locale)
        case .exitSwap: return ChannelCopy.text("更换商家", "Swap merchant", locale: locale)
        case .transfer: return ChannelCopy.text("转赠", "Transfer", locale: locale)
        case .review: return ChannelCopy.text("评价", "Reviews", locale: locale)
        case .renewal: return ChannelCopy.text("续期意向", "Renewal intent", locale: locale)
        case .appeal: return ChannelCopy.text("申诉", "Appeal", locale: locale)
        }
    }
}

enum BundleCommerceCatalog {
    /// Purchase, pay, payout, withdrawal, and virtual goods are not entries.
    static var mountsMoneyActions: Bool { false }

    static func shows(_ entry: BundleCommerceEntry, baseURL: URL?) -> Bool {
        guard !mountsMoneyActions else { return false }
        let route = entry.route
        if ReleaseMoneyWriteSwitch.blocks(route) { return false }
        if ChinaReviewedRouteCapability.forcedOff(route) != nil { return false }
        return ChinaReviewedRouteCapability.offersFeature(route, baseURL: baseURL)
    }

    static func visible(baseURL: URL?, capabilityAvailable: Bool) -> [BundleCommerceEntry] {
        guard capabilityAvailable else { return [] }
        return BundleCommerceEntry.allCases.filter { shows($0, baseURL: baseURL) }
    }
}

enum BundleCommerceCopy {
    static let unknownMark = "—"

    static func hub(_ locale: Locale) -> String { ChannelCopy.text("套餐", "Bundle", locale: locale) }
    static func retry(_ locale: Locale) -> String { ChannelCopy.text("重试", "Retry", locale: locale) }
    static func recover(_ locale: Locale) -> String { ChannelCopy.text("继续查询", "Check again", locale: locale) }

    static func headline(_ phase: BundleCommercePhase, _ locale: Locale) -> String {
        switch phase {
        case .loading: return ChannelCopy.text("正在读取", "Loading", locale: locale)
        case .empty: return ChannelCopy.text("没有可显示的内容", "Nothing to show", locale: locale)
        case .error: return ChannelCopy.text("读取失败", "Couldn't load this", locale: locale)
        case .permission: return ChannelCopy.text("没有读取权限", "Read permission is required", locale: locale)
        case .offline: return ChannelCopy.text("当前离线", "You're offline", locale: locale)
        case .unknown: return ChannelCopy.text("结果未确认", "Result not confirmed", locale: locale)
        case .ready: return hub(locale)
        }
    }

    static func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? unknownMark : trimmed
    }
}

enum BundleCommercePhase {
    case loading, empty, error, permission, offline, unknown, ready
}

enum BundleCommerceFailure {
    static func phase(_ error: Error) -> BundleCommercePhase {
        if error is CancellationError { return .loading }
        if error is URLError { return .offline }
        if let failure = error as? FreeExploreLaunchFailure {
            switch failure {
            case .disabled, .staleSession: return .permission
            case .outcomeUnknown: return .unknown
            case .response(let status, let code, _) where status == 0 && code == 0: return .offline
            default: return .error
            }
        }
        if let api = error as? APIError, api == .notConfigured || api == .unauthorized { return .permission }
        return .error
    }
}

/// In-memory only. Appeal and transfer must not touch the account's saved commands.
@MainActor final class BundleCommerceMemoryStorage: TemplateAuthoringStorage {
    private var values: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws { values[key] = data }
    func remove(_ key: String) throws { values.removeValue(forKey: key) }
}

@MainActor struct BundleCommerceOrderEntry: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale
    @Environment(\.bundleCommerceBaseURL) private var baseURL
    @Environment(\.freeExploreBundleReadProvider) private var provider

    private var entries: [BundleCommerceEntry] {
        let allowed = provider?.available() == true && origin.isConfigured
            && order.id == requestedID && order.memberID == origin.identity?.accountID
        return BundleCommerceCatalog.visible(baseURL: baseURL, capabilityAvailable: allowed)
    }

    var body: some View {
        Group {
            if !entries.isEmpty {
                Section {
                    NavigationLink {
                        BundleCommerceHub(order: order, requestedID: requestedID, origin: origin)
                    } label: {
                        Text(verbatim: BundleCommerceCopy.hub(locale))
                    }
                    .accessibilityIdentifier("bundle.commerce.open")
                }
            }
        }
    }
}

@MainActor struct BundleCommerceHub: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale
    @Environment(\.bundleCommerceBaseURL) private var baseURL
    @Environment(\.freeExploreBundleReadProvider) private var provider

    private var entries: [BundleCommerceEntry] {
        let allowed = provider?.available() == true && origin.isConfigured
            && order.id == requestedID && order.memberID == origin.identity?.accountID
        return BundleCommerceCatalog.visible(baseURL: baseURL, capabilityAvailable: allowed)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                BundleCommerceStatus(phase: .permission, title: BundleCommerceCopy.hub(locale))
            } else {
                List {
                    ForEach(entries) { entry in
                        NavigationLink {
                            BundleCommerceDestination(entry: entry, order: order, requestedID: requestedID, origin: origin)
                        } label: {
                            Text(verbatim: entry.title(locale))
                        }
                        .accessibilityIdentifier(entry.identifier)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CYNight.ink0.ignoresSafeArea())
        .themeDomain(.player)
        .navigationTitle(Text(verbatim: BundleCommerceCopy.hub(locale)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor struct BundleCommerceDestination: View {
    let entry: BundleCommerceEntry
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading

    var body: some View {
        switch entry {
        case .shelf: BundleCommerceShelfScreen()
        case .orderStatus: BundleCommerceOrderScreen(order: order, requestedID: requestedID, origin: origin)
        case .voucher: BundleCommerceVoucherScreen(order: order, requestedID: requestedID, origin: origin)
        case .refundQuote: BundleCommerceQuoteScreen(order: order, requestedID: requestedID, origin: origin)
        case .cancel: BundleCommerceCancelScreen(order: order, requestedID: requestedID, origin: origin)
        case .exitSwap: BundleCommerceExitSwapScreen(order: order, requestedID: requestedID, origin: origin)
        case .transfer: BundleCommerceTransferScreen(order: order, requestedID: requestedID, origin: origin)
        case .review: BundleCommerceReviewScreen(order: order, requestedID: requestedID, origin: origin)
        case .renewal: BundleCommerceRenewalScreen(order: order, requestedID: requestedID, origin: origin)
        case .appeal: BundleCommerceAppealScreen(order: order, requestedID: requestedID, origin: origin)
        }
    }
}

@MainActor struct BundleCommerceStatus: View {
    let phase: BundleCommercePhase
    let title: String
    var detail: String? = nil
    var primaryTitle: String? = nil
    var primaryIdentifier: String? = nil
    var primaryAction: (() -> Void)? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if phase == .loading {
                CYLoadingStateView(rows: 3)
                    .accessibilityIdentifier("bundle.commerce.loading")
            } else {
                CYStateLayout(
                    kind: art,
                    title: Text(verbatim: BundleCommerceCopy.headline(phase, locale)),
                    detail: detail.map { Text(verbatim: $0) },
                    primaryVerbatim: button,
                    primaryIdentifier: primaryIdentifier
                )
                .accessibilityIdentifier(identifier)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CYNight.ink0.ignoresSafeArea())
        .themeDomain(.player)
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var button: (title: String, action: () -> Void)? {
        guard let primaryTitle, let primaryAction, phase == .error || phase == .offline || phase == .unknown else { return nil }
        return (primaryTitle, primaryAction)
    }

    private var art: CYStateKind {
        switch phase {
        case .offline: return .offline
        case .error: return .failure
        case .empty: return .orders
        case .permission: return .notices
        default: return .generic
        }
    }

    private var identifier: String {
        switch phase {
        case .loading: return "bundle.commerce.loading"
        case .empty: return "bundle.commerce.empty"
        case .error: return "bundle.commerce.error"
        case .permission: return "bundle.commerce.permission"
        case .offline: return "bundle.commerce.offline"
        case .unknown: return "bundle.commerce.unknown"
        case .ready: return "bundle.commerce.ready"
        }
    }
}

@MainActor struct BundleCommerceReady<Content: View>: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    let title: String
    let content: (FreeExploreBundleReadHost, FreeExploreBundleLaunchModel) -> Content
    @Environment(\.freeExploreBundleReadProvider) private var provider
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var host: FreeExploreBundleReadHost?
    @State private var phase: BundleCommercePhase = .loading

    var body: some View {
        Group {
            if phase == .ready, let host, let model = host.model, host.current, model.current, model.order != nil {
                content(host, model)
            } else {
                BundleCommerceStatus(
                    phase: phase == .ready ? .empty : phase,
                    title: title,
                    detail: phase == .unknown ? BundleCommerceCopy.unknownMark : nil,
                    primaryTitle: actionTitle,
                    primaryIdentifier: actionIdentifier,
                    primaryAction: action
                )
            }
        }
        .task(id: provider?.revision) { await load() }
        .onChange(of: scenePhase) { _, next in
            if next == .background {
                host?.retire()
                host = nil
                phase = .permission
            }
        }
    }

    private var actionTitle: String? {
        switch phase {
        case .error, .offline: return BundleCommerceCopy.retry(locale)
        case .unknown: return BundleCommerceCopy.recover(locale)
        default: return nil
        }
    }

    private var actionIdentifier: String? {
        switch phase {
        case .error, .offline: return "bundle.commerce.retry"
        case .unknown: return "bundle.commerce.recover"
        default: return nil
        }
    }

    private var action: (() -> Void)? {
        switch phase {
        case .error, .offline: return { Task { await load() } }
        case .unknown: return { Task { await recover() } }
        default: return nil
        }
    }

    private func load() async {
        phase = .loading
        host?.retire()
        host = nil
        guard !Task.isCancelled else { return }
        guard let provider, provider.available(),
              let created = provider.make(order, requestedID, origin) else {
            phase = .permission
            return
        }
        host = created
        await created.load()
        guard !Task.isCancelled else { return }
        await settle(created)
    }

    /// Re-reads the saved reservation command. Does not mint a new request id or report success.
    private func recover() async {
        guard let created = host, let model = created.model, created.current else {
            phase = .permission
            return
        }
        phase = .loading
        await model.recover()
        guard !Task.isCancelled else { return }
        await settle(created)
    }

    private func settle(_ created: FreeExploreBundleReadHost) async {
        guard !Task.isCancelled else { return }
        guard created.current else { phase = .permission; return }
        if created.legacy { phase = .empty; return }
        guard let model = created.model else {
            phase = created.failed ? .error : .empty
            return
        }
        if model.state == .outcomeUnknown || model.failure == .outcomeUnknown {
            phase = .unknown
            return
        }
        if model.state == .idle, model.order == nil, model.failure == nil {
            await model.load()
        }
        guard !Task.isCancelled else { return }
        guard created.current, model.current else { phase = .permission; return }
        if model.state == .outcomeUnknown || model.failure == .outcomeUnknown {
            phase = .unknown
            return
        }
        if let failure = model.failure {
            phase = BundleCommerceFailure.phase(failure)
            return
        }
        phase = model.order == nil ? .empty : .ready
    }
}

@MainActor private struct BundleCommerceShelfScreen: View {
    @State private var model = BundleShelfModel(client: UnavailableBundleShelfClient(), pageSize: 20)

    var body: some View {
        BundleShelfView(model: model, onSelect: nil)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceOrderScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.orderStatus.title(locale)) { _, model in
            BundleCommerceOrderBody(model: model)
        }
    }
}

@MainActor private struct BundleCommerceOrderBody: View {
    let model: FreeExploreBundleLaunchModel
    @Environment(\.locale) private var locale

    var body: some View {
        if let order = model.order {
            BundleOrderStatusView(order: BundleOrderReadModel(order: order), poller: nil)
        } else {
            BundleCommerceStatus(phase: .empty, title: BundleCommerceEntry.orderStatus.title(locale))
        }
    }
}

@MainActor private struct BundleCommerceVoucherScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.voucher.title(locale)) { host, _ in
            BundleCommerceVoucherBody(registrationID: host.registrationID.text)
        }
    }
}

@MainActor private struct BundleCommerceVoucherBody: View {
    @StateObject private var model: BundleVoucherModel

    init(registrationID: String) {
        _model = StateObject(wrappedValue: BundleVoucherModel(
            registrationID: registrationID,
            client: UnavailableBundleVoucherClient(),
            sleep: { _ in throw CancellationError() }))
    }

    var body: some View {
        BundleVoucherView(model: model)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceQuoteScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.refundQuote.title(locale)) { host, model in
            BundleCommerceQuoteBody(host: host, model: model)
        }
    }
}

@MainActor private struct BundleCommerceQuoteBody: View {
    let host: FreeExploreBundleReadHost
    let model: FreeExploreBundleLaunchModel
    @Environment(\.locale) private var locale
    @State private var quote: FreeExploreLaunchRefundQuote?
    @State private var phase: BundleCommercePhase = .loading

    var body: some View {
        Group {
            if let quote {
                BundleRefundQuoteView(quote: quote)
            } else {
                BundleCommerceStatus(
                    phase: phase,
                    title: BundleCommerceEntry.refundQuote.title(locale),
                    detail: phase == .unknown ? BundleCommerceCopy.unknownMark : nil,
                    primaryTitle: actionTitle,
                    primaryIdentifier: actionIdentifier,
                    primaryAction: action
                )
            }
        }
        .task { await loadQuote() }
    }

    private var actionTitle: String? {
        switch phase {
        case .error, .offline: return BundleCommerceCopy.retry(locale)
        case .unknown: return BundleCommerceCopy.recover(locale)
        default: return nil
        }
    }

    private var actionIdentifier: String? {
        switch phase {
        case .error, .offline: return "bundle.commerce.retry"
        case .unknown: return "bundle.commerce.recover"
        default: return nil
        }
    }

    private var action: (() -> Void)? {
        switch phase {
        case .error, .offline: return { Task { await loadQuote() } }
        case .unknown: return { Task { await recover() } }
        default: return nil
        }
    }

    private func loadQuote() async {
        phase = .loading
        quote = nil
        do {
            let value = try await host.readRefundQuote()
            guard host.current, model.current else { phase = .permission; return }
            if model.state == .outcomeUnknown || model.failure == .outcomeUnknown {
                phase = .unknown
                return
            }
            quote = value
        } catch is CancellationError {
            return
        } catch {
            phase = BundleCommerceFailure.phase(error)
        }
    }

    private func recover() async {
        phase = .loading
        await model.recover()
        guard host.current, model.current else { phase = .permission; return }
        if model.state == .outcomeUnknown || model.failure == .outcomeUnknown {
            phase = .unknown
            return
        }
        if let failure = model.failure {
            phase = BundleCommerceFailure.phase(failure)
            return
        }
        await loadQuote()
    }
}

@MainActor private struct BundleCommerceCancelScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.cancel.title(locale)) { host, model in
            BundleCommerceCancelList(host: host, model: model)
        }
    }
}

/// G4 exit swap (`free-explore/index.js` loadExitOptions/consentSwap). Swap only; refund decisions stay out.
@MainActor private struct BundleCommerceExitSwapScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.exitSwap.title(locale)) { host, _ in
            BundleExitSwapView(host: host)
                .background(CYNight.ink0.ignoresSafeArea())
                .themeDomain(.player)
        }
    }
}

@MainActor private struct BundleCommerceCancelList: View {
    let host: FreeExploreBundleReadHost
    let model: FreeExploreBundleLaunchModel
    @Environment(\.locale) private var locale

    var body: some View {
        let rows = model.order?.bundle?.reservations ?? []
        Group {
            if rows.isEmpty {
                BundleCommerceStatus(phase: .empty, title: BundleCommerceEntry.cancel.title(locale),
                                     detail: BundleCommerceCopy.unknownMark)
            } else {
                List {
                    ForEach(rows, id: \.id) { row in
                        NavigationLink {
                            BundleCommerceCancelForm(host: host, reservationID: row.id)
                        } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: BundleCommerceCopy.shown(row.status))
                                Text(verbatim: BundleCommerceCopy.shown(row.startAt))
                            }
                        }
                        .accessibilityIdentifier("bundle.commerce.cancel.reservation.\(row.id.text)")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle(Text(verbatim: BundleCommerceEntry.cancel.title(locale)))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .background(CYNight.ink0.ignoresSafeArea())
        .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceCancelForm: View {
    let host: FreeExploreBundleReadHost
    let reservationID: FreeExploreLaunchID
    @Environment(\.locale) private var locale
    @State private var tools: BundleCommerceCancelTools?
    @State private var phase: BundleCommercePhase = .loading

    var body: some View {
        Group {
            if let tools {
                BundleCommerceCancelHolder(tools: tools, registrationID: host.registrationID, reservationText: reservationID.text)
            } else {
                BundleCommerceStatus(
                    phase: phase,
                    title: BundleCommerceEntry.cancel.title(locale),
                    detail: phase == .unknown ? BundleCommerceCopy.unknownMark : nil,
                    primaryTitle: phase == .error || phase == .offline ? BundleCommerceCopy.retry(locale) : nil,
                    primaryIdentifier: phase == .error || phase == .offline ? "bundle.commerce.retry" : nil,
                    primaryAction: phase == .error || phase == .offline ? { Task { await load() } } : nil
                )
            }
        }
        .task { await load() }
    }

    private func load() async {
        phase = .loading
        do {
            tools = try host.makeCancel(reservationID: reservationID)
        } catch is CancellationError {
            return
        } catch {
            phase = BundleCommerceFailure.phase(error)
        }
    }
}

@MainActor private struct BundleCommerceCancelHolder: View {
    @StateObject private var model: FreeExploreCancelModel
    let tools: BundleCommerceCancelTools
    let registrationID: FreeExploreLaunchID
    let reservationText: String

    init(tools: BundleCommerceCancelTools, registrationID: FreeExploreLaunchID, reservationText: String) {
        self.tools = tools
        self.registrationID = registrationID
        self.reservationText = reservationText
        _model = StateObject(wrappedValue: FreeExploreCancelModel(canceler: tools.canceler))
    }

    var body: some View {
        BundleCancelView(model: model, canceler: tools.canceler, service: tools.service,
                         registrationID: registrationID, reservationID: reservationText)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceTransferScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.transfer.title(locale)) { host, _ in
            BundleCommerceSessionGate(host: host, title: BundleCommerceEntry.transfer.title(locale)) { session in
                BundleCommerceTransferHub(session: session, registrationID: host.registrationID)
            }
        }
    }
}

@MainActor private struct BundleCommerceSessionGate<Content: View>: View {
    let host: FreeExploreBundleReadHost
    let title: String
    let content: (FreeExploreLaunchSession) -> Content
    @State private var session: FreeExploreLaunchSession?
    @State private var phase: BundleCommercePhase = .loading

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                BundleCommerceStatus(phase: phase, title: title,
                                     detail: phase == .unknown ? BundleCommerceCopy.unknownMark : nil)
            }
        }
        .task {
            do {
                session = try host.commerceSession()
            } catch is CancellationError {
                return
            } catch {
                phase = BundleCommerceFailure.phase(error)
            }
        }
    }
}

@MainActor private struct BundleCommerceTransferHub: View {
    let session: FreeExploreLaunchSession
    let registrationID: FreeExploreLaunchID
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            NavigationLink {
                BundleCommerceTransferSendScreen(session: session, registrationID: registrationID)
            } label: {
                Text(verbatim: ChannelCopy.text("发起转赠", "Send a transfer", locale: locale))
            }
            .accessibilityIdentifier("bundle.commerce.transfer.send")
            NavigationLink {
                BundleCommerceTransferClaimScreen(session: session)
            } label: {
                Text(verbatim: ChannelCopy.text("领取转赠", "Claim a transfer", locale: locale))
            }
            .accessibilityIdentifier("bundle.commerce.transfer.claim")
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CYNight.ink0.ignoresSafeArea())
        .themeDomain(.player)
        .navigationTitle(Text(verbatim: BundleCommerceEntry.transfer.title(locale)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor private struct BundleCommerceTransferSendScreen: View {
    @StateObject private var model: BundleTransferSendModel
    let registrationID: FreeExploreLaunchID

    init(session: FreeExploreLaunchSession, registrationID: FreeExploreLaunchID) {
        self.registrationID = registrationID
        let pending = BundleTransferPendingStore(storage: BundleCommerceMemoryStorage(), session: session)
        _model = StateObject(wrappedValue: BundleTransferSendModel(
            service: BundleTransferUnavailableClient(), pending: pending,
            makeKey: { "bt-" + UUID().uuidString }))
    }

    var body: some View {
        BundleTransferSendView(model: model, registrationID: registrationID)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceTransferClaimScreen: View {
    @StateObject private var model: BundleTransferClaimModel

    init(session: FreeExploreLaunchSession) {
        let pending = BundleTransferPendingStore(storage: BundleCommerceMemoryStorage(), session: session)
        _model = StateObject(wrappedValue: BundleTransferClaimModel(
            service: BundleTransferUnavailableClient(), pending: pending,
            makeKey: { "bc-" + UUID().uuidString }))
    }

    var body: some View {
        BundleTransferClaimView(model: model)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceReviewScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.review.title(locale)) { host, model in
            BundleCommerceSessionGate(host: host, title: BundleCommerceEntry.review.title(locale)) { session in
                BundleCommerceReviewHub(topicID: model.topicID, registrationID: host.registrationID, accountID: session.accountID)
            }
        }
    }
}

@MainActor private struct BundleCommerceReviewHub: View {
    @StateObject private var list: BundleReviewListModel
    @StateObject private var compose: BundleReviewComposeModel
    @Environment(\.locale) private var locale

    init(topicID: FreeExploreLaunchID, registrationID: FreeExploreLaunchID, accountID: FreeExploreLaunchID) {
        _list = StateObject(wrappedValue: BundleReviewListModel(topicID: topicID, service: UnavailableBundleReviewClient()))
        _compose = StateObject(wrappedValue: BundleReviewComposeModel(
            registrationID: registrationID, accountID: accountID,
            service: UnavailableBundleReviewClient(), pendingStore: nil,
            makeKey: { "rv-" + UUID().uuidString }))
    }

    var body: some View {
        List {
            NavigationLink {
                BundleReviewListView(model: list)
                    .navigationTitle(Text(verbatim: ChannelCopy.text("公开评价", "Public reviews", locale: locale)))
                    .navigationBarTitleDisplayMode(.inline)
                    .background(CYNight.ink0.ignoresSafeArea())
                    .themeDomain(.player)
            } label: {
                Text(verbatim: ChannelCopy.text("公开评价", "Public reviews", locale: locale))
            }
            .accessibilityIdentifier("bundle.commerce.review.list")
            NavigationLink {
                BundleReviewComposeView(model: compose)
                    .background(CYNight.ink0.ignoresSafeArea())
                    .themeDomain(.player)
            } label: {
                Text(verbatim: ChannelCopy.text("写评价", "Write a review", locale: locale))
            }
            .accessibilityIdentifier("bundle.commerce.review.compose")
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CYNight.ink0.ignoresSafeArea())
        .themeDomain(.player)
        .navigationTitle(Text(verbatim: BundleCommerceEntry.review.title(locale)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor private struct BundleCommerceRenewalScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.renewal.title(locale)) { host, _ in
            BundleCommerceRenewalBody(registrationID: host.registrationID)
        }
    }
}

@MainActor private struct BundleCommerceRenewalBody: View {
    @State private var model: BundleRenewalModel

    init(registrationID: FreeExploreLaunchID) {
        _model = State(initialValue: BundleRenewalModel(
            registrationID: registrationID,
            service: BundleRenewalUnavailableService(),
            makeKey: { "rn-" + UUID().uuidString }))
    }

    var body: some View {
        BundleRenewalIntentView(model: model)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceAppealScreen: View {
    let order: ProfileOrder
    let requestedID: Int
    let origin: any ProfileReading
    @Environment(\.locale) private var locale

    var body: some View {
        BundleCommerceReady(order: order, requestedID: requestedID, origin: origin,
                            title: BundleCommerceEntry.appeal.title(locale)) { host, model in
            BundleCommerceSessionGate(host: host, title: BundleCommerceEntry.appeal.title(locale)) { session in
                BundleCommerceAppealList(model: model, session: session, registrationID: host.registrationID)
            }
        }
    }
}

@MainActor private struct BundleCommerceAppealList: View {
    let model: FreeExploreBundleLaunchModel
    let session: FreeExploreLaunchSession
    let registrationID: FreeExploreLaunchID
    @Environment(\.locale) private var locale

    var body: some View {
        let units = model.order?.bundle?.units ?? []
        Group {
            if units.isEmpty {
                BundleCommerceStatus(phase: .empty, title: BundleCommerceEntry.appeal.title(locale),
                                     detail: BundleCommerceCopy.unknownMark)
            } else {
                List {
                    ForEach(units, id: \.id) { unit in
                        NavigationLink {
                            BundleCommerceAppealForm(session: session, registrationID: registrationID, unitID: unit.id)
                        } label: {
                            Text(verbatim: BundleCommerceCopy.shown(unit.status))
                        }
                        .accessibilityIdentifier("bundle.commerce.appeal.unit.\(unit.id.text)")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle(Text(verbatim: BundleCommerceEntry.appeal.title(locale)))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .background(CYNight.ink0.ignoresSafeArea())
        .themeDomain(.player)
    }
}

@MainActor private struct BundleCommerceAppealForm: View {
    @StateObject private var model: BundleAppealModel
    @State private var evidence: [String]
    let registrationID: FreeExploreLaunchID
    let unitID: FreeExploreLaunchID

    init(session: FreeExploreLaunchSession, registrationID: FreeExploreLaunchID, unitID: FreeExploreLaunchID) {
        self.registrationID = registrationID
        self.unitID = unitID
        let store = BundleAppealPendingStore(storage: BundleCommerceMemoryStorage(), session: session)
        _model = StateObject(wrappedValue: BundleAppealModel(
            service: UnavailableBundleAppealService(), store: store,
            makeKey: { "appeal-" + UUID().uuidString }))
        _evidence = State(initialValue: [])
    }

    var body: some View {
        BundleAppealView(model: model, registrationID: registrationID, unitID: unitID, evidenceRefs: $evidence)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
    }
}
