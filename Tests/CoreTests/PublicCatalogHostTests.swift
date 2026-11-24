import Foundation
import XCTest
@testable import QuestifyCore

final class PublicCatalogHostTests: XCTestCase {
    private let emDash = PWaveNumberFact.unknownDisplay

    func testUnknownPriceIsAnEmDashAndALiteralZeroStaysZero() {
        XCTAssertEqual(PublicCatalogPrice.text(state: "UNKNOWN", amount: .value(0)), emDash)
        XCTAssertEqual(PublicCatalogPrice.text(state: "UNKNOWN", amount: .unknown), emDash)
        XCTAssertNotEqual(PublicCatalogPrice.text(state: "UNKNOWN", amount: .value(0)), "0")
        XCTAssertEqual(PublicCatalogPrice.text(state: nil, amount: .unknown), emDash)
        XCTAssertEqual(PublicCatalogPrice.text(state: "ON_SALE", amount: .value(0)), "0")
        XCTAssertEqual(PublicCatalogPrice.text(state: "ON_SALE", amount: .value(12)), "12")

        let unknown = card(price: .value(0), state: "UNKNOWN", unit: "起")
        let presented = PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                         phase: .ready(PWaveThemeCollectionFact(cards: [unknown], cities: [])))
        guard case .ready(let rows) = PublicCatalogScreen.state(presented) else { return XCTFail("expected rows") }
        XCTAssertEqual(rows[0].price, emDash)
        XCTAssertNil(rows[0].unit)
        XCTAssertNotEqual(rows[0].price, "0")

