#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes utils/access-gate.js and utils/compliance/separate-consent.js.
final class AccessGateAndSeparateConsentTests: XCTestCase {
    typealias G = AccessGateDecision

    private func merchant(active: Bool, permissions: [String] = []) throws -> MerchantAccess {
        let json = active
            ? #"{"active":true,"merchant":{"id":5,"name":"Shop"},"roleCode":"MERCHANT_MANAGER","permissions":[\#(permissions.map { "\"\($0)\"" }.joined(separator: ","))]}"#
            : #"{"active":false}"#
        return try JSONDecoder().decode(MerchantAccess.self, from: Data(json.utf8))
    }

    func testMerchantNoPrincipalMessageDeniesEvenOnHttp200Code500() {
        XCTAssertEqual(G.merchant(code: 500, message: "请先登录", access: nil, need: nil), .deny(.loginExpired))
        XCTAssertEqual(G.merchant(code: nil, message: "xx请先登录yy", access: nil, need: nil), .deny(.loginExpired))
    }

    func testMerchantAuthCodesDenyOtherFailuresAreUnknown() {
        XCTAssertEqual(G.merchant(code: 401, message: nil, access: nil, need: nil), .deny(.notMerchantMember))
        XCTAssertEqual(G.merchant(code: 403, message: "nope", access: nil, need: nil), .deny(.notMerchantMember))
        XCTAssertEqual(G.merchant(code: 500, message: "boom", access: nil, need: nil), .unknown)
        XCTAssertEqual(G.merchant(code: nil, message: nil, access: nil, need: nil), .unknown, "a lost reply never blocks")
    }

    func testMerchantInactiveDeniesAndPositionPermissionIsChecked() throws {
        XCTAssertEqual(G.merchant(code: 200, message: nil, access: try merchant(active: false), need: nil), .deny(.notMerchantMember))
        XCTAssertEqual(G.merchant(code: 200, message: nil, access: nil, need: nil), .deny(.notMerchantMember))
        let member = try merchant(active: true, permissions: ["merchant:order:read"])
        XCTAssertEqual(G.merchant(code: 200, message: nil, access: member, need: nil), .allow, "empty need = any member")
        XCTAssertEqual(G.merchant(code: 200, message: nil, access: member, need: .orders), .allow)
        XCTAssertEqual(G.merchant(code: 200, message: nil, access: member, need: .finance), .deny(.missingMerchantPosition))
    }

    func testClubFailuresMirrorMerchantGate() {
        XCTAssertEqual(G.club(code: 500, message: "请先登录", access: nil, clubID: nil, need: nil), .deny(.loginExpired))
        XCTAssertEqual(G.club(code: 403, message: nil, access: nil, clubID: nil, need: nil), .deny(.noClubAccess))
        XCTAssertEqual(G.club(code: 401, message: nil, access: nil, clubID: "1", need: nil), .deny(.noClubAccess))
        XCTAssertEqual(G.club(code: 502, message: nil, access: nil, clubID: nil, need: nil), .unknown)
        XCTAssertEqual(G.club(code: 200, message: nil, access: nil, clubID: nil, need: nil), .unknown, "200 without a body is a bad reply, not a denial")
    }

    func testClubActiveMustBeExplicit() {
        XCTAssertEqual(G.club(code: 200, message: nil, access: .init(active: nil, clubID: "1", permissions: []), clubID: nil, need: nil), .unknown)
        XCTAssertEqual(G.club(code: 200, message: nil, access: .init(active: false, clubID: "1", permissions: []), clubID: nil, need: nil), .deny(.noClubAccess))
    }

    func testClubScopeAndPermission() {
        let access = G.ClubAccess(active: true, clubID: "7", permissions: ["club:finance:read"])
        XCTAssertEqual(G.club(code: 200, message: nil, access: access, clubID: nil, need: nil), .allow)
        XCTAssertEqual(G.club(code: 200, message: nil, access: access, clubID: "7", need: "club:finance:read"), .allow)
        XCTAssertEqual(G.club(code: 200, message: nil, access: access, clubID: "8", need: nil), .deny(.notInThisClub))
        XCTAssertEqual(G.club(code: 200, message: nil, access: .init(active: true, clubID: nil, permissions: []), clubID: "7", need: nil), .deny(.notInThisClub))
        XCTAssertEqual(G.club(code: 200, message: nil, access: access, clubID: "7", need: "club:member:manage"), .deny(.missingClubPermission))
        XCTAssertEqual(G.club(code: 200, message: nil, access: access, clubID: "", need: ""), .allow, "empty strings mean not required")
    }

    // MARK: separate consent
    func testFeatureDocTypesAndScenesAreTheSourcePairs() {
        XCTAssertEqual(SeparateConsentFeature.photo.recordFields, ["docType": "photo_model_processing", "scene": "object_photo", "eventType": "AGREE"])
        XCTAssertEqual(SeparateConsentFeature.voice.recordFields, ["docType": "voice_clone_processing", "scene": "merchant_voice", "eventType": "AGREE"])
        XCTAssertEqual(SeparateConsentFeature.voice.docType, StoreCharacterVoiceConsentRecord.docType)
        XCTAssertEqual(SeparateConsentFeature.voice.scene, StoreCharacterVoiceConsentRecord.scene)
    }

    func testSeparateConsentDecisions() {
        typealias F = SeparateConsentFeature
        XCTAssertEqual(F.decide(accountID: nil, ownerStillCurrent: true, answer: .agree), .reconfirm)
        XCTAssertEqual(F.decide(accountID: 0, ownerStillCurrent: true, answer: .agree), .reconfirm)
        XCTAssertEqual(F.decide(accountID: 3, ownerStillCurrent: true, answer: .agree), .record)
        XCTAssertEqual(F.decide(accountID: 3, ownerStillCurrent: true, answer: .decline), .declined)
        XCTAssertEqual(F.decide(accountID: 3, ownerStillCurrent: false, answer: .agree), .reconfirm, "an account switch never records consent")
        XCTAssertEqual(F.decide(accountID: 3, ownerStillCurrent: false, answer: .decline), .reconfirm)
        XCTAssertEqual(F.decide(accountID: 3, ownerStillCurrent: true, answer: .dialogFailed), .notCompleted)
        XCTAssertEqual(F.decide(accountID: 3, ownerStillCurrent: true, answer: .timedOut), .notCompleted)
    }
}
#endif
<<<<<<< HEAD

=======
>>>>>>> origin/wip/gm-test
