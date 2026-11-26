#if DEBUG
import SwiftUI

/// DEBUG hosts for screens whose types already compile on this `ui/main` tip.
/// Launch with `--design-fixture cur5-<name>` (`-zh` sets zh-Hans).
/// A paid screen stays on the closed copy. A missing fact is an em dash. A decoded 0 stays 0.
/// The table is `docs/release/receipts/ui-cur-fixtures-5.md`.
enum CurFixtures5 {
    @MainActor static func make(_ name: String) -> AnyView? {
        let zh = name.hasSuffix("-zh")
        let id = zh ? String(name.dropLast(3)) : name
        guard let mounted = makeHost(id) else { return nil }
        let merchant = id.hasPrefix("cur5-wp03") || id.hasPrefix("cur5-merchant")
        return AnyView(Cur5Frame(title: caption(id), zh: zh, merchant: merchant, content: mounted))
    }

    @MainActor private static func makeHost(_ id: String) -> AnyView? {
        switch id {
        case "cur5-ws-purchased": return AnyView(Cur5PurchasedHost())
        case "cur5-ws-purchased-unavailable": return AnyView(Cur5PurchasedUnavailable())
        case "cur5-ws-install": return AnyView(Cur5InstallHost(decode: true))
        case "cur5-ws-install-undecoded": return AnyView(Cur5InstallHost(decode: false))
        case "cur5-wp07-group": return AnyView(Cur5GroupHost(kind: .unknown))
        case "cur5-wp07-group-zero": return AnyView(Cur5GroupHost(kind: .zero))
        case "cur5-wp07-group-empty": return AnyView(Cur5GroupHost(kind: .empty))
        case "cur5-wp07-group-failed": return AnyView(Cur5GroupHost(kind: .failed))
        case "cur5-wp07-activate": return AnyView(PassActivatePanel(topicID: "topic-7"))
        case "cur5-wp07-activate-empty": return AnyView(PassActivatePanel(topicID: nil))
        case "cur5-wp07-coupon": return AnyView(Cur5CouponHost(phase: .ready(Cur5.couponRows)))
        case "cur5-wp07-coupon-empty": return AnyView(Cur5CouponHost(phase: .empty))
        case "cur5-wp07-coupon-failed": return AnyView(Cur5CouponHost(phase: .failed))
        case "cur5-host-config": return AnyView(NavigationStack { HostTipConfigScreen(session: AppSession()) })
        case "cur5-host-player": return AnyView(NavigationStack { HostTipPlayerScreen(session: AppSession()) })
        case "cur5-channel": return AnyView(ChannelRedeemSheet(session: AppSession()))
        case "cur5-landing": return AnyView(NavigationStack { ContentLandingScreen(session: nil, topicID: "topic-fixture") })
        case "cur5-video-bounty": return AnyView(NavigationStack { Cur5VideoBountyHost(failed: false) })
        case "cur5-video-bounty-failed": return AnyView(NavigationStack { Cur5VideoBountyHost(failed: true) })
        case "cur5-wp03-decor-signedout": return AnyView(Cur5Wp03Host(signedOut: true))
        case "cur5-wp03-decor-closed": return AnyView(Cur5Wp03Host(signedOut: false))
        case "cur5-coop-receipt-signedout": return AnyView(Cur5CoopHost(mode: .signedOut))
        case "cur5-coop-receipt-unknown": return AnyView(Cur5CoopHost(mode: .unknown))
        case "cur5-coop-receipt-failed": return AnyView(Cur5CoopHost(mode: .failed))
        case "cur5-square-delete": return AnyView(Cur5SquareHost(kind: .ready))
        case "cur5-square-delete-empty": return AnyView(Cur5SquareHost(kind: .empty))
        case "cur5-square-delete-failed": return AnyView(Cur5SquareHost(kind: .failed))
        case "cur5-square-delete-signedout": return AnyView(Cur5SquareHost(kind: .signedOut))
        case "cur5-quick-empty": return AnyView(Cur5QuickHost(kind: .empty))
        case "cur5-quick-unknown": return AnyView(Cur5QuickHost(kind: .unknown))
        case "cur5-quick-zero": return AnyView(Cur5QuickHost(kind: .zero))
        case "cur5-quick-failed": return AnyView(Cur5QuickHost(kind: .failed))
        case "cur5-preset": return AnyView(GameplayPresetSection(canDraft: false))
        case "cur5-lineage": return AnyView(SourceLineageSection(revisionID: "rev-7"))
        case "cur5-lineage-unknown": return AnyView(SourceLineageSection(revisionID: nil))
        case "cur5-team-role": return AnyView(Cur5TeamHost(zero: true))
        case "cur5-team-role-unknown": return AnyView(Cur5TeamHost(zero: false))
        case "cur5-delivery-zero": return AnyView(Cur5DeliveryHost(zero: true))
        case "cur5-delivery-unknown": return AnyView(OrderDeliverySection(delivery: nil))
        case "cur5-pay-return-zero": return AnyView(OrderPaymentReturnSection(loading: false, payment: 0, registration: nil, channels: []))
        case "cur5-pay-return-unknown": return AnyView(OrderPaymentReturnSection(loading: false, payment: nil, registration: nil, channels: nil))
        case "cur5-refund-zero": return AnyView(Cur5RefundHost())
        case "cur5-accrual-unknown": return AnyView(CreatorAccrualSection(projection: .unknown(reason: nil)))
        default: return nil
        }
    }

