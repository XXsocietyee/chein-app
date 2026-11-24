import XCTest
@testable import QuestifyCore

/// Capability list derived from the kits this build renders. Platform stays `ios-native`.
/// Role views and the filter-shot sensor are not claimed: those renderers are not in this package.
@available(macOS 14.0, *)
@MainActor final class PlayClientCapabilitiesTests: XCTestCase {
    func testEveryNativePlayKitIsDeclaredWithServerSectionNaming() {
        let keys = Set(PlayClientCapabilities.keys)
        for kind in PlayKitScreenKind.allCases {
            XCTAssertTrue(keys.contains("game." + kind.rawValue.lowercased()), kind.rawValue)
        }
        XCTAssertTrue(keys.contains("game.hangman"))
        XCTAssertTrue(keys.contains("game.hiddenobject"))
        XCTAssertFalse(keys.contains("game.hangman".replacingOccurrences(of: "hangman", with: "teamCooperation")))
    }

    func testOurRenderersDeclarePoolAndAnswerKitsWithoutForeignKeys() {
        let keys = Set(PlayClientCapabilities.keys)
        let expected: Set<String> = [
            "chapter.blocks", "route.branch", "theme.runtime", "station.list",
            "media.image", "media.audio", "media.photo", "location.gps",
            "answer.arrive", "answer.gps", "answer.text", "answer.choice", "answer.photo", "answer.scan",
            "answer.preference", "answer.sensor", "answer.estimate", "answer.pricePair", "answer.hiddenObject",
            "sensor.still", "sensor.steps", "sensor.audio_clip",
            "hangman.pool", "qa.letterPool", "game.hangman",
        ]
        XCTAssertTrue(keys.isSuperset(of: expected), "missing: \(expected.subtracting(keys).sorted())")
        for absent in ["role.views", "sensor.filter_shot", "media.photo.record"] {
            XCTAssertFalse(keys.contains(absent), absent)
        }
        XCTAssertEqual(PlayClientCapabilities.keys, PlayClientCapabilities.keys.sorted())
        XCTAssertEqual(Set(PlayClientCapabilities.keys).count, PlayClientCapabilities.keys.count)
        XCTAssertEqual(PlayClientCapabilities.platform, "ios-native")
    }

    func testTokensUseKeyAtVersion() {
        XCTAssertTrue(PlayClientCapabilities.tokens.allSatisfy { $0.hasSuffix("@1") && !$0.hasPrefix("@") })
        XCTAssertEqual(PlayClientCapabilities.declaration(["hangman.pool", "game.hangman"]), "game.hangman@1,hangman.pool@1")
        let fields = PlayClientCapabilities.startFields(clientVersion: "9.9")
        XCTAssertEqual(fields["clientPlatform"], .string("ios-native"))
        XCTAssertEqual(fields["clientVersion"], .string("9.9"))
        XCTAssertNil(PlayClientCapabilities.startFields(clientVersion: nil)["clientVersion"])
        XCTAssertNil(PlayClientCapabilities.startFields(clientVersion: "bad version!")["clientVersion"])
    }

    func testAdvancedStartSendsTheDeclaration() async throws {
        let wire = PlayRecoveryRecordingTransport()
        wire.responses["/api/play/advanced/start"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.advanced), 200)
        let service = PlayExperienceService(configuration: try .init(baseURL: URL(string: "https://example.test")!), transport: wire, enabled: [.reads, .advanced])
        _ = try await service.startAdvanced(activityID: 41, topicID: 71, nodeID: 701, token: "synthetic")
        let body = try XCTUnwrap(wire.requests.first?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["clientPlatform"] as? String, "ios-native")
        XCTAssertEqual(json["nodeId"] as? Int, 701)
        XCTAssertEqual(json["activityId"] as? Int, 41)
        XCTAssertEqual(json["topicId"] as? Int, 71)
        let declared = try XCTUnwrap(json["supportedCapabilities"] as? [String])
        XCTAssertEqual(declared, PlayClientCapabilities.tokens)
        for key in ["hangman.pool@1", "qa.letterPool@1", "game.hangman@1", "answer.estimate@1", "chapter.blocks@1", "route.branch@1"] {
            XCTAssertTrue(declared.contains(key), key)
        }
        XCTAssertFalse(declared.contains("role.views@1"))
    }
}
