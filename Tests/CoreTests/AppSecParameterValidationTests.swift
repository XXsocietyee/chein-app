import XCTest
@testable import QuestifyCore

/// Task 78. Exercises the link and bridge validators already on this tip. It does not add a second parser.
final class AppSecParameterValidationTests: XCTestCase {
    private let session = DeepLinkAndUniversalLinkSafetyAudit.SessionContext(
        realmIdentifier: "cn-prod",
        isAuthenticated: true,
        accountID: 501
    )
    private let hosts: Set<String> = ["link.chengyin.example"]

    private func audit(_ raw: String) throws -> DeepLinkAndUniversalLinkSafetyAudit.AuditReport {
        let url = try XCTUnwrap(URL(string: raw), raw)
        return DeepLinkAndUniversalLinkSafetyAudit.audit(url: url, session: session, verifiedHTTPSHosts: hosts)
    }

    func testLinkParametersRejectTraversalNullBytesBackslashAndNonNumericIDs() throws {
        let malformed = [
            "https://link.chengyin.example/%2e%2e/profile?memberId=42",
            "https://link.chengyin.example/topic/%252e%252e?topicId=10",
            "https://link.chengyin.example/topic?topicId=10%00",
            "https://link.chengyin.example/club/workspace?clubId=10%00",
        ]
        for raw in malformed {
            let report = try audit(raw)
            XCTAssertEqual(report.decision, .rejected(.malformedURL), raw)
        }
        // Foundation may percent-encode a backslash (`%5C`) instead of refusing the string; the audit still rejects it.
        if URL(string: "https://link.chengyin.example/topic\\index?topicId=10") != nil {
            XCTAssertEqual(try audit("https://link.chengyin.example/topic\\index?topicId=10").decision, .rejected(.malformedURL))
        }
        XCTAssertNil(NativeNavigationContract.parseInternal("/pages/topic\\index?id=10"))
        XCTAssertNil(NativeNavigationContract.parseInternal("/subpackageMember/market/gift/index?token=a\\b"))
        XCTAssertNil(NativeNavigationContract.parseInternal("/%2e%2e/subpackagePass/reveal/index"))
        XCTAssertNil(NativeNavigationContract.parseInternal("/subpackageJourney/pages/seats/index?registrationId=abc"))

        let nonNumeric = [
            "https://link.chengyin.example/topic?topicId=abc",
            "https://link.chengyin.example/topic?topicId=10x",
            "https://link.chengyin.example/merchant/public-home?merchantId=nope",
            "https://link.chengyin.example/club/workspace?clubId=club",
        ]
        for raw in nonNumeric {
            let url = try XCTUnwrap(URL(string: raw))
            let report = try audit(raw)
            XCTAssertEqual(report.decision, .rejected(.unsupportedRoute(url.path)), raw)
        }
        XCTAssertNil(MiniProgramPageLink(path: "/subpackageJourney/pages/seats/index", query: ["registrationId": "abc"]))
        XCTAssertNil(MiniProgramPageLink(path: "/subpackageA/pages/video-bounty/index", query: ["topicId": "nope"]))
    }