    private static func caption(_ id: String) -> String {
        switch id {
        case "cur5-ws-purchased": return "Purchased workshop · reads off"
        case "cur5-ws-purchased-unavailable": return "Purchased workshop · no browser"
        case "cur5-ws-install": return "Paid install · no charge"
        case "cur5-ws-install-undecoded": return "Paid install · unknown item"
        case "cur5-wp07-group": return "Group quote · unknown tier and total"
        case "cur5-wp07-group-zero": return "Group quote · total 0"
        case "cur5-wp07-group-empty": return "Group quote · empty"
        case "cur5-wp07-group-failed": return "Group quote · failed"
        case "cur5-wp07-activate": return "Activate · closed"
        case "cur5-wp07-activate-empty": return "Activate · no topic"
        case "cur5-wp07-coupon": return "Coupon usability · unknown is an em dash"
        case "cur5-wp07-coupon-empty": return "Coupon usability · empty"
        case "cur5-wp07-coupon-failed": return "Coupon usability · failed"
        case "cur5-host-config": return "Host tip config · signed out"
        case "cur5-host-player": return "Host tip intents · signed out"
        case "cur5-channel": return "Channel redeem · idle"
        case "cur5-landing": return "Content landing · empty"
        case "cur5-video-bounty": return "Video bounty · unknown amount"
        case "cur5-video-bounty-failed": return "Video bounty · read failed"
        case "cur5-wp03-decor-signedout": return "Store decoration · signed out"
        case "cur5-wp03-decor-closed": return "Store decoration · money closed"
        case "cur5-coop-receipt-signedout": return "Invite receipts · signed out"
        case "cur5-coop-receipt-unknown": return "Invite receipts · unknown state"
        case "cur5-coop-receipt-failed": return "Invite receipts · failed"
        case "cur5-square-delete": return "My square posts"
        case "cur5-square-delete-empty": return "My square posts · empty"
        case "cur5-square-delete-failed": return "My square posts · failed"
        case "cur5-square-delete-signedout": return "My square posts · signed out"
        case "cur5-quick-empty": return "Quick publish · empty"
        case "cur5-quick-unknown": return "Quick publish · unknown quota"
        case "cur5-quick-zero": return "Quick publish · quota 0"
        case "cur5-quick-failed": return "Quick publish · failed"
        case "cur5-preset": return "Gameplay presets · cannot read"
        case "cur5-lineage": return "Source version"
        case "cur5-lineage-unknown": return "Source version · unknown"
        case "cur5-team-role": return "Team role · session count 0"
        case "cur5-team-role-unknown": return "Team role · unknown"
        case "cur5-delivery-zero": return "Delivery · amount 0"
        case "cur5-delivery-unknown": return "Delivery · unknown"
        case "cur5-pay-return-zero": return "Payment return · status 0"
        case "cur5-pay-return-unknown": return "Payment return · unknown"
        case "cur5-refund-zero": return "Partial refund · pending 0"
        case "cur5-accrual-unknown": return "Creator accrual · unknown"
        default: return id
        }
    }
}

