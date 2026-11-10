import XCTest
@testable import QuestifyCore

final class DiscoveryPlayTemplateExtrasTests: XCTestCase {
    private func read(_ json: String) throws -> DiscoveryPlayTemplateRead {
        let data = Data(json.utf8)
        return DiscoveryPlayTemplateRead(template: try JSONDecoder().decode(DiscoveryPlayTemplate.self, from: data),
                                         extras: try JSONDecoder().decode(DiscoveryPlayTemplateExtras.self, from: data))
    }

    func testDecodesMiniProgramFieldsAndNeverTheAnswer() throws {
        let value = try read(#"{"id":7,"title":"T","rating":"4.8","commentCount":3,"validationMethod":3,"validationMethodStr":"选择","questionName":"Door &lt;colour&gt;?","questionA":"Red","questionC":" ","questionB":"Blue","questionAnswer":"A","sysCategoryList":[{"categoryName":"City"},{"categoryName":""}],"imgUrls":"[\"https://x.invalid/a.jpg\",\"\"]","memberId":"9","reason":"Fix the photo"}"#)
        let extras = try XCTUnwrap(value.extras)
        XCTAssertEqual(extras.rating, "4.8"); XCTAssertEqual(extras.commentCount, 3)
        XCTAssertEqual(extras.options.map(\.key), ["A", "B"])
        XCTAssertEqual(extras.categoryNames, ["City"])
        XCTAssertEqual(extras.imageURLs, ["https://x.invalid/a.jpg"])
        XCTAssertEqual(extras.memberID, 9)
        XCTAssertFalse(String(describing: extras).contains("questionAnswer"))
        let presentation = DiscoveryPlayTemplateDetailPresentation(value, ownScope: false)
        XCTAssertEqual(presentation.questionText, "Door <colour>?")
        XCTAssertEqual(presentation.nodePreview, .choice(question: "Door <colour>?", options: extras.options))
        XCTAssertNil(presentation.reviewFeedback, "审核反馈 is own-scope only")
        XCTAssertEqual(DiscoveryPlayTemplateDetailPresentation(value, ownScope: true).reviewFeedback, "Fix the photo")
        XCTAssertThrowsError(try read(#"{"id":7,"commentCount":-1}"#))
    }

    func testPublisherResolutionMatchesMiniProgram() throws {
        func publisher(_ json: String, own: Bool = false) throws -> DiscoveryPlayTemplateDetailPresentation.Publisher {
            DiscoveryPlayTemplateDetailPresentation(try read(json), ownScope: own).publisher
        }
        XCTAssertEqual(try publisher(#"{"id":1,"publisher":"Ann"}"#), .named("Ann", official: true))
        XCTAssertEqual(try publisher(#"{"id":1,"publisher":"Ann","memberId":5}"#), .named("Ann", official: false))
        XCTAssertEqual(try publisher(#"{"id":1,"publisher":"Ann"}"#, own: true), .named("Ann", official: false))
        XCTAssertEqual(try publisher(#"{"id":1}"#, own: true), .mine)
        XCTAssertEqual(try publisher(#"{"id":1,"memberId":5}"#), .creator)
        XCTAssertEqual(try publisher(#"{"id":1}"#), .platform)
    }

    func testStatsChipsGalleryAndRuleSteps() throws {
        let game = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":1,"useNum":0,"rating":"4.5","duration":30,"ruleInstructions":"One\n\n Two ","requiredMaterials":"Paper、Pen/Tape","usageLocation":"Park；Street","sysCategoryList":[{"categoryName":"Walk"}],"imgUrl":"https://x.invalid/c.jpg","storyImg":"https://x.invalid/c.jpg","imgUrls":"https://x.invalid/a.jpg,https://x.invalid/c.jpg"}"#), ownScope: false)
        XCTAssertEqual(game.stats.map(\.kind), [.uses, .rating, .duration])
        XCTAssertEqual(game.stats.first?.value, "0")
        XCTAssertEqual(game.ruleSteps, ["One", "Two"])
        XCTAssertEqual(game.materialChips, ["Paper", "Pen", "Tape"])
        XCTAssertEqual(game.sceneChips, ["Walk", "Park", "Street"])
        XCTAssertEqual(game.gallery, ["https://x.invalid/a.jpg", "https://x.invalid/c.jpg"])
        let topic = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":2,"productType":2,"chapterCount":3,"nodeCount":6,"totalTime":90}"#), ownScope: false)
        XCTAssertTrue(topic.isTopicTemplate)
        XCTAssertEqual(topic.stats.map(\.kind), [.chapters, .nodes, .totalTime])
        XCTAssertEqual(topic.stats.map(\.value), ["3", "6", "90"])
        XCTAssertEqual(game.useCountText, "0")
    }

    func testMissingCountsAreEmDashAndLiteralZeroStaysZero() throws {
        let missingTopic = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":2,"productType":2}"#), ownScope: false)
        XCTAssertEqual(missingTopic.stats.map(\.kind), [.chapters, .nodes])
        XCTAssertEqual(missingTopic.stats.map(\.value), ["—", "—"])
        XCTAssertEqual(missingTopic.commentCountText, "—")
        XCTAssertEqual(missingTopic.useCountText, "—")
        XCTAssertNil(missingTopic.commentCount)
        let zero = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":2,"productType":2,"chapterCount":0,"nodeCount":0,"commentCount":0,"useNum":0,"totalTime":""}"#), ownScope: false)
        XCTAssertEqual(zero.stats.map(\.kind), [.chapters, .nodes])
        XCTAssertEqual(zero.stats.map(\.value), ["0", "0"])
        XCTAssertEqual(zero.commentCount, 0)
        XCTAssertEqual(zero.commentCountText, "0")
        XCTAssertEqual(zero.useCountText, "0")
        let game = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":1}"#), ownScope: false)
        XCTAssertEqual(game.stats.map(\.kind), [.uses])
        XCTAssertEqual(game.stats.map(\.value), ["—"])
        XCTAssertEqual(game.useCountText, "—")
        XCTAssertEqual(game.commentCountText, "—")
        let blank = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":2,"productType":2,"chapterCount":"  ","locationCount":null,"commentCount":"0"}"#), ownScope: false)
        XCTAssertEqual(blank.stats.first?.value, "—")
        XCTAssertEqual(blank.commentCount, 0)
        XCTAssertEqual(blank.commentCountText, "0")
    }

    func testReadPhaseKeepsLoadingEmptyErrorAndUnknownApart() throws {
        let zero = try read(#"{"id":1,"useNum":0,"commentCount":0}"#)
        let ready = DiscoveryPlayTemplateDetailPhase.classify(isLoading: false, failure: nil, read: zero, ownScope: false)
        guard case .ready(let presentation) = ready else { return XCTFail("expected ready") }
        XCTAssertEqual(presentation.useCountText, "0")
        XCTAssertEqual(presentation.commentCountText, "0")
        let stale = DiscoveryPlayTemplateDetailPhase.classify(isLoading: true, failure: nil, read: zero, ownScope: false)
        XCTAssertEqual(stale, .loading)
        XCTAssertEqual(DiscoveryPlayTemplateDetailPhase.classify(isLoading: false, failure: nil, read: nil, ownScope: false), .empty)
        XCTAssertEqual(DiscoveryPlayTemplateDetailPhase.classify(isLoading: false, failure: DiscoveryTemplateUnavailable.notFound, read: nil, ownScope: false), .error)
        XCTAssertEqual(DiscoveryPlayTemplateDetailPhase.classify(isLoading: false, failure: APIError.malformedResponse, read: nil, ownScope: false), .error)
        XCTAssertEqual(DiscoveryPlayTemplateDetailPhase.classify(isLoading: false, failure: DiscoveryTemplateUnavailable.unknown, read: zero, ownScope: false), .unknown)
        let missing = try read(#"{"id":1}"#)
        guard case .ready(let unknownCounts) = DiscoveryPlayTemplateDetailPhase.classify(isLoading: false, failure: nil, read: missing, ownScope: false) else {
            return XCTFail("a template with a missing count is still ready")
        }
        XCTAssertEqual(unknownCounts.useCountText, "—")
        XCTAssertEqual(unknownCounts.commentCountText, "—")
    }

    func testNodePreviewIsInertAndNeedsAnAnswer() throws {
        let text = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":1,"validationMethod":1,"questionName":"Q"}"#), ownScope: false)
        var state = TemplateNodePreviewState(preview: try XCTUnwrap(text.nodePreview))
        XCTAssertFalse(state.canComplete)
        state.type("   "); XCTAssertFalse(state.canComplete)
        state.type("anything"); XCTAssertTrue(state.canComplete)
        let choice = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":1,"validationMethod":3,"questionA":"Red"}"#), ownScope: false)
        var picked = TemplateNodePreviewState(preview: try XCTUnwrap(choice.nodePreview))
        picked.select("D"); XCTAssertFalse(picked.canComplete)
        picked.select("A"); XCTAssertTrue(picked.canComplete)
        let photo = DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":1,"validationMethod":2,"validationMethodStr":"拍照"}"#), ownScope: false)
        XCTAssertEqual(photo.nodePreview, .unsupported(methodText: "拍照"))
        XCTAssertNil(DiscoveryPlayTemplateDetailPresentation(try read(#"{"id":1}"#), ownScope: false).nodePreview)
    }
}
