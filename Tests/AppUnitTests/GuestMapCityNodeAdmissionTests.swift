import XCTest
@testable import Questify

@MainActor final class GuestMapCityNodeAdmissionTests: XCTestCase {
    private let base = URL(string: "https://example.test/native")!
    private let area = RoamSearchArea(coordinate: RoamCoordinate(latitude: 31.2, longitude: 121.5)!, label: "A")

    private func guest() -> CompositionHTTPTransport.SessionIdentity {
        .init(epoch: 1, accountID: nil, role: nil, token: nil)
    }

    private func route(_ path: String, fields: [String: String]) -> ManualMapReadRoute? {
        var url = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !fields.isEmpty {
            url.queryItems = fields.keys.sorted().map { URLQueryItem(name: $0, value: fields[$0]) }
        }
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        return ManualMapReadRoute(request: request, baseURL: base, area: area)
    }

    func testOnlyPureChinaGuestCityNodes() throws {
        let nodes = try XCTUnwrap(route("api/city/nodes", fields: ["lat": "31.2", "lng": "121.5", "radius": "3000"]))
        XCTAssertTrue(GuestMapCityNodeAdmission.allows(nodes, identity: guest(), market: .china, grantsManualMap: true))
        XCTAssertFalse(GuestMapCityNodeAdmission.allows(nodes, identity: guest(), market: .china, grantsManualMap: false))
        XCTAssertFalse(GuestMapCityNodeAdmission.allows(nodes, identity: guest(), market: .unitedStates, grantsManualMap: true))
        let partial = CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: "player", token: nil)
        XCTAssertFalse(GuestMapCityNodeAdmission.allows(nodes, identity: partial, market: .china, grantsManualMap: true))
        let signed = CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: 7, role: "player", token: "synthetic-7")
        XCTAssertFalse(GuestMapCityNodeAdmission.allows(nodes, identity: signed, market: .china, grantsManualMap: true))
        let places = try XCTUnwrap(route("api/roam/pois", fields: ["lat": "31.2", "lng": "121.5", "radius": "3000"]))
        XCTAssertFalse(GuestMapCityNodeAdmission.allows(places, identity: guest(), market: .china, grantsManualMap: true))
        let detail = try XCTUnwrap(route("api/city/nodes/42", fields: [:]))
        XCTAssertTrue(GuestMapCityNodeAdmission.allows(detail, identity: guest(), market: .china, grantsManualMap: true))
        XCTAssertFalse(GuestMapCityNodeAdmission.allows(nil, identity: guest(), market: .china, grantsManualMap: true))
    }
}
