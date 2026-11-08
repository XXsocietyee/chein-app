#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Service-level evidence for pages/merchant/coop-center (no hosted SwiftUI): the plaza read needs
/// BOTH merchant:project:manage and merchant:marketing:read, and a current refusal is never a success.
@MainActor final class MerchantCoopCenterAccessGateTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var permissions = ["merchant:project:manage", "merchant:marketing:read"]
        var homeStatus = 200
        var homeBody = #"{"code":200,"data":{"recruiting":{"count":2,"hasMoreOpen":true,"items":[{"id":70,"name":"Synthetic route"}]},"coupons":{"couponCount":0,"received":0,"verified":0},"content":{"topicCount":0,"freeExploreCount":0,"activityCount":0}}}"#
        var paths: [String] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            let path = request.url?.path ?? ""
            paths.append(path)
            if path.hasSuffix("access/me") {
                let list = permissions.map { "\"\($0)\"" }.joined(separator: ",")
                return (Data("{\"code\":200,\"data\":{\"active\":true,\"merchant\":{\"id\":31},\"roleCode\":\"MERCHANT_MANAGER\",\"permissions\":[\(list)]}}".utf8), 200)
            }
            return (Data(homeBody.utf8), homeStatus)
        }
    }
    private func service(_ wire: Wire) throws -> MerchantContentService {
        let session = try MerchantContentSession(accountID: 7, epoch: 1, storageScope: "synthetic-gate", token: "synthetic-token")
        return MerchantContentService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/")!), transport: wire, currentSession: { session })
    }
    func testGrantedReadReachesPlazaProjection() async throws {
        let wire = Wire(), snapshot = try await service(wire).loadRecruitingHome()
        XCTAssertEqual(wire.paths.filter { $0.hasSuffix("access/me") || $0.hasSuffix("marketing-home") }.count, 2)
        let plaza = try MerchantCoopCenterPlaza(home: snapshot.value, now: Date(timeIntervalSince1970: 1_790_827_200))
        XCTAssertEqual(plaza.routes.count, 1); XCTAssertEqual(plaza.routes.first?.topicID, 70)
        XCTAssertEqual(plaza.scope, MerchantCoopCenterPlaza.Scope(openCount: 2, shownCount: 1))
    }
    func testMissingMarketingGrantIsDeniedBeforeHomeRead() async throws {
        let wire = Wire(); wire.permissions = ["merchant:project:manage"]
        do { _ = try await service(wire).loadRecruitingHome(); XCTFail("must be denied") }
        catch { XCTAssertEqual(error as? MerchantContentFailure, .denied) }
        XCTAssertFalse(wire.paths.contains { $0.hasSuffix("marketing-home") })
    }
    func testMissingProjectGrantIsDenied() async throws {
        let wire = Wire(); wire.permissions = ["merchant:marketing:read"]
        do { _ = try await service(wire).loadRecruitingHome(); XCTFail("must be denied") }
        catch { XCTAssertEqual(error as? MerchantContentFailure, .denied) }
    }
    func testHTTP403AndBusiness403MapToDeniedAnd401ToUnauthorized() async throws {
        let http = Wire(); http.homeStatus = 403; http.homeBody = #"{"code":403}"#
        do { _ = try await service(http).loadRecruitingHome(); XCTFail() } catch { XCTAssertEqual(error as? MerchantContentFailure, .denied) }
        let business = Wire(); business.homeBody = #"{"code":403}"#
        do { _ = try await service(business).loadRecruitingHome(); XCTFail() } catch { XCTAssertEqual(error as? MerchantContentFailure, .denied) }
        let signedOut = Wire(); signedOut.homeStatus = 401; signedOut.homeBody = #"{"code":401}"#
        do { _ = try await service(signedOut).loadRecruitingHome(); XCTFail() } catch { XCTAssertEqual(error as? APIError, .unauthorized) }
    }
    func testMalformedHomeNeverProducesRoutes() async throws {
        let wire = Wire(); wire.homeBody = #"{"code":200,"data":{"recruiting":{"items":[]}}}"#
        let snapshot = try await service(wire).loadRecruitingHome()
        XCTAssertThrowsError(try MerchantCoopCenterPlaza(home: snapshot.value, now: Date())) {
            XCTAssertEqual($0 as? MerchantCoopCenterFailure, .malformed)
        }
    }
}
#endif
