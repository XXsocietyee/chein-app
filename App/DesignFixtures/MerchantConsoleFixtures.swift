#if DEBUG
import SwiftUI

/// D5 design fixtures for the merchant console (light). SYNTHETIC DATA, DEBUG only, never in Release.
/// Names: merchant-home, merchant-home-unknown, merchant-orders, merchant-projects, merchant-customers,
/// merchant-finance, merchant-coupons. Every one runs the REAL view under `.roleTheme(.merchant)`.
@MainActor
final class DesignMerchantReader: MerchantReading {
    enum Variant { case rich, unknown, empty }
    let isConfigured = true
    let isSignedIn = true
    let sessionRevision: UInt64 = 0
    private let variant: Variant
    init(_ variant: Variant) { self.variant = variant }

    func merchantAccess() async throws -> MerchantAccess {
        try decode(#"{"active":true,"merchant":{"id":31,"name":"Synthetic City Gear Hall"},"roleCode":"MERCHANT_OWNER","permissions":["merchant:finance:read","merchant:order:read","merchant:project:manage","merchant:aftercare:read","merchant:verify","merchant:crm:read"]}"#)
    }
    func merchantDashboard(access: MerchantAccess) async throws -> MerchantDashboard {
        if variant == .unknown { return try decode(#"{"pendingOrders":0,"revenue7d":[]}"#) }
        return try decode(#"{"revenue":"12860.50","pendingOrders":3,"revenue7d":[{"date":"11-03","amount":"860.00"},{"date":"11-04","amount":"1250.50"},{"date":"11-05","amount":"0.00"}]}"#)
    }
    func merchantTodo(access: MerchantAccess) async throws -> MerchantTodo {
        if variant != .rich { return try decode(#"{}"#) }
        return try decode(#"{"pendingOrders":3,"pendingVerify":2,"verifiedCount":14,"pendingScanConfirm":1,"refundCount":1}"#)
    }
    func merchantEvents(access: MerchantAccess) async throws -> [MerchantEvent] {
        if variant != .rich { return [] }
        return try decode(#"[{"content":"Synthetic order paid","time":"11-08 21:40"},{"content":"Synthetic code redeemed","time":"11-08 19:05"}]"#)
    }
    func merchantOrders(access: MerchantAccess, filter: MerchantOrderFilter) async throws -> [MerchantOrder] {
        if variant == .empty { return [] }
        return try decode(#"[{"id":101,"orderSn":"SYN-20261108-0101","status":1,"aftersaleStatus":1,"payAmount":"128.00","createTime":"2026-11-08 21:40"},{"id":102,"orderSn":"SYN-20261108-0102","status":4,"aftersaleStatus":1,"payAmount":"59.90","createTime":"2026-11-08 19:05"},{"id":103,"orderSn":"SYN-20261107-0103","status":2,"aftersaleStatus":3,"payAmount":null,"createTime":"2026-11-07 10:12"}]"#)
    }
    func merchantProjects(access: MerchantAccess) async throws -> MerchantProjectPage {
        if variant == .empty { return try decode(#"{"rows":[],"total":0}"#) }
        return try decode(#"{"rows":[{"id":201,"bizType":"activity","title":"Synthetic City Walk, Stop 1","state":"running","ownerType":"merchant","addressName":"Synthetic East Lane","pendingVerifyCount":2,"stateText":"Running","startTime":"2026-11-09 10:00","endTime":"2026-11-09 18:00","signupCount":24,"viewCount":310},{"id":202,"bizType":"activity","title":"Synthetic Night Market Quest","state":"notStarted","ownerType":"merchant","addressName":"Synthetic West Lane","pendingVerifyCount":0,"stateText":"Not started","startTime":"2026-11-15 18:00","signupCount":0,"viewCount":41}],"total":2}"#)
    }
    private func decode<T: Decodable>(_ json: String) throws -> T { try JSONDecoder().decode(T.self, from: Data(json.utf8)) }
}

/// Real-path host: the same `.roleTheme(.merchant)` the merchant root applies, plus the page background.
struct MerchantConsoleFixture: View {
    enum Screen { case home, homeUnknown, orders, projects, customers, finance }
    let screen: Screen
    @StateObject private var reader: DesignMerchantReader
    private let business = MerchantBusinessFixtureReader(scenario: .ready)
    private let journal = MerchantBusinessMemoryIntentStore()

    init(_ screen: Screen) {
        self.screen = screen
        _reader = StateObject(wrappedValue: DesignMerchantReader(screen == .homeUnknown ? .unknown : .rich))
    }

    var body: some View {
        NavigationStack {
            switch screen {
            case .home, .homeUnknown:
                MerchantHomeView(reader: reader, businessReader: business, businessJournal: journal)
                    .environment(\.nativeVerificationDestination, { AnyView(Text(verbatim: "Scan")) })
            case .orders: MerchantOrdersView(reader: reader)
            case .projects: MerchantProjectsView(reader: reader)
            case .customers: MerchantBusinessPage(reader: business, journal: journal, query: .customers(.init()))
            case .finance: MerchantLedgerSettlementOverview(reader: business)
            }
        }
        .roleTheme(.merchant)
        .cyDomainPageBackground()
    }
}

/// The registry's `make` is nonisolated; fixtures are only ever built from the app's body on the main actor.
func merchantConsoleFixture(_ screen: MerchantConsoleFixture.Screen) -> AnyView {
    MainActor.assumeIsolated { AnyView(MerchantConsoleFixture(screen)) }
}
func merchantCouponFixture() -> AnyView {
    MainActor.assumeIsolated { AnyView(CouponManagementFixtureHost(showsHarness: false)) }
}
#endif
