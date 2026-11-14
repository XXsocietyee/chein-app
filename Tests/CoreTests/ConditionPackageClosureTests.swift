#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// CL-02: the condition packages (落地清单 EXT-01…11) and owner decision D-09, closed under the PROPOSED decisions of
/// `docs/owner-handover/SUPPLEMENT.md` refresh 3. Kept parts (EXT-04 gift, EXT-05 signed referral token, EXT-06 pass
/// library / pricing / author revenue) are cited where they already exist; dropped parts are absence checks over
/// `App` and `Core`. The two `Core/UnifiedOPT…`/`Core/Legacy52…` files are 落地清单 contract records (titles and
/// dispositions), not behaviour, so they are exempt from every absence check.
final class ConditionPackageClosureTests: XCTestCase {
    private static let contractRecords: Set<String> = [
        "Core/UnifiedOPT090To092AndEXT01To11ReleaseSignoffContract.swift",
        "Core/Legacy52TicketsAndMP01To21SliceParityContract.swift",
    ]

    // MARK: OWN-D-09 端侧范围与新业务范围

    /// OWN-D-09: native scope is the mini-program `app.json` minus WeChat-only; Flutter is not built (EXT-10).
    func testOWN_D_09_nativeScopeIsMiniProgramMinusWeChatOnlyAndNoFlutter() throws {
        let root = repoRoot()
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { !$0.path.contains("/.git/") && !$0.path.contains("/DerivedData/") && !$0.path.contains("/.build/") } ?? []
        XCTAssertFalse(files.isEmpty)
        let flutter = files.filter { $0.lastPathComponent == "pubspec.yaml" || $0.pathExtension == "dart" }
        XCTAssertEqual(flutter.map(\.path), [], "OWN-D-09 / EXT-10: Flutter is not built")

        let ext10 = try XCTUnwrap(UnifiedOPT090To092AndEXT01To11ReleaseSignoffContract.conditionalExtensions.first { $0.extID == "EXT-10" })
        XCTAssertTrue(ext10.disposition.hasPrefix("排除"))

        // Every mapped mini-program page has a native target (exists / partial / gated / merged-into / dropped).
        let pageMap = try String(contentsOf: root.appendingPathComponent("docs/parity/page-map.csv"), encoding: .utf8)
        let rows = pageMap.split(separator: "\n").dropFirst().filter { !$0.isEmpty }
        XCTAssertGreaterThanOrEqual(rows.count, 163)
        for row in rows {
            let cells = row.split(separator: ",", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
            XCTAssertGreaterThanOrEqual(cells.count, 4, String(row))
            XCTAssertFalse(cells[2].isEmpty, "page \(cells[0]) has no native target")
            XCTAssertTrue(["exists", "partial", "gated", "merged-into", "dropped"].contains(cells[3].split(separator: ":").first.map(String.init) ?? ""),
                          "page \(cells[0]) status \(cells[3])")
        }

        // WeChat-only: the phone-bind route that needs a wx.login code is not called natively.
        XCTAssertEqual(hits(#"getwxbindphone"#), [], "OWN-D-09: WeChat-only phone bind stays out")
    }

    // MARK: Kept parts (ALREADY-DONE)

    /// OWN-EXT-04: single-buyer gift kept (buy as gift, claim by token, money gated); crowdfunding dropped.
    func testOWN_EXT_04_singleBuyerGiftKeptAndCrowdfundingAbsent() throws {
        XCTAssertEqual(PlatformPass.giftsBoughtPath, "api/marketing/product/gifts/bought")
        XCTAssertEqual(PlatformPass.giftsReceivedPath, "api/marketing/product/gifts/received")
        XCTAssertEqual(PlatformPass.claimPath, "api/marketing/product/gifts/claim")
        let claim = try XCTUnwrap(JourneyLoopSource.journey.first { $0.name == .giftClaim })
        XCTAssertEqual(claim.path, "/api/marketing/product/gifts/claim")
        XCTAssertTrue(claim.money, "gift claim is a money write and stays behind the money switch")
        XCTAssertEqual(MiniProgramPageLink.reviewedPages["subpackageMember/market/gift/index"]?.required, ["token"])
        XCTAssertNotNil(MiniProgramPageLink(path: "subpackageMember/market/gift/index", query: ["token": "g-1"]))
        XCTAssertNil(MiniProgramPageLink(path: "subpackageMember/market/gift/index", query: [:]))
        XCTAssertTrue(try source("App/PassMarketViews.swift").contains("@MainActor struct PassMarketHost: View"))

        XCTAssertEqual(hits(#"crowdfund|众筹"#), [], "OWN-EXT-04: crowdfunding is dropped")
    }

    /// OWN-EXT-05: the signed referral token is kept; no multi-level distribution; attribution never from a query parameter.
    func testOWN_EXT_05_signedReferralTokenKeptAndQueryAttributionRefused() throws {
        let issue = try XCTUnwrap(JourneyLoopSource.journey.first { $0.name == .issueReferral })
        XCTAssertEqual(issue.method, "POST")
        XCTAssertEqual(issue.path, "/api/marketing/referral/token")
        XCTAssertTrue(issue.money)
        XCTAssertTrue(try source("Core/JourneyLoopSource.swift").contains(#"JourneyCase(name: .issueReferral, method: "POST", path: "/api/marketing/referral/token""#))

        // A landing carries only the signed token (k, t, aid, tid); a raw referrer / sharer / channel key rejects the link.
        let signed = try XCTUnwrap(URL(string: "chein://landing?k=r&t=signed.token&aid=12"))
        XCTAssertEqual(CheinDeepLink(url: signed), .referral(token: "signed.token", activityID: 12, topicID: nil))
        for key in ["referrer", "referrer_id", "sharer", "inviter", "uid", "channel", "utm_source"] {
            let url = try XCTUnwrap(URL(string: "chein://landing?k=r&t=signed.token&\(key)=9"))
            XCTAssertNil(CheinDeepLink(url: url), key)
        }
        XCTAssertNil(CheinDeepLink(url: try XCTUnwrap(URL(string: "chein://referral/signed.token?referrer=9"))))
        // The attribution claim is listed but no G6 method builds it from client input.
        XCTAssertTrue(G6CapabilitySource.hiddenPaths.contains("/api/marketing/attribution/claim"))

        XCTAssertEqual(hits(#"multiLevel|MultiLevel|多级分销|二级分销|commissionTier|uplineCommission"#), [],
                       "OWN-EXT-05: no multi-level distribution")
    }

    /// OWN-EXT-06: pass library, publisher pricing and the author revenue read are kept; derivative licensing is dropped.
    func testOWN_EXT_06_passLibraryPricingAndRevenueKeptAndDerivativeLicensingAbsent() throws {
        XCTAssertEqual(PlatformPass.libraryPath, "api/platform-pass/library")
        XCTAssertNotNil(MiniProgramPageLink(path: "subpackageMember/market/passes/index", query: [:]))
        XCTAssertNotNil(MiniProgramPageLink(path: "subpackageMember/market/library/index", query: [:]))
        XCTAssertTrue(try source("App/PassMembershipViews.swift").contains("@MainActor struct PassMembershipHost: View"))
        XCTAssertEqual(TopicPricingXcx.previewRoute, "/api/topic/pricing/preview")
        XCTAssertEqual(TopicPricingXcx.confirmRoute, "/api/topic/pricing/confirm")
        XCTAssertTrue(try source("App/PublisherLifecycleViews.swift").contains("TopicPricingXcx.screen("))
        XCTAssertTrue(G6CapabilitySource.paths.contains("/api/marketing/revenue/author/mine"))

        XCTAssertEqual(hits(#"二创|derivativeLicen|DerivativeLicen|takedownSettlement|TakedownSettlement"#), [],
                       "OWN-EXT-06: derivative licensing and take-down settlement are dropped")
    }

    // MARK: DROP rows (absence checks; the same greps are written in completeness-matrix.csv)

    /// OWN-EXT-01: no role room, private-clue room or host hand-off.
    func testOWN_EXT_01_noRoleRoomOrHostTransfer() {
        XCTAssertEqual(hits(#"RoleRoom|HostTransfer|hostAuthority"#), [])
    }

    /// OWN-EXT-02: no offline map tile store. `searchMap.offlineMap` is the string key of the offline placeholder label
    /// (a static map ground with the pins as buttons), not a tile pack.
    func testOWN_EXT_02_noOfflineMapTileStore() {
        XCTAssertEqual(hits(#"MKTileOverlay|offlineMap|OfflineMapPack"#, exempt: [("App/SearchMapCanvas.swift", #"Text\("searchMap\.offlineMap"\)"#)]), [])
    }

    /// OWN-EXT-03: no stored value or member card. Lower-case `storedValue` is the persisted-string parameter of
    /// preferences and template metadata (`init(storedValue:)`), and `invalidStoredValue` is a settings decode error.
    func testOWN_EXT_03_noStoredValueOrMemberCard() {
        XCTAssertEqual(hits(#"storedValue|StoredValue|储值"#, exempt: [("*", #"(\bstoredValue\b|invalidStoredValue)"#)]), [])
        XCTAssertEqual(hits(#"储值|StoredValueCard|storedValueBalance"#), [])
    }

    /// OWN-EXT-08: one renderer; no embedded script engine or VM.
    func testOWN_EXT_08_noEmbeddedScriptEngine() {
        XCTAssertEqual(hits(#"JSContext|WKWebView.*engine|import JavaScriptCore"#), [])
    }

    /// OWN-EXT-09: existing points never expire; no expiry field, copy or growth system.
    func testOWN_EXT_09_noPointExpiry() {
        XCTAssertEqual(hits(#"pointsExpire|expiringPoints|积分.*过期|pointsExpiry|PointsExpiry"#), [])
    }

    /// OWN-EXT-11: no external API client, CRDT co-editing or crowd adjudication.
    func testOWN_EXT_11_noExternalAPIClientOrCRDT() {
        XCTAssertEqual(hits(#"CRDT|Automerge|openapi/|crowdAdjudicat|CrowdAdjudicat|众裁"#), [])
    }

    // MARK: Helpers

    /// `grep -rnE <pattern> App Core` over Swift sources, minus the contract records and the listed exemptions.
    /// An exemption is (relative path or "*", regex the whole line must match).
    private func hits(_ pattern: String, exempt: [(String, String)] = []) -> [String] {
        let root = repoRoot()
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            XCTFail("bad pattern \(pattern)")
            return []
        }
        let exemptions = exempt.compactMap { entry -> (String, NSRegularExpression)? in
            (try? NSRegularExpression(pattern: entry.1)).map { (entry.0, $0) }
        }
        var found: [String] = []
        for directory in ["App", "Core"] {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
                XCTFail("missing \(directory)")
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = directory + "/" + url.path.dropFirst(base.path.count + 1)
                if Self.contractRecords.contains(relative) { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                for (index, line) in text.components(separatedBy: "\n").enumerated() {
                    let range = NSRange(line.startIndex..., in: line)
                    guard regex.firstMatch(in: line, range: range) != nil else { continue }
                    let excused = exemptions.contains { path, rule in
                        (path == "*" || path == relative) && rule.firstMatch(in: line, range: range) != nil
                    }
                    if !excused { found.append("\(relative):\(index + 1)") }
                }
            }
        }
        return found.sorted()
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
#endif
