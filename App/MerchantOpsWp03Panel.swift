import SwiftUI

enum MerchantOpsWp03Page: String {
    case decor, npc, team, coupon, chapter

    var routes: [MerchantOpsWp03Route] {
        switch self {
        case .decor: return [.order, .orderStatus, .shareCode, .claimsStatus, .claimsSubmit]
        case .npc: return [.npcReview]
        case .team: return [.invitePreview]
        case .coupon: return [.couponSummary]
        case .chapter: return [.inviteRevoke]
        }
    }
}

enum MerchantOpsWp03Route: String, Identifiable, CaseIterable {
    case claimsStatus, claimsSubmit, order, orderStatus, couponSummary, npcReview, invitePreview, shareCode, inviteRevoke
    var id: String { rawValue }

    var path: String {
        switch self {
        case .claimsStatus: return MerchantOpsWp03Catalog.claimsStatus
        case .claimsSubmit: return MerchantOpsWp03Catalog.claimsSubmit
        case .order: return MerchantOpsWp03Catalog.commerceOrder
        case .orderStatus: return MerchantOpsWp03Catalog.commerceOrderStatus
        case .couponSummary: return MerchantOpsWp03Catalog.couponSummary
        case .npcReview: return MerchantOpsWp03Catalog.npcReview
        case .invitePreview: return MerchantOpsWp03Catalog.invitePreview
        case .shareCode: return MerchantOpsWp03Catalog.shareCode
        case .inviteRevoke: return MerchantOpsWp03Catalog.inviteRevoke
        }
    }

    func call(accountID: Int) -> MerchantOpsWp03Call {
        switch self {
        case .claimsStatus: return .claimsStatus()
        case .claimsSubmit:
            return .claimsSubmit(merchantID: accountID > 0 ? accountID : 1, requestID: "wp03-claim", contactName: "Store", contactPhone: "13800000000", statement: "claim", proofType: "store", assetID: "wp03")
        case .order: return .commerceOrder(bizType: "premium_template", requestID: "wp03-decor-order")
        case .orderStatus: return .commerceOrderStatus(orderSn: "TPLTM_PENDING")
        case .couponSummary: return .couponSummary()
        case .npcReview: return .npcReview()
        case .invitePreview: return .invitePreview(token: "")
        case .shareCode: return .shareCode(memberID: accountID)
        case .inviteRevoke: return .inviteRevoke(applicationID: 1)
        }
    }
}

final class MerchantOpsWp03Bridge {
    let baseURL: URL?
    let token: String?
    let host: String?
    let accountID: Int
    let transport: any HTTPTransport

    init(baseURL: URL?, token: String?, host: String?, accountID: Int, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.host = host
        self.accountID = accountID
        self.transport = transport
    }
}

private struct MerchantOpsWp03BridgeKey: EnvironmentKey {
    static let defaultValue: MerchantOpsWp03Bridge? = nil
}

extension EnvironmentValues {
    var merchantOpsWp03Bridge: MerchantOpsWp03Bridge? {
        get { self[MerchantOpsWp03BridgeKey.self] }
        set { self[MerchantOpsWp03BridgeKey.self] = newValue }
    }
}

enum MerchantOpsWp03Phase: Equatable {
    case loading, ready, empty, failed, withheld, signedOut
}

@MainActor final class MerchantOpsWp03Model: ObservableObject {
    @Published private(set) var phase: [String: MerchantOpsWp03Phase] = [:]
    @Published private(set) var reply: [String: MerchantOpsWp03Reply] = [:]

    func load(page: MerchantOpsWp03Page, bridge: MerchantOpsWp03Bridge?) async {
        guard let bridge, let baseURL = bridge.baseURL else {
            for route in page.routes { phase[route.id] = .signedOut }
            return
        }
        let client = MerchantOpsWp03Client(baseURL: baseURL, transport: bridge.transport)
        let money = ReviewedAreaSwitch.moneyPayments(apiHost: bridge.host)
        let writes = ReviewedAreaSwitch.merchantWrites(apiHost: bridge.host)
        for route in page.routes { phase[route.id] = .loading }
        for route in page.routes {
            if route == .shareCode, bridge.accountID <= 0 {
                phase[route.id] = .signedOut
                continue
            }
            let result = await client.perform(route.call(accountID: bridge.accountID), token: bridge.token, allowsMoney: money, allowsMerchantWrite: writes)
            reply[route.id] = result
            phase[route.id] = Self.phase(result)
        }
    }

    private static func phase(_ result: MerchantOpsWp03Reply) -> MerchantOpsWp03Phase {
        if !result.sent { return .withheld }
        if !result.succeeded { return .failed }
        if result.isEmpty { return .empty }
        return .ready
    }
}

