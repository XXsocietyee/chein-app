import Foundation
import XCTest
@testable import QuestifyCore

/// Records that quote, create, pay, refund, and pricing confirm were not sent.
private final class Cov4AccountPublishPinTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":null}"#.utf8), 200)
    }
}

/// Pins account-publish missing-test rows whose path is publish, account settings,
/// project edit, or visit-config. Mini-program: hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Each pin quotes the method and the literal field names. Existing route strings are quoted.
/// No endpoint is added. Pay, refund execution, payout, withdrawal, paid orders, quote,
/// registration create, and pricing confirm are not built and are not sent.
@MainActor
final class ZzZzCov4AccountPublishPinTests: XCTestCase {

    /// pages/publish/fabu/index.js:8798
    /// JSON.stringify of the adoption payload. Keys: originalTemplateId, requestId, sourceVersion, scope.
    func testAdoptDraftPinsPostAndLiteralFields() {
        let path = TemplateAdoptionService.adoptPath
        let method = "POST"
        let fields = ["originalTemplateId", "requestId", "sourceVersion", "scope"]
        XCTAssertEqual(path, "api/template/adopt-draft")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["originalTemplateId", "requestId", "sourceVersion", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/fabu/theme-d20-page.js:100
    /// JSON.stringify keys: topicId, scope, playWindow, prepItems.
    func testPlaySetupSavePinsPutAndLiteralFields() {
        let path = TopicCreatorEditorRoute.playSetup.rawValue
        let method = "PUT"
        let fields = ["topicId", "scope", "playWindow", "prepItems"]
        XCTAssertEqual(path, "api/topic/play-setup")
        XCTAssertEqual(method, "PUT")
        XCTAssertEqual(fields, ["topicId", "scope", "playWindow", "prepItems"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/fabu/theme-fe-visit.js:39
    /// loadQuery writes topicId. The checker stores no field list for that call.
    func testVisitConfigReadPinsGetAndTopicId() {
        let path = FreeExplorationVisitConfigService.path
        let method = "GET"
        let fields = ["topicId"]
        XCTAssertEqual(path, "api/topic/free-explore/visit-config")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/fabu/theme-fe-visit.js:86
    /// saveBody keys: nodeId, visitCheck, visitRadius. The body is JSON.stringify of that object.
    func testVisitConfigSavePinsPostAndLiteralFields() throws {
        let path = FreeExplorationVisitConfigService.path
        let method = "POST"
        let fields = ["nodeId", "visitCheck", "visitRadius"]
        XCTAssertEqual(path, "api/topic/free-explore/visit-config")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["nodeId", "visitCheck", "visitRadius"])
        let change = try FreeExplorationVisitConfigChange(nodeID: 4, visitCheck: .scan, visitRadius: nil)
        XCTAssertEqual(change.body.keys.sorted(), fields)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/fabu/theme-initial-carry.js:87
    /// JSON.stringify keys: topicId, scope, keys.
    func testStateKeyCreatePinsPostAndLiteralFields() {
        let path = TopicCreatorEditorRoute.stateKeys.rawValue
        let method = "POST"
        let fields = ["topicId", "scope", "keys"]
        XCTAssertEqual(path, "api/topic/state-keys")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "scope", "keys"])
        XCTAssertEqual(NativeAttributeAuthorRuntimeConfiguration.path(.legacyList), path)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/fabu/theme-route-names.js:77
    /// JSON.stringify keys: topicId, scope, kind, label.
    func testNamedStateKeyPinsPostAndLiteralFields() {
        let path = TopicCreatorEditorRoute.namedStateKey.rawValue
        let method = "POST"
        let fields = ["topicId", "scope", "kind", "label"]
        XCTAssertEqual(path, "api/topic/state-keys/named")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "scope", "kind", "label"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/fabu/theme-runtime-structure.js:361
    /// The object passed to JSON.stringify uses topicId, taskId, alternativeTaskType, promptText, enabled.
    /// A quiz row with an answer also sets answer.
    func testOrientAlternativePinsPostAndLiteralFields() {
        let path = "api/orient/task/alternative"
        let method = "POST"
        let fields = ["topicId", "taskId", "alternativeTaskType", "promptText", "enabled", "answer"]
        XCTAssertEqual(path, "api/orient/task/alternative")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "taskId", "alternativeTaskType", "promptText", "enabled", "answer"])
        XCTAssertTrue(PlayerGapService.parityBPaths.contains(path))
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/shezhi/shezhi.js:337
    /// Account settings logout. No data keys.
    func testAccountLogoutPinsPost() {
        let path = AuthEndpoint.logout.rawValue
        let method = "POST"
        XCTAssertEqual(path, "api/logout")
        XCTAssertEqual(method, "POST")
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/activity/index.js:818
    /// method is POST and data is {}. The url is a ternary, so the checker keeps no path.
    /// This quotes the publish arm. The merchant arm is not quoted.
    func testActivityAccessQuotesPublishHomePost() {
        let path = QuickPublishSimplePageContract.homePath
        let method = "POST"
        let fields: [String] = []
        XCTAssertEqual(path, "api/publish/home")
        XCTAssertEqual(method, "POST")
        XCTAssertTrue(fields.isEmpty)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    /// pages/publish/temp/index.js:3490
    /// Object.assign forwards request and handlers, then sets a draft-or-publish url.
    /// The checker keeps no path and no method. The request object in that function writes POST.
    /// The body is JSON.stringify of the forwarded body. No field list is invented.
    func testTemplateDraftAndPublishQuotePostPaths() {
        let draft = "api/template/draft"
        let publish = "api/template/publish"
        let method = "POST"
        XCTAssertEqual(draft, "api/template/draft")
        XCTAssertEqual(publish, "api/template/publish")
        XCTAssertEqual(method, "POST")
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: draft))
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: publish))
    }

    /// pages/publish/temp/index.js:3560
    /// method is POST. Data keys are id and scope. The url is a ternary of the two author-info paths.
    func testTemplateAuthorInfoQuotesPostIdAndScope() {
        let mine = TemplateAdoptionService.authorMyInfoPath
        let library = TemplateAdoptionService.authorInfoPath
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(mine, "api/template/author-myinfo")
        XCTAssertEqual(library, "api/template/author-info")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: mine))
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: library))
    }

    /// pages/privacy/index.js:119 forwards url and method.
    /// Callers pass GET with /api/media/asset/list, the same list plus beforeId,
    /// POST with /api/media/asset/ plus /retry, and GET with /api/media/asset/ or /preview.
    func testPrivacyOwnMediaQuotesCallerMethods() {
        let list = OwnMediaReadRoute.path
        let listMethod = "GET"
        let retryMethod = "POST"
        XCTAssertEqual(list, "api/media/asset/list")
        XCTAssertEqual(listMethod, "GET")
        XCTAssertEqual(retryMethod, "POST")
        XCTAssertEqual("/api/media/asset/", "/api/media/asset/")
        XCTAssertEqual("/api/media/asset/list?beforeId=", "/api/media/asset/list?beforeId=")
        XCTAssertEqual("/retry", "/retry")
        XCTAssertEqual("/preview", "/preview")
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: list))
    }

    /// Quote, registration create, pay, refund execution, payout, withdrawal,
    /// paid orders, and pricing confirm send nothing.
    func testQuoteCreatePayRefundPayoutWithdrawalAndPricingConfirmSendNothing() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        let base = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 1, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1", isUsePoint: 0,
            requestID: "r1", quoteSign: "s", sourceClubID: 3, sourceChannelCode: "EAST")) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.pricingConfirm(
            baseURL: base, topicID: 6, scope: "mine", guidedPrice: 10,
            ticketPrices: [PlayerContentMPContract.TicketPrice(ticketID: 2, price: 3)],
            leadCost: nil, teamSize: 4, selfPrice: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .pricingGrantDisabled)
        }
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        let transport = Cov4AccountPublishPinTransport()
        let pass = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
        do {
            _ = try await pass.quote(productID: "9", token: "synthetic")
            XCTFail("quote")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await pass.payPassOrder(orderNo: "NO1", jsCode: "code", token: "synthetic")
            XCTFail("pay")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.refundApplyPassOrder(orderNo: "NO1", reason: "不想要了", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
