import XCTest
import Foundation
@testable import QuestifyCore

/// WP-04 owner-decision guards (DEC-01 / DEC-04 / DEC-05 / DEC-07 and the release boundary).
/// Source-text scans are read-only and deterministic: no network, no clock, no Keychain.
@MainActor final class WP04OwnerDecisionGuardTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("cannot read \(relative)", file: file, line: line)
            throw CocoaError(.fileReadNoSuchFile)
        }
        return text
    }

    /// All Swift files under a repo-relative directory, as (relativePath, text).
    private func swiftSources(under directory: String) throws -> [(String, String)] {
        let base = repoRoot.appendingPathComponent(directory)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
            XCTFail("cannot enumerate \(directory)"); return []
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                out.append(("\(directory)/\(url.lastPathComponent)", text))
            }
        }
        XCTAssertFalse(out.isEmpty, "no Swift sources found under \(directory)")
        return out
    }

    /// Drops `//` comments so a guard never trips on prose that explains the prohibition.
    private func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> Substring in
            if let range = line.range(of: "//") { return line[line.startIndex..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// `code(_:)` with string-literal contents blanked, so route strings like "order/refund-quote" are not arithmetic.
    private func codeWithoutStrings(_ text: String) -> String {
        let stripped = code(text)
        guard let regex = try? NSRegularExpression(pattern: #""(?:[^"\\\n]|\\.)*""#) else { return stripped }
        return regex.stringByReplacingMatches(in: stripped, range: NSRange(location: 0, length: (stripped as NSString).length), withTemplate: "\"\"")
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { XCTFail("bad pattern"); return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    // DEC-01: channels are never moved between guilds/categories by the client.
    func testManagementTransportHasNoChannelMoveRoute() throws {
        let files = try swiftSources(under: "Core").filter { $0.0.contains("NativeChannelManagement") || $0.0.contains("NativeTeamChannelManagement") }
        XCTAssertFalse(files.isEmpty)
        let forbidden = #"(?i)(channel[-_/]?platform/[A-Za-z_/-]*move|channels?/move|move[-_]?channel|moveChannel|reparent|transfer[-_]?channel)"#
        for (path, text) in files {
            XCTAssertEqual(matches(forbidden, in: code(text)), [], "channel move route/symbol in \(path)")
        }
        let models = try source("Core/NativeChannelManagementModels.swift")
        XCTAssertEqual(matches(#"(?i)\bcase\s+move\w*"#, in: code(models)), [], "error/capability enum grew a move case")
    }

    // DEC-05: no random team-up. Existing symbols only *reject* cancelled legacy matchmaking.
    func testNoRandomTeamMatchmakingSymbolsInAppOrCore() throws {
        let forbidden = #"(?i)\b\w*(startMatchmaking|joinMatchmaking|requestMatchmaking|randomTeam|randomMatch|randomPair|randomTeammate|autoTeam|quickMatch|findRandom|matchRandom|teamUpRandom)\w*"#
        for directory in ["Core", "App"] {
            for (path, text) in try swiftSources(under: directory) {
                XCTAssertEqual(matches(forbidden, in: code(text)), [], "random matchmaking symbol in \(path)")
            }
        }
        // The only tolerated matchmaking mentions are the existing reject-only legacy checks.
        let allowed: Set<String> = ["Core/OrdinaryCityCourseSelector.swift", "Core/TeamClubEligibilityProjection.swift"]
        for directory in ["Core", "App"] {
            for (path, text) in try swiftSources(under: directory) where !allowed.contains(path) {
                XCTAssertEqual(matches(#"(?i)matchmak\w*"#, in: code(text)), [], "new matchmaking use in \(path)")
            }
        }
        let projection = try source("Core/TeamClubEligibilityProjection.swift")
        XCTAssertTrue(projection.contains("rejectsCancelledMatchmaking"))
    }

    // DEC-07: cancel quote stays unavailable until a server contract exists.
    func testFreeExploreCancelQuoteStillUnavailableWithoutServerContract() async throws {
        let gated = GatedFreeExploreReservationCanceler()
        let quote = await gated.quote(reservationID: "1", useWaiver: false)
        XCTAssertEqual(quote, .unavailable)
        let cancel = await gated.cancel(reservationID: "1", useWaiver: false, expectedOutcome: "server-value")
        XCTAssertEqual(cancel, .unavailable)

        let model = FreeExploreCancelModel(canceler: gated)
        await model.requestQuote(reservationID: "1", useWaiver: true)
        XCTAssertEqual(model.state, .unavailable)
        await model.confirm()
        XCTAssertEqual(model.state, .unavailable, "confirm without a server quote must not progress")

        let coordinator = try code(source("Core/FreeExploreLaunchCoordinator.swift"))
        XCTAssertTrue(coordinator.contains("throw FreeExploreLaunchFailure.cancellationQuoteUnavailable"))
        XCTAssertFalse(coordinator.contains("cancel-quote"), "coordinator must not dispatch a cancel quote route yet")
    }

    func testNoClientSideRefundArithmeticInFreeExploreCore() throws {
        let files = try swiftSources(under: "Core").filter { $0.0.contains("FreeExplore") }
        XCTAssertFalse(files.isEmpty)
        let arithmetic = #"(?i)\b(refund|fee|deposit|price|amount|cents|fen)\w*\s*[-+*/]\s*\(?\s*[A-Za-z0-9_.]+"#
        let assigned = #"(?i)\b(let|var)\s+\w*(refund|penalty|deduct)\w*\s*(:\s*[A-Za-z0-9<>?]+\s*)?=\s*[^\n]*[-+*/]"#
        for (path, text) in files {
            let body = codeWithoutStrings(text)
            XCTAssertEqual(matches(arithmetic, in: body), [], "refund-like arithmetic in \(path)")
            XCTAssertEqual(matches(assigned, in: body), [], "computed refund/penalty value in \(path)")
        }
        let cancelFlow = try source("Core/FreeExploreCancelFlow.swift")
        XCTAssertTrue(cancelFlow.contains("expectedOutcome: quote.expectedOutcome"), "expectedOutcome must come from the server quote")
    }

    // Release boundary: the shipped composition has no reviewed deployment.
    func testShippedCompositionIsUnconfigured() throws {
        let text = code(try source("App/RegionalLaunchConfiguration.swift"))
        XCTAssertTrue(text.contains("makeComposition(reviewed: nil, build: .current)"))
        XCTAssertTrue(text.contains("guard let reviewed else"))
        XCTAssertTrue(text.contains(".init(deployment: .unconfigured"))
        // No code path in the shipped property builds a reviewed deployment.
        guard let start = text.range(of: "static var composition"), let end = text.range(of: "static func reviewedDeployment") else {
            return XCTFail("composition property not found")
        }
        let property = String(text[start.lowerBound..<end.lowerBound])
        XCTAssertFalse(property.contains("reviewedComposition"))
        XCTAssertFalse(property.contains("reviewedDeployment"))
        XCTAssertEqual(matches(#"makeComposition\(reviewed:\s*(?!nil)"#, in: property), [])
        // The approved-URL registry stays empty.
        XCTAssertTrue(text.contains("let approved:[RegionalMarket:Set<String>]=[:]"))
        XCTAssertTrue(text.contains("verifiedCapabilities:[]"))
    }

    // DEC-04: no feature is enabled or disabled from a minor/age signal in the client.
    func testNoMinorAgeDerivedFeatureEnablement() throws {
        let forbidden = #"\b\w*(isMinor|isUnder18|isUnderage|underAge|minorMode|minorFlag|isAdult|ageBand|ageYears|birthDate|dateOfBirth|birthday)\w*"#
        for directory in ["Core", "App"] {
            for (path, text) in try swiftSources(under: directory) {
                XCTAssertEqual(matches(forbidden, in: code(text)), [], "age/minor-derived enablement symbol in \(path)")
            }
        }
    }
}
