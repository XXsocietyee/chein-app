import XCTest
@testable import Questify
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The App struct owns pass and market bindings. Purchase, quote, order, and claim stay unreachable.
@MainActor final class MPParityPassBindingTests: XCTestCase {
    func testViewerMerchantAndMembershipStayReadOnly() {
        XCTAssertFalse(MPParityBindings.moneyEnabled)
        XCTAssertFalse(MPCommerceGate.purchasesEnabled)
        XCTAssertFalse(MPCommerceGate.claimsEnabled)
        XCTAssertFalse(MPCommerceGate.payoutEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        for kind in ReleaseMoneyWriteKind.allCases {
            XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind))
        }

        XCTAssertFalse(MPParityBindings.viewerIsMerchant(role: "player"))
        XCTAssertTrue(MPParityBindings.viewerIsMerchant(role: "merchant"))
        XCTAssertTrue(MPParityBindings.viewerIsMerchant(role: "", userType: "2"))
        XCTAssertFalse(MPParityBindings.viewerIsMerchant(role: "merchant", debugView: "user"))
        XCTAssertFalse(MPParityBindings.viewerIsMerchant(role: "", userType: "2", debugView: "user"))

        let selling = overview(active: false, coverageEnd: nil, libraryCount: 12, plans: plans)
        // MKT-4-1: month plan only, priced 首发价 ¥X (platform-pass.js:84-86,108).
        XCTAssertEqual(MPParityBindings.memberSide(viewerIsMerchant: false, overview: selling),
                       .plans(appLocalized("mp.member.plan.launchPrice \("¥39.00")", locale: .current)))
        let sellingContent = MPParityBindings.membershipContent(selling)
        XCTAssertEqual(sellingContent.plans.map(\.code), ["MONTH"])
        XCTAssertEqual(sellingContent.plans.first?.line, .month)
        XCTAssertEqual(sellingContent.buyPrice, "¥39.00")
        XCTAssertNil(MPParityBindings.memberSide(viewerIsMerchant: true, overview: selling))
        let held = overview(active: true, coverageEnd: "2027-12-10 12:00:00", libraryCount: nil, plans: plans)
        XCTAssertEqual(MPParityBindings.memberSide(viewerIsMerchant: false, overview: held), .activeUntil("2027.12.10"))
        let counted = overview(active: false, coverageEnd: nil, libraryCount: 0, plans: [])
        XCTAssertEqual(MPParityBindings.memberSide(viewerIsMerchant: false, overview: counted), .themeCount(0))
        XCTAssertNil(MPParityBindings.memberSide(viewerIsMerchant: false, overview: .merchantBlocked))
        XCTAssertNil(MPParityBindings.wholePoints(nil))
        XCTAssertEqual(MPParityBindings.wholePoints(0), 0)
        XCTAssertEqual(MPParityBindings.wholePoints(18), 18)
    }

    func testStoreCardCheckoutAndOrderFactsDoNotOpenPurchase() {
        let city = product(id: "1", name: "城市包", kind: 2, city: "上海", topics: ["老城"], topicIDs: ["990014"], cash: 88)
        let cheaper = product(id: "2", name: "时限", kind: 3, city: "上海", topics: ["外滩"], topicIDs: ["990014"], cash: 39)
        let gift = product(id: "7", name: "礼品", kind: 7, city: "上海", topics: ["老城"], topicIDs: ["990014"], cash: 1)
        let card = MPParityBindings.exploreCard(products: [city])
        XCTAssertEqual(card?.priceText, "¥88.00")
        XCTAssertEqual(card?.covers, ["老城"])
        XCTAssertNil(MPParityBindings.exploreCard(products: [gift]))
        let both = MPParityBindings.exploreCard(products: [city, cheaper])
        XCTAssertEqual(both?.covers, ["外滩", "老城"])
        let fromPrice = both?.priceText ?? ""
        XCTAssertTrue(fromPrice.contains("¥39") || fromPrice.contains("mp.pass.store.from"), fromPrice)

        let covered = MPParityBindings.checkoutCover(topicCovered: true, products: [city, gift], topicID: "990014")
        XCTAssertTrue(covered.covered)
        XCTAssertTrue(covered.passes.isEmpty)
        let open = MPParityBindings.checkoutCover(topicCovered: false, products: [city, gift], topicID: "990014")
        XCTAssertFalse(open.covered)
        XCTAssertEqual(open.passes.map(\.id), ["1"])
        XCTAssertEqual(open.passes.first?.priceText, "¥88.00")

        let detail = MPParityBindings.orderFacts(
            id: "ORD-1", purchaseKind: 2, ownerType: 1, ticketID: nil, expiresAt: "2027-12-11 00:00:00",
            wechatPaymentAmount: nil, payableAmount: 0, totalAmount: 0, pointPaymentAmount: nil)
        XCTAssertTrue(detail.shown)
        XCTAssertTrue(detail.selfPlayPass)
        XCTAssertEqual(detail.untilMonth, 12)
        XCTAssertEqual(detail.untilDay, 10)
        XCTAssertEqual(detail.actualPaid, 0)
        XCTAssertTrue(detail.free)
        XCTAssertFalse(detail.payReachable)
        XCTAssertFalse(detail.refundReachable)
        let paid = MPParityBindings.orderFacts(
            id: "ORD-2", purchaseKind: nil, ownerType: 1, ticketID: nil, expiresAt: "2027-12-10 12:00:00",
            wechatPaymentAmount: 12, payableAmount: 0, totalAmount: 0, pointPaymentAmount: 0)
        XCTAssertTrue(paid.selfPlayPass)
        XCTAssertEqual(paid.untilDay, 10)
        XCTAssertEqual(paid.actualPaid, 12)
        XCTAssertFalse(paid.free)
        XCTAssertFalse(MPParityBindings.orderFacts(
            id: "", purchaseKind: 2, ownerType: nil, ticketID: nil, expiresAt: nil,
            wechatPaymentAmount: nil, payableAmount: nil, totalAmount: nil, pointPaymentAmount: nil).shown)
        XCTAssertEqual(MPText.unknown, "—")
    }

    func testReadTransportRefusesPurchaseQuoteOrderAndClaim() async throws {
        let wire = Recorder()
        let transport = PlatformPassReadOnlyTransport(underlying: wire)
        let base = try XCTUnwrap(URL(string: "https://fixture.example.test"))
        for path in [PlatformPass.purchasePath, PlatformPass.quotePath, PlatformPass.orderPath, PlatformPass.claimPath] {
            var request = URLRequest(url: base.appendingPathComponent(path))
            request.httpMethod = "POST"
            do {
                _ = try await transport.send(request)
                XCTFail(path)
            } catch PlatformPassWriteRefusal.unreachable {
            } catch {
                XCTFail("\(path) \(error)")
            }
        }
        XCTAssertTrue(wire.requests.isEmpty)

        var overview = URLRequest(url: base.appendingPathComponent(PlatformPass.overviewPath))
        overview.httpMethod = "GET"
        wire.body = Data(#"{"code":200,"data":{"enabled":false}}"#.utf8)
        let reader = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
        let loaded = try await reader.overview(token: "session-token", viewerIsMerchant: false)
        XCTAssertFalse(loaded.enabled)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertThrowsError(try reader.purchase(planCode: "YEAR", channel: "XPAY", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
        }
        do { _ = try await reader.quote(productID: "9", token: "session-token"); XCTFail("quote") }
        catch { XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable) }
        do {
            _ = try await reader.order(productID: "9", token: "session-token", payMode: 1, quoteSign: "sign", quoteExpiresAt: 1, requestID: "mkp_1")
            XCTFail("order")
        } catch { XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable) }
        do { _ = try await reader.claim(giftToken: "gift", requestID: "gift_1", token: "session-token"); XCTFail("claim") }
        catch { XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable) }
        XCTAssertEqual(wire.requests.count, 1)
    }

    func testBindingSourceDoesNotCallWriteMethods() throws {
        let source = try String(contentsOf: sourceURL(), encoding: .utf8)
        for needle in [".purchase(", ".quote(", ".order(", ".claim("] {
            XCTAssertFalse(source.contains(needle), needle)
        }
        XCTAssertFalse(source.contains("moneyEnabled = true"))
        XCTAssertFalse(source.contains("purchasesEnabled = true"))
        XCTAssertFalse(source.contains("claimsEnabled = true"))
    }

    private func sourceURL(file: StaticString = #filePath) -> URL {
        var url = URL(fileURLWithPath: "\(file)")
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url.appendingPathComponent("App/MPParityPassSession.swift")
    }

    /// MKT-4-4: card facts follow platform-pass.js passView (clamped days, two labels only, active only).
    func testMembershipCardFactsFollowHolding() {
        let holding = PlatformPassHolding(active: true, validTo: nil, coverageEnd: nil, planLabel: "月卡",
                                          daysTotal: 30, daysRemaining: 40, teammateBenefit: true, expiring: true)
        XCTAssertEqual(holding.daysRemaining, 30)
        XCTAssertNil(PlatformPassHolding(active: true, validTo: nil, coverageEnd: nil, planLabel: "季卡").planLabel)
        XCTAssertNil(PlatformPassHolding(active: true, validTo: nil, coverageEnd: nil, daysTotal: 0, daysRemaining: 3).daysRemaining)
        let active = MPParityBindings.membershipContent(PlatformPassOverview(
            enabled: true, merchantBlocked: false, libraryCount: nil, plans: plans, holding: holding,
            jsapiAvailable: true, xpayAvailable: false))
        XCTAssertEqual(active.planLabel, "月卡"); XCTAssertTrue(active.teammate); XCTAssertTrue(active.expiring)
        XCTAssertEqual(active.daysLeft, 30); XCTAssertEqual(active.daysTotal, 30)
        let inactive = MPParityBindings.membershipContent(overview(active: false, coverageEnd: nil, libraryCount: nil, plans: plans))
        XCTAssertNil(inactive.planLabel); XCTAssertNil(inactive.daysLeft); XCTAssertFalse(inactive.expiring)
    }

    private var plans: [PlatformPassPlan] {
        [PlatformPassPlan(code: "YEAR", title: "年卡", priceFen: 29900, validDays: 365),
         PlatformPassPlan(code: "MONTH", title: "月卡", priceFen: 3900, validDays: 30)]
    }

    private func overview(active: Bool, coverageEnd: String?, libraryCount: Int?, plans: [PlatformPassPlan]) -> PlatformPassOverview {
        PlatformPassOverview(
            enabled: true, merchantBlocked: false, libraryCount: libraryCount, plans: plans,
            holding: PlatformPassHolding(active: active, validTo: nil, coverageEnd: coverageEnd),
            jsapiAvailable: true, xpayAvailable: false)
    }

    private func product(id: String, name: String, kind: Int, city: String, topics: [String], topicIDs: [String], cash: Double) -> PlatformPassProduct {
        PlatformPassProduct(id: id, name: name, kind: "", city: city, validity: "", seats: "", price: "",
                            coverCount: topics.count, topics: topics, topicIDs: topicIDs, giftOnly: kind == 7,
                            isExtraSeat: kind == 8, cashPrice: cash, pointsPrice: nil, productKind: kind,
                            validityKind: 1, validDays: 30)
    }

    private final class Recorder: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body = Data()
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (body, 200)
        }
    }
}