struct MerchantOpsWp03Panel: View {
    let page: MerchantOpsWp03Page
    @Environment(\.merchantOpsWp03Bridge) private var bridge
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = MerchantOpsWp03Model()

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? CYSpacing.md : CYSpacing.sm) {
            Text(LocalizedStringKey(titleKey), tableName: "MerchantOpsWp03")
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(Text(LocalizedStringKey(titleKey), tableName: "MerchantOpsWp03"))
            ForEach(page.routes) { route in
                MerchantOpsWp03RowView(route: route, phase: model.phase[route.id] ?? .loading, reply: model.reply[route.id]) {
                    Task { await model.load(page: page, bridge: bridge) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("wp03.page." + page.rawValue)
        .task(id: taskKey) { await model.load(page: page, bridge: bridge) }
    }

    private var titleKey: String {
        switch page {
        case .decor: return "wp03.decor.title"
        case .npc: return "wp03.npc.title"
        case .team: return "wp03.team.title"
        case .coupon: return "wp03.coupon.title"
        case .chapter: return "wp03.chapter.title"
        }
    }

    private var taskKey: String {
        guard let bridge, let baseURL = bridge.baseURL else { return "none" }
        return baseURL.absoluteString + "|" + (bridge.token ?? "") + "|" + String(bridge.accountID) + "|" + (bridge.host ?? "")
    }
}

private struct MerchantOpsWp03RowView: View {
    let route: MerchantOpsWp03Route
    let phase: MerchantOpsWp03Phase
    let reply: MerchantOpsWp03Reply?
    let retry: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? CYSpacing.sm : CYSpacing.xs) {
            copy(LocalizedStringKey(titleKey), style: .bodyMedium, color: CYColor.textPrimary)
            Text(verbatim: MerchantOpsWp03Catalog.method(for: route.path) + " /" + route.path)
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            state
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("wp03.row." + route.id)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(LocalizedStringKey(titleKey), tableName: "MerchantOpsWp03"))
        .accessibilityValue(spokenValue)
        .accessibilityHint(spokenHint)
    }

    private var spokenValue: Text {
        switch phase {
        case .loading: return Text("wp03.loading", tableName: "MerchantOpsWp03")
        case .empty: return Text("wp03.empty", tableName: "MerchantOpsWp03")
        case .failed: return Text(verbatim: reply?.message ?? MerchantOpsWp03Reply.unknown)
        case .withheld: return Text("wp03.unknown", tableName: "MerchantOpsWp03")
        case .signedOut: return Text("wp03.signedOut", tableName: "MerchantOpsWp03")
        case .ready: return Text(verbatim: reply?.detail ?? MerchantOpsWp03Reply.unknown)
        }
    }

    private var spokenHint: Text {
        switch phase {
        case .failed: return Text("wp03.retry", tableName: "MerchantOpsWp03")
        case .withheld: return Text(LocalizedStringKey(withheldKey), tableName: "MerchantOpsWp03")
        case .empty: return Text("wp03.empty", tableName: "MerchantOpsWp03")
        case .signedOut: return Text("wp03.signedOut", tableName: "MerchantOpsWp03")
        case .loading: return Text("wp03.loading", tableName: "MerchantOpsWp03")
        case .ready: return Text(verbatim: MerchantOpsWp03Catalog.method(for: route.path) + " /" + route.path)
        }
    }

    private var titleKey: String { "wp03.row." + route.rawValue }

    private func copy(_ key: LocalizedStringKey, style: CYTextStyle, color: Color) -> some View {
        Text(key, tableName: "MerchantOpsWp03")
            .cyText(style)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var state: some View {
        switch phase {
        case .loading:
            loading
        case .empty:
            copy("wp03.empty", style: .body, color: CYColor.textSecondary)
                .accessibilityIdentifier("wp03.empty." + route.id)
        case .failed:
            Text(verbatim: reply?.message ?? MerchantOpsWp03Reply.unknown)
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            CYPillButton(
                "wp03.retry",
                style: .secondary,
                fullWidth: dynamicTypeSize.isAccessibilitySize,
                compact: !dynamicTypeSize.isAccessibilitySize,
                tableName: "MerchantOpsWp03",
                action: retry
            )
            .accessibilityIdentifier("wp03.retry." + route.id)
        case .withheld:
            copy("wp03.unknown", style: .body, color: CYColor.textPrimary)
                .accessibilityIdentifier("wp03.withheld." + route.id)
            copy(LocalizedStringKey(withheldKey), style: .body, color: CYColor.textSecondary)
        case .signedOut:
            copy("wp03.signedOut", style: .body, color: CYColor.textSecondary)
                .accessibilityIdentifier("wp03.signedOut." + route.id)
        case .ready:
            Text(verbatim: reply?.detail ?? MerchantOpsWp03Reply.unknown)
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("wp03.ready." + route.id)
        }
    }

    private var loading: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.sm))
        return layout {
            ProgressView()
                .tint(CYColor.textSecondary)
            copy("wp03.loading", style: .body, color: CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wp03.loading." + route.id)
    }

    private var withheldKey: String {
        switch route {
        case .order, .orderStatus: return "wp03.moneyOff"
        case .claimsSubmit, .shareCode, .inviteRevoke: return "wp03.writesOff"
        default: return "wp03.unknown"
        }
    }
}