private struct Cur5Frame: View {
    let title: String
    let zh: Bool
    let merchant: Bool
    let content: AnyView

    init(title: String, zh: Bool, merchant: Bool, content: AnyView) {
        self.title = title
        self.zh = zh
        self.merchant = merchant
        self.content = content
        W8Text.languageOverride = zh ? "zh-Hans" : "en"
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            Text(verbatim: zh ? title + " · 调试夹具 · 合成数据" : title + " · DEBUG fixture · synthetic")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.sm)
                .accessibilityIdentifier("cur5.fixture.footer")
        }
        .environment(\.locale, Locale(identifier: zh ? "zh-Hans" : "en"))
        .themeDomain(merchant ? .merchant : .player)
    }
}

private enum Cur5 {
    static let token = "synthetic-fixture-token"
    static let hashA = String(repeating: "a", count: 64)
    static let hashB = String(repeating: "b", count: 64)
    static let fixtureBase = URL(string: "https://fixture.example")!

    static var paidItemJSON: String {
        #"{"licenseId":"WKO_0000000000000000000000000000000b","moduleId":11,"purchasedVersionId":"synthetic-version","contentHash":"\#(hashA)","acquiredAt":"2026-10-05T00:00:00Z","termsVersion":"terms-1","termsHash":"\#(hashB)","status":"ACTIVE","commercialUse":"PROHIBITED","adaptation":"LOCAL_ADAPTATION","translation":"PROHIBITED","allowedRegions":["110101"],"themeLimit":{"unlimited":false,"maximum":1},"merchantLimit":{"unlimited":false,"maximum":0},"runLimit":{"unlimited":false,"maximum":0},"acquisition":"PAID","buyerKind":"INDIVIDUAL","useDuration":"PERPETUAL_PURCHASED_VERSION","updates":"EXACT_PURCHASED_VERSION","redistribution":"PROHIBITED","contentUseStatus":"PRIVATE_DRAFT_INSTALL_AVAILABLE","purchaseActionStatus":"EXACT_VERSION_PURCHASED"}"#
    }

    static func paidItem() -> WorkshopPurchasedItem? {
        try? JSONDecoder().decode(WorkshopPurchasedItem.self, from: Data(paidItemJSON.utf8))
    }

    static var couponRows: [CouponUsabilityRow] {
        [
            CouponUsabilityRow(id: "1", name: nil, usable: false, reason: "MYSTERY", faceText: nil),
            CouponUsabilityRow(id: "2", name: "Night pass", usable: true, reason: "AVAILABLE", faceText: "0")
        ]
    }

    static var readyBounty: VideoBountyState {
        var state = VideoBountyState()
        state.submissions = .ready([
            VideoBountySubmissionRow(
                id: "sub-1", platform: nil, sourceURL: "https://fixture.example/night",
                status: .approved, reviewNote: nil, windowEndText: "2026.11.30",
                canAppeal: false, canCancel: false)
        ])
        state.accruals = .ready([
            VideoBountyAccrualRow(id: "acc-1", amountText: nil, views: 0, groupViews: nil)
        ])
        state.attribution = .ready(.unknown)
        return state
    }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(json.utf8))
    }

    static var failedBounty: VideoBountyState {
        var state = VideoBountyState()
        state.submissions = .failed(nil)
        state.accruals = .failed(nil)
        state.attribution = .failed(nil)
        return state
    }
}

private struct Cur5Down: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        throw URLError(.cannotConnectToHost)
    }
}

