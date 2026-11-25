import XCTest
@testable import Questify

/// MP-first (owner 2026-11-25): the composition admits exactly the merchant-content write paths, POST + bearer token.
@MainActor final class MerchantContentMPWriteRouteTests: XCTestCase {
    private let base = URL(string: "https://merchant-route.example")!
    private func request(_ path: String, body: [String: MerchantContentValue] = ["id": .integer(1)], token: String = "synthetic-token",
                         method: String = "POST") throws -> URLRequest {
        var r = URLRequest(url: base.appendingPathComponent(path)); r.httpMethod = method
        r.setValue(token, forHTTPHeaderField: "Authorization"); r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONEncoder().encode(body); return r
    }
    func test_every_command_path_is_admitted_and_nothing_else() throws {
        let commands: [MerchantContentCommand] = [
            .reviewCircle(topicID: 70, scope: "MERCHANT"), .apply(chapterID: 7, message: ""), .withdraw(applicationID: 3),
            .cancelRegistration(id: 5), .auditApplication(id: 3, approve: true, reason: ""), .auditNode(nodeID: 9, approve: true, reason: ""),
            .claim(poiID: 1), .cancelClaim(poiID: 1), .cityStatus(poiID: 1, online: true),
            .saveNPC(nodeID: 9, name: "n", avatar: "a", greeting: "g"), .enrollVoice(nodeID: 9, voiceSample: "s"), .resetVoice(nodeID: 9),
        ]
        for command in commands {
            let path = try command.request().path
            XCTAssertTrue(MerchantContentMPWriteRoute.paths.contains(path), path)
            XCTAssertTrue(MerchantContentMPWriteRoute.accepts(try request(path), baseURL: base, token: "synthetic-token"), path)
        }
        XCTAssertFalse(MerchantContentMPWriteRoute.accepts(try request("api/merchant/city-node/claim", method: "GET"), baseURL: base, token: "synthetic-token"))
        XCTAssertFalse(MerchantContentMPWriteRoute.accepts(try request("api/merchant/city-node/claim"), baseURL: base, token: "other-token"))
        XCTAssertFalse(MerchantContentMPWriteRoute.accepts(try request("api/merchant/commerce/order"), baseURL: base, token: "synthetic-token"))
    }
    func test_station_command_only_for_merchant_station_actions() throws {
        let station = try request("api/game/session/command", body: ["action": .string("STATION_ACCEPT"), "activityId": .integer(1)])
        XCTAssertTrue(MerchantContentMPWriteRoute.accepts(station, baseURL: base, token: "synthetic-token"))
        let team = try request("api/game/session/command", body: ["action": .string("USE_ITEM")])
        XCTAssertFalse(MerchantContentMPWriteRoute.accepts(team, baseURL: base, token: "synthetic-token"))
    }
}