    func testDecodedZeroStaysZeroAndDoesNotOpenARoute() throws {
        let zero = try audit("https://link.chengyin.example/topic?topicId=0")
        XCTAssertEqual(zero.decision, .rejected(.unsupportedRoute("/topic")))
        let decodedZero = try audit("https://link.chengyin.example/topic?topicId=%30")
        XCTAssertEqual(decodedZero.decision, .rejected(.unsupportedRoute("/topic")))
        XCTAssertNil(CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://ticket/0"))))
        XCTAssertNil(CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://landing?k=g&t=tok&aid=%30"))))
        XCTAssertNil(CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://landing?k=r&t=tok&tid=0"))))
        let absent = CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://landing?k=r&t=tok&aid=")))
        XCTAssertEqual(absent, .referral(token: "tok", activityID: nil, topicID: nil))
        XCTAssertNil(MiniProgramPageLink(path: "/subpackageJourney/pages/seats/index", query: ["registrationId": "0"]))
    }

    func testPaidRevealSpoofAndEmptyGiftTokenStayClosed() throws {
        XCTAssertNil(MiniProgramPageLink(path: "/subpackagePass/reveal/index", query: ["mode": "paid", "count": "9", "until": "2099"]))
        XCTAssertEqual(MiniProgramPageLink(path: "/subpackagePass/reveal/index", query: [:])?.query, [:])
        // MKT-3-2 (parity r1): an absent or empty gift token opens the gift page on 链接已失效 (MPParityRoute
        // `.gift(token: "")`); it never reaches a claim, so the link still carries no token.
        XCTAssertEqual(MiniProgramPageLink(path: "/subpackageMember/market/gift/index", query: ["token": ""])?.query, [:])
        XCTAssertEqual(MiniProgramPageLink(path: "/subpackageMember/market/gift/index", query: [:])?.query, [:])
        XCTAssertEqual(
            MiniProgramPageLink(path: "/subpackageMember/market/gift/index", query: ["token": "gift-token"])?.query["token"],
            "gift-token"
        )
        let spoof = "chein://mp/%2e%2e/subpackagePass/reveal/index?mode=paid&count=9&token="
        let url = try XCTUnwrap(URL(string: spoof))
        XCTAssertNil(MiniProgramPageLink(cheinURL: url))
        XCTAssertNil(CheinDeepLink(url: url))
        XCTAssertNil(CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://gift/"))))
        XCTAssertNil(CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://landing?k=g&t="))))
        XCTAssertEqual(MiniProgramPageLink(cheinURL: try XCTUnwrap(URL(string: "chein://mp/subpackageMember/market/gift/index?token=")))?.query, [:])
        XCTAssertNil(URL(string: "chein://gift/%00").flatMap(CheinDeepLink.init(url:)))
    }

    func testBridgeRejectsUnexpectedArgumentsBadKeysAndControlValues() throws {
        let manifest = ExternalGameManifest(
            id: "rpg.appsec.bridge",
            name: "AppSec",
            version: "1.0.0",
            entry: "index.html",
            permissions: ["storage", "haptics"],
            sha256: "00",
            signature: "00"
        )
        var progress: [String: String] = [:]
        let paidMeta = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "getMetadata", payload: ["mode": "paid"]))
        XCTAssertEqual(Self.bridge(paidMeta, manifest: manifest, progress: &progress).error, "INVALID_ARGUMENTS")
        let extraLoad = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "loadProgress", payload: ["extra": "1"]))
        XCTAssertEqual(Self.bridge(extraLoad, manifest: manifest, progress: &progress).error, "INVALID_ARGUMENTS")
        let meta = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "getMetadata"))
        XCTAssertTrue(Self.bridge(meta, manifest: manifest, progress: &progress).ok)
        let load = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "loadProgress"))
        XCTAssertTrue(Self.bridge(load, manifest: manifest, progress: &progress).ok)

        for key in ["%2e%2e", "a\\b", "bad/key", String(repeating: "k", count: 65)] {
            let body = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "saveProgress", payload: [key: "1"]))
            let response = Self.bridge(body, manifest: manifest, progress: &progress)
            XCTAssertEqual(response.error, "STORAGE_QUOTA_EXCEEDED", key)
            XCTAssertTrue(progress.isEmpty, key)
        }
        let control = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "saveProgress", payload: ["stage": "ok\u{0}"]))
        XCTAssertEqual(Self.bridge(control, manifest: manifest, progress: &progress).error, "STORAGE_QUOTA_EXCEEDED")
        XCTAssertTrue(progress.isEmpty)

        let badHaptic = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "haptic", payload: ["style": "paid"]))
        XCTAssertEqual(Self.bridge(badHaptic, manifest: manifest, progress: &progress).error, "INVALID_ARGUMENTS")
        let extraHaptic = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "haptic", payload: ["style": "light", "extra": "1"]))
        XCTAssertEqual(Self.bridge(extraHaptic, manifest: manifest, progress: &progress).error, "INVALID_ARGUMENTS")
        let haptic = try JSONEncoder().encode(ExternalGameBridgeRequest(action: "haptic", payload: ["style": "selection"]))
        XCTAssertTrue(Self.bridge(haptic, manifest: manifest, progress: &progress).ok)

        let number = Data("{\"apiVersion\":\"1.0\",\"action\":\"saveProgress\",\"payload\":{\"k\":1}}".utf8)
        XCTAssertEqual(
            ExternalGameBridgeHandler.handle(rawJSON: number, manifest: manifest, progressStore: &progress).error,
            "INVALID_BRIDGE_MESSAGE"
        )
        XCTAssertTrue(progress.isEmpty)
    }

    private static func bridge(
        _ rawJSON: Data,
        manifest: ExternalGameManifest,
        progress: inout [String: String]
    ) -> ExternalGameBridgeResponse {
        ExternalGameBridgeHandler.handle(rawJSON: rawJSON, manifest: manifest, progressStore: &progress)
    }
}