@MainActor private struct Cur5PurchasedReader: WorkshopPurchasedReading {
    func list(before: Int64?, lifetime: WorkshopPurchasedReadLifetime) async throws -> WorkshopPurchasedPage {
        throw WorkshopPurchasedIssue.disabled
    }
    func detail(licenseId: String, lifetime: WorkshopPurchasedReadLifetime) async throws -> WorkshopPurchasedDetail {
        throw WorkshopPurchasedIssue.disabled
    }
}

@MainActor private struct Cur5PurchasedHost: View {
    @StateObject private var session = AppSession()
    private let browser: WorkshopPurchasedBrowser?

    init() {
        guard let play = try? PlayExperienceSession(accountID: 7, epoch: 1, namespace: "synthetic", token: Cur5.token) else {
            browser = nil
            return
        }
        let context = RuntimeDependencyContext(market: .china, baseURL: Cur5.fixtureBase, role: "player", session: play)
        browser = WorkshopPurchasedBrowser(
            reader: Cur5PurchasedReader(),
            lease: ContentDraftSessionLease(context: context, current: { context }))
    }

    var body: some View {
        if let browser {
            WorkshopPurchasedLibraryView(browser: browser).environmentObject(session)
        } else {
            Text(verbatim: "—").accessibilityIdentifier("cur5.ws.unknown")
        }
    }
}

@MainActor private struct Cur5PurchasedUnavailable: View {
    var body: some View {
        NavigationStack {
            List { WorkshopPurchasedAccountLink(browser: nil) }
        }
    }
}

@MainActor private struct Cur5InstallHost: View {
    let decode: Bool

    var body: some View {
        if decode, let item = Cur5.paidItem() {
            List { WorkshopPaidInstallEntry(item: item, makeController: { _ in nil }) }
        } else {
            Text(verbatim: "—").accessibilityIdentifier("cur5.install.unknown")
        }
    }
}

@MainActor private struct Cur5GroupHost: View {
    enum Kind { case unknown, zero, empty, failed }
    let kind: Kind

    var body: some View {
        switch kind {
        case .unknown:
            GroupCheckoutPanel(phase: .ready(display(total: nil)), onRetry: {})
        case .zero:
            GroupCheckoutPanel(phase: .ready(display(total: "0")), onRetry: {})
        case .empty:
            GroupCheckoutPanel(phase: .ready(GroupCheckoutDisplay(
                productName: nil, productKind: nil, tierLabel: nil, totalText: nil, activityID: nil, ticketID: nil)), onRetry: {})
        case .failed:
            GroupCheckoutPanel(phase: .failed(nil), onRetry: {})
        }
    }

    private func display(total: String?) -> GroupCheckoutDisplay {
        GroupCheckoutDisplay(productName: "Harbor night", productKind: 5, tierLabel: nil, totalText: total, activityID: nil, ticketID: nil)
    }
}

@MainActor private struct Cur5CouponHost: View {
    let phase: CouponUsabilityPhase

    var body: some View {
        List { CouponUsabilitySection(phase: phase, onRetry: {}) }
    }
}

@MainActor private struct Cur5VideoBountyHost: View {
    let failed: Bool

    var body: some View {
        VideoBountyView(
            state: failed ? Cur5.failedBounty : Cur5.readyBounty,
            campaign: nil,
            onLoad: {},
            onSubmit: { _, _, _, _, _ in },
            onAppeal: { _, _ in },
            onCancel: { _ in })
    }
}

@MainActor private struct Cur5Wp03Host: View {
    let signedOut: Bool

    var body: some View {
        MerchantOpsWp03Panel(page: .decor)
            .padding(CYSpacing.pageHorizontal)
            .environment(\.merchantOpsWp03Bridge, signedOut ? nil : bridge)
    }

    private var bridge: MerchantOpsWp03Bridge {
        MerchantOpsWp03Bridge(
            baseURL: Cur5.fixtureBase, token: Cur5.token, host: "www.chengyinhub.com",
            accountID: 7, transport: Cur5Down())
    }
}

