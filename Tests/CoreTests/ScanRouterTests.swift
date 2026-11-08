import XCTest
@testable import QuestifyCore

/// FP-C7: scanned text is classified by one pure router. Nothing here opens or writes anything.
final class ScanRouterTests: XCTestCase {
    private let verified = ScanRouter(links: NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://example.test"]))
    func testDefaultRouterRoutesNoHTTPSLink() {
        let router = ScanRouter()
        XCTAssertEqual(router.route("https://example.test/pages/activity/detail/index?id=5"), .unrecognized)
        XCTAssertEqual(router.route("https://example.test/door?scene=abcdef0123456789abcdef0123456789"), .unrecognized)
    }
    func testVerifiedOriginRoutesDoorAndContentLinks() {
        guard case .entry(.door(let door)) = verified.route("https://example.test/door?scene=abcdef0123456789abcdef0123456789&inviter=42") else { return XCTFail() }
        XCTAssertEqual(door.inviter, "42")
        XCTAssertEqual(verified.route("https://example.test/pages/activity/detail/index?id=5"), .entry(.content(NativeContentTarget(kind: .activity, id: 5)!)))
        XCTAssertEqual(verified.route("  https://example.test/pages/club/detail/index?id=9 "), .entry(.content(NativeContentTarget(kind: .club, id: 9)!)))
    }
    func testMiniProgramSourcePathsRouteWithOrWithoutLeadingSlash() {
        for text in ["/pages/topic/index/index?id=3", "pages/topic/index/index?id=3"] {
            XCTAssertEqual(ScanRouter().route(text), .entry(.content(NativeContentTarget(kind: .topic, id: 3)!)), text)
        }
        XCTAssertEqual(ScanRouter().route("subpackageRoam/session/index?id=8"), .entry(.content(NativeContentTarget(kind: .roamSession, id: 8)!)))
    }
    func testEverythingElseIsUnrecognizedAndNeverGuessed() {
        let long = "https://example.test/" + String(repeating: "a", count: 9000)
        for text in [nil, "", "   ", "http://example.test/door?scene=abcdef0123456789abcdef0123456789", "https://evil.test/door?scene=abcdef0123456789abcdef0123456789",
                     "weixin://dl/business", "javascript:alert(1)", "TICKET-12345678", "0123456789abcdef", "pages/activity/detail/index?id=0",
                     "pages/unknown/page?id=1", "https://example.test/pages/activity/detail/index?id=1\n", long] as [String?] {
            XCTAssertEqual(verified.route(text), .unrecognized, text ?? "nil")
        }
    }
}
