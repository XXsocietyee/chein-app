#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// pages/coop/nearby: the explicit search action drives the real CoopFlowService through
/// CoopFlowSessionReader into a recording fake transport (no real host). Rows appear only
/// after a code-200 envelope; a server refusal leaves the list empty and failed.
private final class NearbyMerchantProofTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var status = 200
    var response = #"{"code":200,"data":[{"id":91,"memberId":801,"name":"Synthetic shop","distance":125},{"id":92,"name":"Synthetic lead"}]}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(response.utf8), status) }
}

@MainActor private final class NearbyMerchantProofLocation: RoamDeviceLocationProviding {
    let fix: RoamDeviceFix
    var calls = 0
    init(_ fix: RoamDeviceFix) { self.fix = fix }
    func currentFix() async throws -> RoamDeviceFix { calls += 1; return fix }
    func stop() {}
}

@MainActor final class NearbyMerchantSearchHTTPProofTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(_ transport: NearbyMerchantProofTransport) throws -> NearbyMerchantCoordinator {
        let service = CoopFlowService(configuration: try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com/native/"))), transport: transport)
        let session = try CoopFlowSession(accountID: 7, epoch: 1, token: "fixture-token")
        let reader = CoopFlowSessionReader(service: service, current: { session }, unauthorized: { _ in })
        let coordinate = try XCTUnwrap(RoamCoordinate(latitude: 31.2, longitude: 121.4))
        let fix = try RoamDeviceFix(coordinate: coordinate, accuracyMeters: 5, measuredAt: date, datum: .gcj02)
        return NearbyMerchantCoordinator(reader: reader, location: NearbyMerchantProofLocation(fix), approved: { true }, now: { self.date })
    }

    func testSearchPostsMultipartNearbyFormAndShowsRowsOnlyAfterServerOK() async throws {
        let transport = NearbyMerchantProofTransport()
        let model = try makeModel(transport)
        XCTAssertTrue(transport.requests.isEmpty, "Construction is inert")
        await model.search(purposeAccepted: true)
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/native/api/merchant/nearby")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "fixture-token")
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
        for field in ["longitude", "latitude", "radius", "limit"] {
            XCTAssertTrue(body.contains("name=\"\(field)\""), field)
        }
        XCTAssertTrue(body.contains("name=\"radius\"\r\n\r\n5000"))
        XCTAssertTrue(body.contains("name=\"limit\"\r\n\r\n30"))
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.rows.map(\.id), [91, 92])
        XCTAssertEqual(model.rows.first?.memberID, 801)
    }

    func testServerRefusalAndHTTPFailureNeverPublishRows() async throws {
        for (status, json) in [(200, #"{"code":500,"msg":"refused"}"#), (502, #"{"code":200,"data":[]}"#), (200, #"{"code":200,"data":{}}"#)] {
            let transport = NearbyMerchantProofTransport()
            transport.status = status; transport.response = json
            let model = try makeModel(transport)
            await model.search(purposeAccepted: true)
            XCTAssertEqual(transport.requests.count, 1, json)
            XCTAssertEqual(model.phase, .failed, json)
            XCTAssertTrue(model.rows.isEmpty, json)
        }
    }
}
#endif
