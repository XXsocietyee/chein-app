import XCTest
@testable import QuestifyCore

/// Pins closed literal request shapes for the account-publish coverage lane that
/// ends before `pages/publish/fabu/theme-runtime-structure.js`.
/// A call whose data is not a closed object literal is left unpinned.
/// None of these paths are money writes. No money gate is turned on, and these tests send nothing.
@MainActor
final class AccountPublishLaneAContractTests: XCTestCase {
    func testAddressDeletePinsId() throws {
        let method = "POST"
        let fields = ["id"]
        let mutation = ParticipantMutation.delete(id: 9)
        XCTAssertEqual(mutation.path, "api/user/address/delete")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(try mutation.fields().keys.sorted(), fields)
        XCTAssertEqual(fields, ["id"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/user/address/delete"))
    }

    func testAddressInfoPinsId() {
        let method = "POST"
        let fields = ["id"]
        XCTAssertTrue(ProfileParticipantAccess.readPaths.contains("api/user/address/info"))
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/user/address/info"))
    }

    func testNicknameCheckPinsNickname() {
        let path = "api/user/nickname/check"
        let method = "POST"
        let fields = ["nickname"]
        XCTAssertEqual(path, "api/user/nickname/check")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["nickname"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    func testBindPhonePinsCode() {
        let path = "api/getwxbindphone"
        let method = "POST"
        let fields = ["code"]
        XCTAssertEqual(path, "api/getwxbindphone")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["code"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    func testActivityPublishPrecheckPinsScope() {
        let method = "POST"
        let fields = ["scope"]
        XCTAssertTrue(PlayerGapService.paths.contains("api/activity/publish_precheck"))
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/activity/publish_precheck"))
    }

    func testActivityTemplateListPinsIsQuoteAndKeyword() {
        let method = "POST"
        let fields = ["is_quote", "keyword"]
        XCTAssertTrue(MemberRound2Service.paths.contains("api/template/my-list"))
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["is_quote", "keyword"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/my-list"))
    }

    func testCollaboratorListPinsPageNumPageSizeAndKeyword() {
        let method = "POST"
        let fields = ["keyword", "pageNum", "pageSize"]
        XCTAssertEqual(PublishingRead.collaborators(keyword: "city").request.path, "api/user/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["keyword", "pageNum", "pageSize"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/user/list"))
    }

    func testBindingStatusPinsTopicIdAndScope() {
        let method = "POST"
        let fields = ["scope", "topicId"]
        XCTAssertEqual(TemplateAdoptionService.bindingStatusPath, "api/template/topic-template/binding-status")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["scope", "topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/topic-template/binding-status"))
    }

    func testAuthorEditDetailPinsIdAndScope() {
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(TopicCreatorEditorRoute.authorEditDetail.rawValue, "api/topic/author-edit-detail")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/topic/author-edit-detail"))
    }

    func testAttributeBindingPinsTopicIdAndScope() {
        let method = "GET"
        let fields = ["scope", "topicId"]
        XCTAssertEqual(TopicCreatorEditorRoute.attributeBinding.rawValue, "api/topic/attribute-binding")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["scope", "topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/topic/attribute-binding"))
    }

    func testAuthorSavedDetailPinsIdAndScope() {
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertTrue(PlayerGapService.parityBPaths.contains("api/topic/author-saved-detail"))
        XCTAssertEqual(TopicCreatorEditorRoute.authorSavedDetail.rawValue, "api/topic/author-saved-detail")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/topic/author-saved-detail"))
    }

    func testAdoptionSourcePinsOriginalTemplateIdAndScope() {
        let method = "GET"
        let fields = ["originalTemplateId", "scope"]
        XCTAssertEqual(TemplateAdoptionService.sourcePath, "api/template/adoption-source")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["originalTemplateId", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/adoption-source"))
    }

    func testAdoptionReceiptPinsRequestIdAndScope() {
        let method = "GET"
        let fields = ["requestId", "scope"]
        XCTAssertEqual(TemplateAdoptionService.receiptPath, "api/template/adoption-receipt")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["requestId", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/adoption-receipt"))
    }

    func testAdoptionDetailPinsRequestIdAndScope() {
        let method = "GET"
        let fields = ["requestId", "scope"]
        XCTAssertEqual(TemplateAdoptionService.detailPath, "api/template/adoption-detail")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["requestId", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/adoption-detail"))
    }

    func testAuthorMyInfoPinsIdAndScopeForAdoptionDraft() {
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(TemplateAdoptionService.authorMyInfoPath, "api/template/author-myinfo")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/author-myinfo"))
    }

    func testAuthorMyInfoPinsIdAndScopeForNodeBind() {
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(TemplateAdoptionService.authorMyInfoPath, "api/template/author-myinfo")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/author-myinfo"))
    }

    func testAuthorMyInfoPinsIdAndScopeForCopy() {
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(TemplateAdoptionService.authorMyInfoPath, "api/template/author-myinfo")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/author-myinfo"))
    }

    func testAuthorMyInfoPinsIdAndScopeForDetailLoad() {
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(TemplateAdoptionService.authorMyInfoPath, "api/template/author-myinfo")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/author-myinfo"))
    }

    func testFabuTemplateListPinsIsQuoteDraftStatusAndScope() {
        let method = "POST"
        let fields = ["draft_status", "is_quote", "scope"]
        XCTAssertTrue(MemberRound2Service.paths.contains("api/template/my-list"))
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["draft_status", "is_quote", "scope"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/template/my-list"))
    }

    func testPublishCheckPinsTopicIdAndScope() {
        let method = "GET"
        let fields = ["scope", "topicId"]
        XCTAssertEqual(NativeAttributeAuthorRuntimeConfiguration.path(.publishCheck), "api/topic/publish-check")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["scope", "topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/topic/publish-check"))
    }

    func testCastVoicePinsTopicIdAndPreset() {
        let path = "api/topic/cast/voice"
        let method = "GET"
        let fields = ["preset", "topicId"]
        XCTAssertEqual(path, "api/topic/cast/voice")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["preset", "topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path))
    }

    func testPlaySetupPinsTopicIdAndScope() {
        let method = "GET"
        let fields = ["scope", "topicId"]
        XCTAssertEqual(TopicCreatorEditorRoute.playSetup.rawValue, "api/topic/play-setup")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["scope", "topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/topic/play-setup"))
    }

    func testStateKeysPinsTopicIdAndScope() {
        let method = "GET"
        let fields = ["scope", "topicId"]
        XCTAssertEqual(NativeAttributeAuthorRuntimeConfiguration.path(.legacyList), "api/topic/state-keys")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["scope", "topicId"])
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "api/topic/state-keys"))
    }
}
