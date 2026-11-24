import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// P2: story-lock gate, #866 fields, photo-record, visit-config gate, and the one arrival channel.
final class PlayRuntimePortTests: XCTestCase {
    private func nodes(_ extra: String, node: String) throws -> PlayNodesResult {
        try JSONDecoder().decode(PlayNodesResult.self, from: Data(#"{"mode":2,"playable":true,"nodes":[\#(node)]\#(extra)}"#.utf8))
    }

    func testMissingStoryLockedIsNotLockedUntilTheGateIsOn() throws {
        let node = #"{"nodeId":1,"name":"桥"}"#
        let snapshot = try PlaySnapshot(scope: .topic(9), result: try nodes("", node: node))
        XCTAssertFalse(PlayRuntimePortRouteGate.storyLockMissingCountsAsLocked)
        XCTAssertFalse(snapshot.isStoryLocked(snapshot.visibleNodes[0]))
        #if DEBUG
        PlayRuntimePortRouteGate.testStoryLockMissingCountsAsLocked = true
        defer { PlayRuntimePortRouteGate.testStoryLockMissingCountsAsLocked = nil }
        XCTAssertTrue(snapshot.isStoryLocked(snapshot.visibleNodes[0]))
        #endif
        let explicit = try PlaySnapshot(scope: .topic(9), result: try nodes("", node: #"{"nodeId":1,"storyLocked":false,"visited":true}"#))
        XCTAssertFalse(explicit.isStoryLocked(explicit.visibleNodes[0]))
        XCTAssertTrue(explicit.isVisited(explicit.visibleNodes[0]))
        let city = try JSONDecoder().decode(PlayNodesResult.self, from: Data(#"{"mode":1,"playable":true,"nodes":[{"nodeId":1}]}"#.utf8))
        let citySnapshot = try PlaySnapshot(scope: .topic(9), result: city)
        XCTAssertFalse(citySnapshot.isStoryLocked(citySnapshot.visibleNodes[0]))
    }

    func testRunStartAltStationsPerkAndAddressHidden() throws {
        let result = try nodes(#","runStartMode":"ALT","perkOnly":true,"altStations":[{"id":3,"name":"东门","longitude":121.5,"latitude":31.2},{"id":3,"name":"dup"},{"id":0},{"name":"no id"}]"#,
                               node: #"{"nodeId":1,"addressHidden":true,"perk":{"included":true,"extraSpendText":"加 2","reserveRequired":false},"feedbackText":"到过","picUrl":"https://a.example/1.jpg","done":true}"#)
        XCTAssertEqual(result.runStartMode, .alt)
        XCTAssertEqual(result.perkOnly, true)
        XCTAssertEqual(result.altStations.map(\.id), [3])
        XCTAssertEqual(result.altStations.first?.name, "东门")
        let node = result.nodes[0]
        XCTAssertEqual(node.addressHidden, true)
        XCTAssertEqual(node.perk?.included, true)
        XCTAssertEqual(node.perk?.extraSpendText, "加 2")
        XCTAssertEqual(node.feedbackText, "到过")
        XCTAssertEqual(node.photoURL, "https://a.example/1.jpg")
        let plain = try nodes(#","runStartMode":"MAYBE","altStations":"bad","perkOnly":"yes""#, node: #"{"nodeId":1,"addressHidden":"maybe","perk":{"included":"yes"}}"#)
        XCTAssertNil(plain.runStartMode)
        XCTAssertTrue(plain.altStations.isEmpty)
        XCTAssertNil(plain.perkOnly)
        XCTAssertNil(plain.nodes[0].perk)
        let facts = FreeExplorationStoryFacts(snapshot: try PlaySnapshot(scope: .topic(9), result: result))
        XCTAssertTrue(facts.isPerkOnly)
        let offered = [PlayAltStation(id: 3, name: nil, longitude: nil, latitude: nil)]
        XCTAssertEqual(try PlayRunStartRequest(mode: .desk).fields, ["startMode": "DESK"])
        XCTAssertEqual(try PlayRunStartRequest(mode: .alt, altStationID: 3, offered: offered).fields, ["startMode": "ALT", "altStationId": "3"])
        XCTAssertThrowsError(try PlayRunStartRequest(mode: .alt, altStationID: 4, offered: offered))
        XCTAssertThrowsError(try PlayRunStartRequest(mode: .desk, altStationID: 3, offered: offered))
        XCTAssertEqual(PlayCompletionModePresentation(raw: "ASSISTED")?.titleKey, "playx.completion.assisted")
        XCTAssertNil(PlayCompletionModePresentation(raw: "DESK"))
    }

    func testRunPhotosAndEvidenceStayOnFinishedNodes() throws {
        let result = try JSONDecoder().decode(PlayNodesResult.self, from: Data(#"""
        {"mode":1,"playable":true,"total":3,"doneCount":3,"nodes":[
          {"nodeId":1,"name":"钟楼","done":true,"picUrl":"https://a.example/1.jpg","feedbackText":"钟声"},
          {"nodeId":2,"name":"桥","done":true,"picUrl":null},
          {"nodeId":3,"name":"井","done":false,"picUrl":"https://a.example/3.jpg","feedbackText":"未完成"}]}
        """#.utf8))
        let snapshot = try PlaySnapshot(scope: .topic(9), result: result)
        XCTAssertEqual(PlayRunKeepsakes.photos(in: snapshot).map(\.id), [1])
        XCTAssertEqual(PlayRunKeepsakes.evidence(in: snapshot).map(\.text), ["钟声"])
    }

    func testPhotoRecordAcceptsRecordBodiesAndRejectsTheOrdinaryWrite() {
        XCTAssertEqual(PlayPhotoRecordSubmission.validate(mode: "RECORD", imageURL: nil, textConfirmed: true, submitPhotoCheck: false), .success(.textConfirmed))
        XCTAssertEqual(PlayPhotoRecordSubmission.validate(mode: "RECORD", imageURL: "https://a.example/p.jpg", textConfirmed: false, submitPhotoCheck: false), .success(.image("https://a.example/p.jpg")))
        XCTAssertEqual(PlayPhotoRecordSubmission.validate(mode: "RECORD", imageURL: "https://a.example/p.jpg", textConfirmed: false, submitPhotoCheck: true), .failure(.submitPhotoCheckOnRecord))
        XCTAssertEqual(PlayPhotoRecordSubmission.validate(mode: "PHOTO", imageURL: nil, textConfirmed: true, submitPhotoCheck: false), .failure(.textConfirmedOnOrdinary))
        XCTAssertEqual(PlayPhotoRecordSubmission.validate(mode: "RECORD", imageURL: "http://a.example/p.jpg", textConfirmed: false, submitPhotoCheck: false), .failure(.imageURL))
    }

    func testHiddenStationPhotoDoesNotWinTheChain() throws {
        let result = try JSONDecoder().decode(PlayNodesResult.self, from: Data(#"""
        {"mode":1,"topicCover":"https://x.example/t.jpg","chapters":[{"chapterId":81,"imgArr":"https://x.example/c.jpg"}],
         "nodes":[{"nodeId":7,"chapterId":81,"imgUrl":"https://x.example/secret.jpg","imgHidden":true}]}
        """#.utf8))
        XCTAssertEqual(PlayStationImageResolver.station(for: result.nodes[0], in: result).source, "https://x.example/c.jpg")
        XCTAssertEqual(PlayStationImageResolver.station(for: result.nodes[0], in: result).tier, .chapter)
    }

    func testVisitConfigGateIsDefaultOffAndOutsideTheMarkTable() async throws {
        XCTAssertFalse(PlayRuntimePortRouteGate.freeExploreVisitConfigRead)
        XCTAssertFalse(PlayRuntimePortRouteGate.freeExploreVisitConfigWrite)
        XCTAssertEqual(PlayRuntimePortRouteGate.visitConfigMark, .liveInProduction)
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: PlayRuntimePortRouteGate.visitConfigPath))
        let configuration = try APIConfiguration(baseURL: URL(string: "https://fixture.example")!)
        let service = FreeExplorationVisitConfigService(configuration: configuration, transport: VisitConfigStub(), token: { "fixture-token" })
        do {
            _ = try await service.load(topicID: 9)
            XCTFail("default-off reads must not send")
        } catch let error as FreeExplorationVisitConfigError {
            XCTAssertEqual(error, .disabled)
        }
    }

    func testStationArrivalUsesTheExistingArriveChannel() throws {
        XCTAssertEqual(PlayCompletionEvidence.stationArrival.path, "arrive")
        XCTAssertEqual(PlayCompletionEvidence.location(longitude: 1, latitude: 2, coordinateSystem: "GCJ02").path, "arrive")
        let service = PlayExperienceService(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example")!),
                                             transport: VisitConfigStub(), enabled: [.classicCompletion])
        let request = try service.completionRequest(scope: .topic(9), nodeID: 7, evidence: .stationArrival, advance: nil, token: "synthetic", boundary: "b")
        XCTAssertEqual(request.url?.path, "/api/play/arrive")
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        XCTAssertFalse(body.contains("longitude"))
        XCTAssertTrue(body.contains("name=\"nodeId\""))
    }
}

private final class VisitConfigStub: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        (Data(#"{"code":200,"data":[]}"#.utf8), 200)
    }
}
