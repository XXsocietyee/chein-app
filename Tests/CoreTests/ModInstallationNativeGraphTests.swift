import XCTest
@testable import QuestifyCore

final class ModInstallationNativeGraphTests: XCTestCase {
    private var graph: String { #"{"schemaVersion":1,"branch":{"enabled":true,"startStepId":"intro","steps":[{"id":"intro","title":"Opening","body":"Complete source text","terminal":false,"options":[{"id":"continue","label":"Continue","nextStepId":"middle"}]},{"id":"middle","title":"Middle","body":"Not flattened","terminal":false,"options":[{"id":"continue","label":"Continue","nextStepId":"end"}]},{"id":"end","title":"Ending","body":"Complete ending text","terminal":true,"outcomeCode":"end","outcomeLabel":"Ending","options":[]}]}}"# }
    func testAllNodesEdgesAndEndingRemainVisible() throws {
        let parsed = try ModInstallationNativeGraph(json: graph)
        XCTAssertEqual(parsed.startStepId, "intro")
        XCTAssertEqual(parsed.steps.map(\.id), ["intro", "middle", "end"])
        XCTAssertEqual(parsed.steps[0].options.first?.nextStepId, "middle")
        XCTAssertEqual(parsed.steps[1].body, "Not flattened")
        XCTAssertEqual(parsed.steps[2].outcomeCode, "end")
    }
    func testDanglingAndCyclicGraphsAreNotPartialPreviews() {
        XCTAssertThrowsError(try ModInstallationNativeGraph(json: graph.replacingOccurrences(of: "\"nextStepId\":\"middle\"", with: "\"nextStepId\":\"absent\"")))
        XCTAssertThrowsError(try ModInstallationNativeGraph(json: graph.replacingOccurrences(of: "\"nextStepId\":\"end\"", with: "\"nextStepId\":\"intro\"")))
    }
    func testUnknownFallbackScriptAndDuplicateKeysAreNotDiscarded() {
        XCTAssertThrowsError(try ModInstallationNativeGraph(json: graph.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":true,\"fallbackChoiceId\":\"continue\"")))
        XCTAssertThrowsError(try ModInstallationNativeGraph(json: graph.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"script\":\"forbidden\"")))
        XCTAssertThrowsError(try ModInstallationNativeGraph(json: graph.replacingOccurrences(of: "\"startStepId\":\"intro\"", with: "\"startStepId\":\"intro\",\"startStepId\":\"end\"")))
    }
    func testExistingTextFactsDecodeWithoutGraphField() throws {
        let hash = String(repeating: "a", count: 64)
        let facts = ModInstallationFacts(schema: "mod-installation-facts-v1", requestId: "original", licenseId: "licensed", draftId: 1,
            merchantId: 2, bindingHash: hash, draftContentHash: hash, title: "Title", rules: "Rules", confirmed: false, bindings: [])
        XCTAssertNil(try JSONDecoder().decode(ModInstallationFacts.self, from: JSONEncoder().encode(facts)).advancedConfigJson)
    }
    func testConfirmationCannotReplaceTheReviewedGraph() throws {
        let hash = String(repeating: "a", count: 64)
        func facts(_ json: String) -> ModInstallationFacts {
            .init(schema: "mod-installation-facts-v1", requestId: "original", licenseId: "licensed", draftId: 1,
                merchantId: 2, bindingHash: hash, draftContentHash: hash, title: "Title", rules: "Rules", confirmed: true, bindings: [], advancedConfigJson: json)
        }
        try facts(graph).validateConfirmation(of: facts(graph))
        XCTAssertThrowsError(try facts(graph + " ").validateConfirmation(of: facts(graph)))
    }
}