@MainActor private final class Cur5CoopReader: CoopFlowReading {
    enum Mode { case signedOut, failed, unknown }
    let mode: Mode
    init(mode: Mode) { self.mode = mode }
    var session: CoopFlowSession? {
        guard mode != .signedOut else { return nil }
        return try? CoopFlowSession(accountID: 7, epoch: 1, token: Cur5.token)
    }
    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        if mode == .failed { throw CoopFlowFailure.disabled }
        guard case .inviteRequests = resource else { return .object([:]) }
        return .object(["rows": .array([.object(["state": .null, "requestId": .null])])])
    }
    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement {
        throw CoopFlowFailure.disabled
    }
}

@MainActor private struct Cur5CoopHost: View {
    let mode: Cur5CoopReader.Mode
    private let reader: Cur5CoopReader

    init(mode: Cur5CoopReader.Mode) {
        self.mode = mode
        reader = Cur5CoopReader(mode: mode)
    }

    var body: some View {
        List {
            CoopInviteReceiptSections(reader: reader, kind: .club, topicID: nil, merchantMemberIDs: [])
        }
    }
}

@MainActor private struct Cur5SquareHost: View {
    enum Kind { case ready, empty, failed, signedOut }
    let kind: Kind

    var body: some View {
        List {
            CreativeSquareAuthorDeleteSection(
                signedIn: kind != .signedOut,
                load: {
                    switch kind {
                    case .ready: return [7]
                    case .empty, .signedOut: return []
                    case .failed: throw Cur5ReadFailure()
                    }
                },
                remove: { _ in throw Cur5ReadFailure() })
        }
    }
}

private struct Cur5ReadFailure: Error {}

@MainActor private struct Cur5QuickHost: View {
    enum Kind { case empty, unknown, zero, failed }
    @StateObject private var owner = QuickPublishSimplePageOwner()
    let kind: Kind

    var body: some View {
        QuickPublishSimplePageStatus(owner: owner)
            .task { await owner.load(read: read, draft: draft) }
    }

    private var draft: QuickPublishDraft {
        var value = QuickPublishDraft()
        if kind != .empty { value.title = "Night walk" }
        return value
    }

    private var read: ((PublishingRead) async throws -> ProjectEditJSON)? {
        switch kind {
        case .empty:
            return nil
        case .failed:
            return { _ in throw Cur5ReadFailure() }
        case .unknown:
            return { resource in
                if resource == .capability { return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeMissingThemesJSON) }
                if resource == .aiQuota { return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaUnknownJSON) }
                throw Cur5ReadFailure()
            }
        case .zero:
            return { resource in
                if resource == .capability { return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeZeroThemesJSON) }
                if resource == .aiQuota { return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaZeroJSON) }
                throw Cur5ReadFailure()
            }
        }
    }
}

@MainActor private struct Cur5TeamHost: View {
    let zero: Bool

    var body: some View {
        if zero, let shared = Cur5.decode(TeamSharedOutcome.self, #"{"sessionParticipants":0}"#) {
            TeamRoleAndSharedSection(role: nil, shared: shared)
        } else {
            TeamRoleAndSharedSection(role: nil, shared: nil)
        }
    }
}

@MainActor private struct Cur5DeliveryHost: View {
    let zero: Bool

    var body: some View {
        if zero, let facts = Cur5.decode(OrderDeliveryFacts.self, #"{"ticketName":"Night","amountFromServer":0}"#) {
            OrderDeliverySection(delivery: facts)
        } else {
            OrderDeliverySection(delivery: nil)
        }
    }
}

@MainActor private struct Cur5RefundHost: View {
    var body: some View {
        if let facts = Cur5.decode(OrderSettlementFacts.self, #"{"refundPendingAmount":0,"amountsComplete":false}"#) {
            OrderPartialRefundSection(settlement: facts)
        } else {
            OrderPartialRefundSection(settlement: nil)
        }
    }
}
#endif
