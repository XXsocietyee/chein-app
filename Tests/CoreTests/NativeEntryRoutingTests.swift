import Foundation
import XCTest
@testable import QuestifyCore

final class NativeEntryRoutingTests: XCTestCase {
    func testDefaultPolicyAcceptsNothing() { XCTAssertNil(NativeEntryLinkPolicy().parse(URL(string: "https://example.test/door?scene=abcdef0123456789abcdef0123456789")!)) }
    func testApprovedDoorPreservesRawOneDecode() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        guard case .door(let intent) = policy.parse(URL(string: "https://example.test/door?scene=abcdef0123456789abcdef0123456789&inviter=42")!) else { return XCTFail() }
        XCTAssertEqual(intent.inviter, "42")
        XCTAssertEqual(DoorParsing.scene(intent.scene), "abcdef0123456789abcdef0123456789")
    }
    func testInvitationIsTypedWithoutMerchantGuess() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        guard case .merchantInvitation(let route) = policy.parse(URL(string: "https://example.test/merchant/team?invite=synthetic-invite-token")!) else { return XCTFail() }
        XCTAssertEqual(route.invitation.token, "synthetic-invite-token")
    }
    func testOverlongSceneRemainsUnresolved() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        guard case .door(let intent) = policy.parse(URL(string: "https://example.test/door?scene=abcdef0123456789abcdef0123456789ab")!) else { return XCTFail() }
        XCTAssertNil(DoorParsing.scene(intent.scene))
    }
    func testShortInvitationTokenIsRejected() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        XCTAssertNil(policy.parse(URL(string: "https://example.test/merchant/team?invite=synthetic-token")!))
    }
    func testRejectsSpoofingAndUnsupportedRoutes() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        for text in ["http://example.test/merchant/team?invite=a", "https://evil.test/merchant/team?invite=a", "https://u@example.test/merchant/team?invite=a", "https://example.test:443/merchant/team?invite=a", "https://example.test/merchant/team?invite=a#x", "https://example.test/merchant/team?invite=a&invite=b", "https://example.test/merchant/team?invite=a&extra=1", "https://example.test/merchant/%74eam?invite=a", "https://example.test/merchant/team?%69nvite=a", "https://example.test/other?invite=a"] { XCTAssertNil(policy.parse(URL(string: text)!), text) }
    }
    /// FP-C3: typed intents for the content destinations, without enabling any origin.
    func testContentDestinationsParseFromSourcePathsOnVerifiedOriginsOnly() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        let expected: [(String, NativeContentTarget.Kind)] = [
            ("/pages/activity/detail/index", .activity), ("/pages/club/detail/index", .club), ("/pages/topic/index/index", .topic),
            ("/pages/templatedetail/templatedetail", .template), ("/pages/square/detail/index", .post),
            ("/subpackageRoam/poi-detail/index", .poi), ("/subpackageRoam/session/index", .roamSession)]
        XCTAssertEqual(Set(expected.map(\.1)), Set(NativeContentTarget.Kind.allCases))
        for (path, kind) in expected {
            XCTAssertEqual(policy.parse(URL(string: "https://example.test\(path)?id=42")!), .content(NativeContentTarget(kind: kind, id: 42)!))
            XCTAssertEqual(NativeNavigationContract.parseInternal("\(path)?id=42"), .content(NativeContentTarget(kind: kind, id: 42)!))
            XCTAssertNil(NativeEntryLinkPolicy().parse(URL(string: "https://example.test\(path)?id=42")!), "default policy has no origins")
            XCTAssertNil(NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://other.test"]).parse(URL(string: "https://example.test\(path)?id=42")!))
        }
    }
    func testContentDestinationsRejectNonCanonicalIds() {
        let policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"])
        for query in ["", "?id=", "?id=0", "?id=-3", "?id=007", "?id=+7", "?id=1.5", "?id=abc", "?id=1&id=2", "?id=1&x=2", "?x=1", "?id=99999999999999999999"] {
            XCTAssertNil(policy.parse(URL(string: "https://example.test/pages/activity/detail/index\(query)")!), query)
        }
        XCTAssertNil(NativeContentTarget(kind: .club, id: 0)); XCTAssertNil(NativeContentTarget(kind: .club, id: -1))
        XCTAssertNil(policy.parse(URL(string: "https://example.test/pages/activity/detail/index/extra?id=1")!))
    }
}
