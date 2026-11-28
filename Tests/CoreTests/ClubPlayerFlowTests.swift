import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ClubPlayerFlowTests: XCTestCase {
    func testCreateStepsMatchTheFourMiniProgramGates() {
        XCTAssertEqual(ClubCreateSteps.count, 4)
        XCTAssertFalse(ClubCreateSteps.canAdvance(step: 1, clubType: " ", name: "", nameBlocked: false, city: ""))
        XCTAssertTrue(ClubCreateSteps.canAdvance(step: 1, clubType: "兴趣社群", name: "", nameBlocked: false, city: ""))
        XCTAssertTrue(ClubCreateSteps.canAdvance(step: 2, clubType: "", name: "", nameBlocked: true, city: ""))
        XCTAssertFalse(ClubCreateSteps.canAdvance(step: 3, clubType: "兴趣社群", name: "  ", nameBlocked: false, city: ""))
        XCTAssertFalse(ClubCreateSteps.canAdvance(step: 3, clubType: "兴趣社群", name: "夜行", nameBlocked: true, city: "上海"))
        XCTAssertTrue(ClubCreateSteps.canAdvance(step: 3, clubType: "", name: "夜行", nameBlocked: false, city: ""))
        XCTAssertFalse(ClubCreateSteps.canAdvance(step: 4, clubType: "兴趣社群", name: "夜行", nameBlocked: false, city: " "))
        XCTAssertTrue(ClubCreateSteps.canAdvance(step: 4, clubType: "", name: "", nameBlocked: true, city: "上海"))
    }

    func testJoinMessageIsRequiredOnlyWhenPolicyIsOne() {
        XCTAssertTrue(ClubPlayerJoin.requiresMessage(joinPolicy: 1))
        XCTAssertFalse(ClubPlayerJoin.requiresMessage(joinPolicy: 0))
        XCTAssertFalse(ClubPlayerJoin.requiresMessage(joinPolicy: 2))
        XCTAssertFalse(ClubApplicationMessage.isValid("", for: .apply))
        XCTAssertTrue(ClubApplicationMessage.isValid("一起夜行", for: .apply))
        XCTAssertTrue(ClubApplicationMessage.isValid("", for: .join))
    }

    func testApplyStillNeedsNamePhoneAndExperienceOnTheFirstTwoSteps() {
        XCTAssertFalse(ClubHostApplyPort.canAdvance(step: 1, text: ["leaderName": "阿夜", "phone": " "]))
        XCTAssertTrue(ClubHostApplyPort.canAdvance(step: 1, text: ["leaderName": "阿夜", "phone": "13800000000"]))
        XCTAssertFalse(ClubHostApplyPort.canAdvance(step: 2, text: ["experience": ""]))
        XCTAssertTrue(ClubHostApplyPort.canAdvance(step: 2, text: ["experience": "没有经验"]))
        XCTAssertTrue(ClubHostApplyPort.canAdvance(step: 3, text: [:]))
        XCTAssertTrue(ClubHostApplyPort.canAdvance(step: 4, text: [:]))
    }

    func testNameCheckDecode() {
        XCTAssertEqual(ClubNameCheck.decode(data: Data(#"{"code":200,"data":{"available":true}}"#.utf8), status: 200), .available)
        XCTAssertEqual(ClubNameCheck.decode(data: Data(#"{"code":"200","data":{"available":false,"reason":"夜行社已存在"}}"#.utf8), status: 200), .taken("夜行社已存在"))
        XCTAssertEqual(ClubNameCheck.decode(data: Data(#"{"code":200,"data":{"available":false,"reason":"  "}}"#.utf8), status: 200), .taken(ClubNameCheck.takenFallback))
        XCTAssertEqual(ClubNameCheck.decode(data: Data(#"{"code":409,"data":{"available":false}}"#.utf8), status: 200), .unchecked)
        XCTAssertEqual(ClubNameCheck.decode(data: Data(#"{"code":200}"#.utf8), status: 200), .unchecked)
        XCTAssertEqual(ClubNameCheck.decode(data: Data("not-json".utf8), status: 200), .unchecked)
        XCTAssertEqual(ClubNameCheck.decode(data: Data(#"{"code":200,"data":{"available":true}}"#.utf8), status: 500), .unchecked)
        XCTAssertFalse(ClubNameCheck.shouldQuery("  \n"))
        XCTAssertTrue(ClubNameCheck.shouldQuery("夜行"))
        XCTAssertFalse(ClubNameCheck.allowsAdvance(.taken("占用")))
        XCTAssertTrue(ClubNameCheck.allowsAdvance(.unchecked))
        XCTAssertTrue(ClubNameCheck.allowsAdvance(.available))
    }

    func testTakenMessageRecognizesChineseAndEnglishServerText() {
        XCTAssertTrue(ClubNameCheck.isTakenMessage("俱乐部名称已被使用，请换一个"))
        XCTAssertTrue(ClubNameCheck.isTakenMessage("名称已存在"))
        XCTAssertTrue(ClubNameCheck.isTakenMessage("名称重复"))
        XCTAssertTrue(ClubNameCheck.isTakenMessage("Club name already taken"))
        XCTAssertFalse(ClubNameCheck.isTakenMessage("请稍后再试"))
        XCTAssertFalse(ClubNameCheck.isTakenMessage(nil))
    }

    func testWizardCopyHasBothLanguages() {
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        XCTAssertEqual(ClubPlayerCopy.createIntroTitle(zh), "建一个俱乐部")
        XCTAssertEqual(ClubPlayerCopy.createIntroTitle(en), "Create a club")
        XCTAssertEqual(ClubPlayerCopy.applyTitle(step: 1, locale: zh), "先认识一下你")
        XCTAssertEqual(ClubPlayerCopy.applyTitle(step: 1, locale: en), "Let’s start with you")
        XCTAssertEqual(ClubPlayerCopy.createTitle(step: 3, locale: zh), "完善俱乐部资料")
        XCTAssertEqual(ClubPlayerCopy.createTitle(step: 3, locale: en), "Complete the club profile")
        XCTAssertEqual(ClubPlayerCopy.needName(zh), "请给俱乐部起个名字")
        XCTAssertEqual(ClubPlayerCopy.quitRejoin(needsApproval: true, locale: zh), "要重新申请并等主理人通过")
        XCTAssertEqual(ClubPlayerCopy.quitRejoin(needsApproval: false, locale: en), "You can tap Join again. No approval is needed.")
        XCTAssertEqual(ClubPlayerCopy.confirmResult(zh), "确认结果")
        XCTAssertEqual(ClubPlayerCopy.confirmResult(en), "Confirm the result")
    }

    func testChinaNameCheckIsOfferedAndSendsTheTrimmedName() async throws {
        let china = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        XCTAssertTrue(ChinaReviewedRouteCapability.offersFeature("/" + ClubNameCheck.path, baseURL: china))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + ClubNameCheck.path))
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: "/" + ClubNameCheck.path))
        XCTAssertEqual(ChinaReviewedRouteCapability.callSiteCount, 996)
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 680)
        let transport = NameCheckHTTP(status: 200, body: #"{"code":200,"data":{"available":false,"reason":""}}"#)
        let service = try ClubOperationsService(configuration: .init(baseURL: china), transport: transport)
        let result = await service.checkName("  夜行  ", token: "synthetic-token")
        XCTAssertEqual(result, .taken(ClubNameCheck.takenFallback))
        XCTAssertEqual(transport.requests.count, 1)
        let body = try XCTUnwrap(transport.requests.first?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json, ["name": "夜行"])
    }

    func testOfferedHostPostsTheTrimmedNameAndStopsWhenTaken() async throws {
        let transport = NameCheckHTTP(status: 200, body: #"{"code":200,"data":{"available":false,"reason":""}}"#)
        let service = try ClubOperationsService(configuration: .init(baseURL: URL(string: "https://name-check.test")!), transport: transport)
        let blank = await service.checkName("  ", token: "synthetic-token")
        XCTAssertEqual(blank, .unchecked)
        XCTAssertTrue(transport.requests.isEmpty)
        let taken = await service.checkName("  夜行  ", token: "synthetic-token")
        XCTAssertEqual(taken, .taken(ClubNameCheck.takenFallback))
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertTrue(request.url?.path.hasSuffix(ClubNameCheck.path) == true)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["name"], "夜行")
    }

    func testNameCheckFailureStaysUnchecked() async throws {
        let transport = NameCheckHTTP(status: 200, body: #"{"code":200,"data":{"available":true}}"#, fail: true)
        let service = try ClubOperationsService(configuration: .init(baseURL: URL(string: "https://name-check.test")!), transport: transport)
        let result = await service.checkName("夜行", token: "synthetic-token")
        XCTAssertEqual(result, .unchecked)
        XCTAssertEqual(transport.requests.count, 1)
    }

    @MainActor func testAccessWithoutANameCheckDoesNotInventAnAnswer() async {
        let result = await SilentClubAccess().checkClubName("夜行")
        XCTAssertEqual(result, .unchecked)
    }
}

private final class NameCheckHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    let status: Int
    let body: String
    let fail: Bool
    init(status: Int, body: String, fail: Bool = false) {
        self.status = status
        self.body = body
        self.fail = fail
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if fail { throw URLError(.networkConnectionLost) }
        return (Data(body.utf8), status)
    }
}

@MainActor private final class SilentClubAccess: ClubOperationsAccess {
    var identity: ClubReadIdentity? { nil }
    var isConfigured: Bool { false }
    var writeAvailability: ClubOperationsWriteAvailability { .unverified }
    func snapshot(target: ClubOperationsTarget) async throws -> ClubOperationsSnapshot { throw APIError.notConfigured }
    func perform(_ command: ClubOperationsCommand, target: ClubOperationsTarget, expectedIdentity: ClubReadIdentity) async throws -> ClubOperationsReceipt {
        throw APIError.notConfigured
    }
}
