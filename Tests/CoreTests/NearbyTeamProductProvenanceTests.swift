import XCTest
@testable import QuestifyCore

final class NearbyTeamProductProvenanceTests: XCTestCase {
    private func row(_ fields: String) throws -> NearbyTeam {
        try JSONDecoder().decode(NearbyTeam.self, from: Data(("{\"teamId\":503" + fields + "}").utf8))
    }

    func testKnownSourceProductTypesUseExistingLabels() throws {
        XCTAssertEqual(try row(",\"productType\":1").productLabelKey, "nearby.urbanExplore")
        XCTAssertEqual(try row(",\"productType\":2").productLabelKey, "nearby.freeExplore")
        XCTAssertEqual(try row(",\"productType\":\"2\"").productLabelKey, "nearby.freeExplore")
    }

    func testMissingInvalidAndFutureProductsDoNotBecomeCityMode() throws {
        for fields in ["", ",\"productType\":null", ",\"productType\":99", ",\"productType\":0", ",\"productType\":-1", ",\"productType\":\"unknown\"", ",\"productType\":true"] {
            XCTAssertNil(try row(fields).productLabelKey)
        }
    }

    func testFutureRawProductAndExistingIdentityArePreserved() throws {
        let value = try row(",\"productType\":99,\"activityId\":42,\"viewerStatus\":\"PENDING\"")
        XCTAssertEqual(value.productType, 99)
        XCTAssertEqual(value.activityID, 42)
        XCTAssertEqual(value.viewerStatus, .pending)
        XCTAssertEqual(value.teamID, NearbyTeamID(503))
        XCTAssertNil(value.productLabelKey)
    }
}