        let free = card(price: .value(0), state: "ON_SALE", unit: "起")
        let priced = PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                      phase: .ready(PWaveThemeCollectionFact(cards: [free], cities: [PWaveCatalogCity(cityCode: "SHA", cityName: "上海")])))
        guard case .ready(let mixed) = PublicCatalogScreen.state(priced) else { return XCTFail("expected mixed") }
        XCTAssertEqual(mixed[0].price, "0")
        XCTAssertEqual(mixed[0].unit, "起")
        XCTAssertEqual(mixed[1].title, "上海")
        XCTAssertNil(mixed[1].price)
    }

    func testHiddenCatalogStaysUnavailable() {
        let hidden = PWavePresentation<PWaveThemeCollectionFact>.loading(clientCapabilityPresent: false)
        XCTAssertEqual(PublicCatalogScreen.state(hidden), .unavailable)
        XCTAssertNotEqual(PublicCatalogScreen.state(hidden), .ready([]))
    }

    func testUniversalLinkReadsListFiltersAndInfoAndRefusesMoney() throws {
        XCTAssertTrue(UniversalLinkConfiguration.verifiedHTTPSOrigins.isEmpty)
        XCTAssertNil(UniversalLinkParser().parse(URL(string: "https://example.test/catalog")!))
        XCTAssertNil(NativeEntryLinkPolicy().parse(URL(string: "https://example.test/catalog/info?id=9")!))

        let parser = UniversalLinkParser(verifiedHTTPSOrigins: ["https://example.test"])
        guard case .miniProgramPage(let home) = parser.parse(URL(string: "https://example.test/catalog?city_code=SHA")!) else {
            return XCTFail("expected home")
        }
        XCTAssertEqual(home.page, "pages/index/index")
        XCTAssertTrue(home.query.isEmpty)
        guard case .miniProgramPage(let filters) = parser.parse(URL(string: "https://example.test/catalog/filters")!) else {
            return XCTFail("expected home")
        }
        XCTAssertEqual(filters.page, "pages/index/index")
        guard case .content(let topic) = parser.parse(URL(string: "https://example.test/catalog?id=9")!) else {
            return XCTFail("expected topic")
        }
        XCTAssertEqual(topic.kind, .topic)
        XCTAssertEqual(topic.id, 9)
        guard case .miniProgramPage(let info) = parser.parse(URL(string: "https://example.test/catalog/info?id=9&locale=zh-CN")!) else {
            return XCTFail("expected home")
        }
        XCTAssertEqual(info.page, "pages/index/index")

        for raw in [
            "https://example.test/catalog/map",
            "https://example.test/catalog/ids?ids=9",
            "https://example.test/catalog/city/list",
            "https://example.test/api/public-catalog/list",
            "https://example.test/catalog/info",
            "https://example.test/catalog/info?id=9&pay=1",
            "https://example.test/catalog?quote=1",
            "https://example.test/catalog?order=1",
            "https://example.test/catalog/list?price=0",
        ] {
            XCTAssertNil(parser.parse(URL(string: raw)!), raw)
            XCTAssertNil(PublicCatalogLink.parse(path: URL(string: raw)!.path, items: URLComponents(string: raw)?.queryItems ?? []), raw)
        }
        XCTAssertEqual(PublicCatalogLink.readablePaths, [.list, .filters, .info])
        XCTAssertFalse(PublicCatalogLink.readablePaths.contains(.map))
        XCTAssertFalse(PublicCatalogLink.readablePaths.contains(.ids))
        XCTAssertFalse(PublicCatalogLink.readablePaths.contains(.cityList))
    }

    func testHostPostsTheThreeReadsAndKeepsMoneyOff() async throws {
        XCTAssertFalse(PublicCatalogHost.moneyEnabled)
        let wire = Wire(body: envelope(#"{"id":"9","name":"江岸","priceState":"UNKNOWN","priceFrom":0,"priceUnit":"起"}"#))
        let reader = try makeReader(wire)
        let host = PublicCatalogHost(reader: reader)
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let info = try XCTUnwrap(PublicCatalogLink(screen: .info, fields: ["id": "9"]))
        let presented = try await host.load(info, token: nil, scope: scope, currentScope: { scope })
        guard case .ready(let rows) = PublicCatalogScreen.state(presented) else { return XCTFail("expected a card") }
        XCTAssertEqual(rows[0].price, emDash)
        XCTAssertNotEqual(rows[0].price, "0")
        XCTAssertNil(rows[0].unit)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/public-catalog/info")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(String(decoding: request.httpBody ?? Data(), as: UTF8.self), "id=9")
        XCTAssertFalse(String(decoding: request.httpBody ?? Data(), as: UTF8.self).contains("{"))

        wire.body = envelope("[]")
        let filters = try XCTUnwrap(PublicCatalogLink(screen: .filters, fields: ["city_code": "SHA"]))
        let listed = try await host.load(filters, token: nil, scope: scope, currentScope: { scope })
        XCTAssertEqual(PublicCatalogScreen.state(listed), .empty)
        XCTAssertEqual(wire.requests[1].url?.path, "/api/public-catalog/filters")
        XCTAssertEqual(String(decoding: wire.requests[1].httpBody ?? Data(), as: UTF8.self), "city_code=SHA")

        let list = try XCTUnwrap(PublicCatalogLink(screen: .list, fields: [:]))
        _ = try await host.load(list, token: "session-token", scope: scope, currentScope: { scope })
        XCTAssertEqual(wire.requests[2].url?.path, "/api/public-catalog/list")
        XCTAssertEqual(wire.requests[2].value(forHTTPHeaderField: "Authorization"), "session-token")
        let paths = wire.requests.compactMap { $0.url?.path }
        XCTAssertFalse(paths.contains("/api/public-catalog/map"))
        XCTAssertFalse(paths.contains("/api/public-catalog/ids"))
        XCTAssertFalse(paths.contains("/api/public-catalog/city/list"))

        let sent = wire.requests.count
        XCTAssertThrowsError(try host.quote(requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try host.order(requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try host.pay(orderNo: "o-1", requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? PWaveRefusal, .writesNotAvailable)
        }
        XCTAssertEqual(wire.requests.count, sent)
    }

    func testMissingGrantSendsNothing() async throws {
        let wire = Wire(body: envelope(#"{"id":"9","name":"江岸"}"#))
        let reader = try PWaveReader(configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
                                    transport: wire, endpointClass: .nonProduction, capabilities: PWaveCapability())
        let host = PublicCatalogHost(reader: reader)
        let scope = try PWaveSessionScope(accountID: 7, epoch: 1, namespace: "cn")
        let link = try XCTUnwrap(PublicCatalogLink(screen: .list, fields: [:]))
        let presented = try await host.load(link, token: nil, scope: scope, currentScope: { scope })
        XCTAssertEqual(PublicCatalogScreen.state(presented), .unavailable)
        XCTAssertTrue(wire.requests.isEmpty)
        XCTAssertFalse(PublicCatalogHost.moneyEnabled)
    }

    private func card(price: PWaveNumberFact, state: String, unit: String) -> PWaveCatalogCard {
        PWaveCatalogCard(id: "9", canonicalPath: nil, cityCode: nil, cityName: nil, name: "江岸",
                         subtitle: nil, summary: nil, imageURL: nil, productType: nil, chapterNames: nil,
                         priceFrom: price, priceState: state, priceUnit: unit, saleState: nil, freeSelfPlay: nil,
                         groupEligible: nil, schoolEligible: nil, requestedLocale: nil, actualLocale: nil,
                         translationState: nil, revisionState: nil)
    }

    private func envelope(_ data: String) -> Data {
        Data(#"{"code":200,"msg":"ok","requiredCapabilities":["public.catalog"],"data":\#(data)}"#.utf8)
    }

    private func makeReader(_ wire: Wire) throws -> PWaveReader {
        try PWaveReader(configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
                        transport: wire, endpointClass: .nonProduction,
                        capabilities: PWaveCapability(granted: [.themeCollection], supportedServerCapabilities: ["public.catalog"]))
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body: Data
        init(body: Data) { self.body = body }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (body, 200)
        }
    }
}
