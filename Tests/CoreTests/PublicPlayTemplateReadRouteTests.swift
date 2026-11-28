import XCTest
@testable import QuestifyCore

final class PublicPlayTemplateReadRouteTests: XCTestCase {
    private let base = URL(string: "https://k40-home.example.test")!

    private func form(_ path: String, _ fields: [String: String], token: String? = nil) throws -> URLRequest {
        try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent(path), fields: fields, token: token, boundary: "k40-home-boundary")
    }

    func testInfoListAndHomeDataMatchTheDiscoveryServiceBodies() throws {
        let info = try form("api/template/info", ["id": "8"], token: "synthetic-player-token")
        XCTAssertTrue(PublicPlayTemplateReadRoute.accepts(info, baseURL: base))
        var listFields = ["pageNum": "1", "pageSize": String(DiscoveryService.playTemplatePageSize), "keyword": "walk", "pack_type": "1"]
        XCTAssertTrue(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", listFields), baseURL: base))
        listFields.removeValue(forKey: "keyword")
        listFields.removeValue(forKey: "pack_type")
        listFields["pageNum"] = String(DiscoveryService.playTemplatePageCap)
        XCTAssertTrue(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", listFields), baseURL: base))
        var home = URLRequest(url: base.appendingPathComponent("api/template/homeData"))
        home.httpMethod = "POST"
        home.setValue("application/json", forHTTPHeaderField: "Content-Type")
        home.httpBody = Data("{}".utf8)
        XCTAssertTrue(PublicPlayTemplateReadRoute.accepts(home, baseURL: base))
    }

    func testMyInfoScopeExtraFieldsAndBadIDsStayOut() throws {
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/myinfo", ["id": "8"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/info", ["id": "8", "scope": "my"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/info", ["id": "0"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/info", ["id": "08"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", ["pageNum": "0", "pageSize": "50"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", ["pageNum": "21", "pageSize": "50"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", ["pageNum": "1", "pageSize": "10"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", ["pageNum": "1", "pageSize": "50", "pack_type": "3"]), baseURL: base))
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(try form("api/template/list", ["pageNum": "1", "pageSize": "50", "keyword": "  "]), baseURL: base))
        var get = try form("api/template/info", ["id": "8"])
        get.httpMethod = "GET"
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(get, baseURL: base))
        var queried = try form("api/template/info", ["id": "8"])
        queried.url = URL(string: base.appendingPathComponent("api/template/info").absoluteString + "?x=1")
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(queried, baseURL: base))
        var home = URLRequest(url: base.appendingPathComponent("api/template/homeData"))
        home.httpMethod = "POST"
        home.setValue("application/json", forHTTPHeaderField: "Content-Type")
        home.httpBody = Data("{\"id\":8}".utf8)
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(home, baseURL: base))
    }
}
