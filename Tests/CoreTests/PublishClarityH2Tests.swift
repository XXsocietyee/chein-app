import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

@MainActor final class PublishClarityH2Tests: XCTestCase {
    private let base = URL(string: "https://api.example.test")!

    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply: Data = Data(#"{"code":200,"data":[]}"#.utf8)
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (reply, 200) }
    }
    private final class Storage: ProjectEditDataStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values[key] = nil }
    }
    private func json(_ text: String) throws -> ProjectEditJSON { try JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)) }
    private func project(_ text: String) throws -> CreatorContentProject { try JSONDecoder().decode(CreatorContentProject.self, from: Data(text.utf8)) }

    // MARK: route

    func testReadRouteIsAnExactGetWithTopicAndScope() throws {
        let request = try TopicPublicationReadRoute.check(topicID: 42, owner: .merchant).request(baseURL: base, token: "t0k")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.test/api/topic/publish-check?topicId=42&scope=MERCHANT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "t0k")
        XCTAssertEqual(TopicPublicationReadRoute(request: request, baseURL: base), .check(topicID: 42, owner: .merchant))
        let personal = try TopicPublicationReadRoute.status(topicID: 7, owner: .personal).request(baseURL: base, token: "t0k")
        XCTAssertEqual(TopicPublicationReadRoute(request: personal, baseURL: base), .status(topicID: 7, owner: .personal))

        var extra = request; extra.url = URL(string: "https://api.example.test/api/topic/publish-check?topicId=42&scope=MERCHANT&x=1")
        XCTAssertNil(TopicPublicationReadRoute(request: extra, baseURL: base))
        var padded = request; padded.url = URL(string: "https://api.example.test/api/topic/publish-check?topicId=042&scope=MERCHANT")
        XCTAssertNil(TopicPublicationReadRoute(request: padded, baseURL: base))
        var post = request; post.httpMethod = "POST"
        XCTAssertNil(TopicPublicationReadRoute(request: post, baseURL: base))
        XCTAssertThrowsError(try TopicPublicationReadRoute.check(topicID: 0, owner: .personal).request(baseURL: base, token: "t0k"))
    }

    func testFeatureAcceptsOnlyTheTwoGets() throws {
        XCTAssertTrue(BusinessRuntimeFeature.projectPublicationRead.accepts(try .init(method: "GET", path: TopicPublicationPath.check)))
        XCTAssertTrue(BusinessRuntimeFeature.projectPublicationRead.accepts(try .init(method: "GET", path: TopicPublicationPath.status)))
        XCTAssertFalse(BusinessRuntimeFeature.projectPublicationRead.accepts(try .post(TopicPublicationPath.status)))
        XCTAssertFalse(BusinessRuntimeFeature.projectRead.accepts(try .init(method: "GET", path: TopicPublicationPath.status)))
        let request = try TopicPublicationReadRoute.status(topicID: 9, owner: .personal).request(baseURL: base, token: "t0k")
        XCTAssertEqual(ProjectExactReadRoute(request: request, baseURL: base)?.feature, .projectPublicationRead)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/topic/publish-status"), .missing)
    }

    // MARK: publish-check

    func testCheckDecodesLocationAndRejectsMalformedRows() throws {
        let body = #"{"code":200,"data":[{"level":"error","code":"BLOCK_CONFIG_INVALID","nodeId":31,"message":"Bad gate","chapterId":5,"chapterTitle":"Old town","nodeName":"Bell tower","blockId":"template:8","field":"nodes[nodeId=31].template[templateId=8]","source":"guard"},{"level":"warn","code":"LINEAR_JOURNEY_SESSION","nodeId":null,"message":"Linear run"}]}"#
        let report = try TopicPublishCheckReport.decode(Data(body.utf8), status: 200, topicID: 3)
        XCTAssertEqual(report.blocking.count, 1)
        XCTAssertEqual(report.advisory.count, 1)
        XCTAssertFalse(report.structurePassed)
        let issue = report.blocking[0]
        XCTAssertEqual(issue.chapterID, 5); XCTAssertEqual(issue.nodeName, "Bell tower"); XCTAssertEqual(issue.blockID, "template:8")
        XCTAssertEqual(TopicPublishIssueWhere.of(issue), .stop(chapter: "Old town", stop: "Bell tower"))
        XCTAssertEqual(TopicPublishIssueWhere.of(report.advisory[0]), .unlocated)

        for bad in [#"{"code":200,"data":[{"level":"info","message":"x"}]}"#, #"{"code":200,"data":[{"level":"error","message":""}]}"#,
                    #"{"code":200,"data":[{"level":"error","message":"x","nodeId":-1}]}"#, #"{"code":500,"msg":"x"}"#, #"{"code":200,"data":{}}"#] {
            XCTAssertThrowsError(try TopicPublishCheckReport.decode(Data(bad.utf8), status: 200, topicID: 3), bad)
        }
        XCTAssertThrowsError(try TopicPublishCheckReport.decode(Data(#"{"code":401}"#.utf8), status: 200, topicID: 3)) { XCTAssertEqual($0 as? APIError, .unauthorized) }
    }

    func testWhereFollowsMiniProgramFieldMapping() {
        XCTAssertEqual(TopicPublishIssueWhere.fromField("tickets[0].price"), .tickets)
        XCTAssertEqual(TopicPublishIssueWhere.fromField("saleEnd"), .tickets)
        XCTAssertEqual(TopicPublishIssueWhere.fromField("chapters[2].name"), .chapterNumber(3))
        XCTAssertEqual(TopicPublishIssueWhere.fromField("chapter:0"), .chapterNumber(1))
        XCTAssertEqual(TopicPublishIssueWhere.fromField("chapters"), .story)
        XCTAssertEqual(TopicPublishIssueWhere.fromField("themeStateKeys"), .story)
        XCTAssertEqual(TopicPublishIssueWhere.fromField("name"), .topicSettings)
        XCTAssertEqual(TopicPublishIssueWhere.fromField(nil), .unlocated)
    }

    func testServerIssueLocatesByServerIDsOnlyWhenUnique() {
        var draft = ProjectEditDraft()
        var chapter = ProjectEditChapter(); chapter.id = "chapter-5"; chapter.preserved["id"] = .number(5)
        var node = ProjectEditNode(); node.id = "chapter-5-node-31"; node.localMetadata = ["id": .number(31)]
        chapter.nodes = [node]; draft.chapters = [chapter]
        let gate = TopicPublishCheckIssue(id: 0, level: .error, code: nil, message: "x", nodeID: 31, blockID: "template:8")
        XCTAssertEqual(gate.location(in: draft), .node(chapterID: "chapter-5", nodeID: "chapter-5-node-31", anchor: "project-issue-anchor-gameplay"))
        let chapterOnly = TopicPublishCheckIssue(id: 1, level: .error, code: nil, message: "x", chapterID: 5, field: "chapters[0].blocks")
        XCTAssertEqual(chapterOnly.location(in: draft), .chapter(id: "chapter-5", anchor: "project-issue-anchor-storyFlow"))
        XCTAssertNil(TopicPublishCheckIssue(id: 2, level: .error, code: nil, message: "x", nodeID: 99).location(in: draft))
        XCTAssertEqual(TopicPublishCheckIssue(id: 3, level: .warn, code: nil, message: "x", field: "name").location(in: draft), .root(anchor: "project-issue-anchor-name"))
        var duplicate = draft; duplicate.chapters.append(chapter)
        XCTAssertNil(gate.location(in: duplicate))
    }

    func testAgreementAndStagesNeverClaimRehearsalOrOnSite() {
        let clean = TopicPublishCheckReport(topicID: 1, issues: [])
        let blocked = TopicPublishCheckReport(topicID: 1, issues: [.init(id: 0, level: .error, code: nil, message: "x")])
        XCTAssertEqual(TopicPublishCheckAgreement.of(clean, localIssueCount: 0, draftMatchesSaved: false), .savedVersionDiffers)
        XCTAssertEqual(TopicPublishCheckAgreement.of(blocked, localIssueCount: 0, draftMatchesSaved: true), .serverOnlyBlocks)
        XCTAssertEqual(TopicPublishCheckAgreement.of(clean, localIssueCount: 2, draftMatchesSaved: true), .localOnlyBlocks)
        XCTAssertEqual(TopicPublishCheckAgreement.of(clean, localIssueCount: 0, draftMatchesSaved: true), .agrees)
        XCTAssertEqual(TopicVerificationSummary.state(.structure, report: nil), .unknown)
        XCTAssertEqual(TopicVerificationSummary.state(.structure, report: clean), .passed)
        XCTAssertEqual(TopicVerificationSummary.state(.structure, report: blocked), .blocked)
        XCTAssertEqual(TopicVerificationSummary.state(.rehearsal, report: clean), .notRecorded)
        XCTAssertEqual(TopicVerificationSummary.state(.onSite, report: clean), .notRecorded)
    }

    // MARK: publish-status

    private let publicPending = #"{"draft":{"draft":false,"editable":true,"editBlockedReason":null},"review":{"state":"AWAITING","label":"已公开待审","passed":false,"pending":false,"auditTaskId":null,"detail":null},"visibility":{"visible":true,"reason":null},"sale":{"onSale":false,"lifecycleSaleOpen":false,"awaitingReview":true,"nextStep":"完成定价后可开售","blockReason":"商业审核未通过"},"playable":{"playable":true,"reason":null,"publishedConfigVersion":12,"beta":false,"gate":"PUBLISHED_SNAPSHOT_ONLY"}}"#

    func testStatusKeepsFiveFactsSeparate() throws {
        let status = try TopicPublicationStatus.decode(try json(publicPending))
        XCTAssertEqual(status.visibility?.visible, true)
        XCTAssertEqual(status.review?.passed, false)
        XCTAssertEqual(status.sale?.onSale, false)
        XCTAssertEqual(status.playable?.publishedConfigVersion, 12)
        XCTAssertEqual(TopicPublicationHeadline.of(status), .publicAwaitingReview)
        let rows = TopicPublicationFactRow.rows(status)
        XCTAssertTrue(rows.contains(.sale(.no, awaitingReview: .yes, nextStep: "完成定价后可开售", blockReason: "商业审核未通过")))

        let sparse = try TopicPublicationStatus.decode(try json(#"{"review":{"state":"PENDING"}}"#))
        XCTAssertEqual(TopicPublicationHeadline.of(sparse), .unknown)
        XCTAssertTrue(TopicPublicationFactRow.rows(sparse).contains(.visible(.unknown, reason: nil)))
        XCTAssertThrowsError(try TopicPublicationStatus.decode(try json(#"{"visibility":{"visible":"yes"}}"#)))
        XCTAssertThrowsError(try TopicPublicationStatus.decodeResponse(Data(#"{"code":500}"#.utf8), status: 200))
    }

    func testHeadlinesNeverPromoteVisibilityToApproval() throws {
        func status(_ state: String, passed: Bool?, visible: Bool?) -> TopicPublicationStatus {
            .init(review: .init(state: state, passed: passed), visibility: .init(visible: visible))
        }
        XCTAssertEqual(TopicPublicationHeadline.of(status("PASSED", passed: true, visible: true)), .live)
        XCTAssertEqual(TopicPublicationHeadline.of(status("PASSED", passed: true, visible: false)), .approvedHidden)
        XCTAssertEqual(TopicPublicationHeadline.of(status("PENDING", passed: nil, visible: false)), .inReview)
        XCTAssertEqual(TopicPublicationHeadline.of(status("REJECTED", passed: false, visible: false)), .rejected)
        XCTAssertEqual(TopicPublicationHeadline.of(status("PASSED", passed: true, visible: nil)), .unknown)
        XCTAssertEqual(TopicPublicationHeadline.ofListState("running"), .listedPublic)
        XCTAssertEqual(TopicPublicationHeadline.ofListState("notStarted"), .listedPublic)
        XCTAssertEqual(TopicPublicationHeadline.ofListState("offline"), .listedOffline)
        XCTAssertEqual(TopicPublicationHeadline.ofListState("pending"), .inReview)
        XCTAssertEqual(TopicPublicationHeadline.ofListState("cancelled"), .unknown)
        XCTAssertEqual(TopicPublicationHeadline.ofListState(nil), .unknown)
    }

    // MARK: acknowledgment (U03-02)

    func testAcknowledgmentKeepsCommercialFactsAndRoundTrips() throws {
        let raw = try json(#"{"topicId":8,"auditTaskId":3,"reviewState":"PENDING","published":true,"bundledTemplateIds":[4],"commercialAwaitingReview":true,"commercialNextStep":"主题与引用的玩法将一起审核。","reviewPassed":false,"publicVisible":true,"contentRevisionNo":2,"publicationStatus":\#(publicPending)}"#)
        let ack = try ProjectEditBundleAcknowledgment.decode(raw, expectedTopicID: 8)
        XCTAssertEqual(ack.commercialAwaitingReview, true)
        XCTAssertEqual(ack.contentRevisionNo, 2)
        XCTAssertEqual(TopicPublicationHeadline.of(ack), .publicAwaitingReview)
        XCTAssertEqual(TopicPublishNextStep.of(ack).serverText, "完成定价后可开售")
        let again = try JSONDecoder().decode(ProjectEditBundleAcknowledgment.self, from: JSONEncoder().encode(ack))
        XCTAssertEqual(again, ack)

        let legacy = try ProjectEditBundleAcknowledgment.decode(try json(#"{"topicId":8,"auditTaskId":3,"reviewState":"PENDING","published":true,"bundledTemplateIds":[]}"#), expectedTopicID: 8)
        XCTAssertNil(legacy.publicationStatus)
        XCTAssertEqual(TopicPublicationHeadline.of(legacy), .publicAwaitingReview)
        XCTAssertEqual(TopicPublishNextStep.of(legacy).fallbackKey, "next.review")

        let notRequired = try ProjectEditBundleAcknowledgment.decode(try json(#"{"topicId":8,"reviewState":"NOT_REQUIRED","published":true,"bundledTemplateIds":[]}"#), expectedTopicID: 8)
        XCTAssertEqual(TopicPublicationHeadline.of(notRequired), .listedPublic, "visible without a review fact is not approval")
        let wrongType = try ProjectEditBundleAcknowledgment.decode(try json(#"{"topicId":8,"reviewState":"DRAFT","published":false,"bundledTemplateIds":[],"commercialAwaitingReview":"yes"}"#), expectedTopicID: 8)
        XCTAssertNil(wrongType.commercialAwaitingReview)
        XCTAssertEqual(TopicPublicationHeadline.of(wrongType), .draft)
    }

    // MARK: my projects (U03-03)

    func testMyProjectTopicFactSharesHeadlineAndExplainsSoldScope() throws {
        let sold = try XCTUnwrap(MyProjectTopicFact.of(try project(#"{"id":1,"bizType":"topic","state":"offline","signupCount":4}"#)))
        XCTAssertEqual(sold.headline, .listedOffline)
        XCTAssertEqual(sold.editScopeNoticeKey, "list.soldEditScope")
        let unknown = try XCTUnwrap(MyProjectTopicFact.of(try project(#"{"id":2,"bizType":"topic","state":"draft"}"#)))
        XCTAssertEqual(unknown.headline, .draft)
        XCTAssertEqual(unknown.editScopeNoticeKey, "list.unknownSoldEditScope")
        let fresh = try XCTUnwrap(MyProjectTopicFact.of(try project(#"{"id":3,"bizType":"topic","state":"running","signupCount":0}"#)))
        XCTAssertEqual(fresh.headline, .listedPublic)
        XCTAssertNil(fresh.editScopeNoticeKey)
        XCTAssertNil(MyProjectTopicFact.of(try project(#"{"id":4,"bizType":"activity","state":"running"}"#)))
    }

    // MARK: HTTP adapter

    func testServiceReadsOnlyWithItsOwnGrantAndSession() async throws {
        let session = try ProjectEditSession(accountID: 7, epoch: 1, storageNamespace: "fixture")
        let wire = Wire(), store = ProjectEditLocalStore(storage: Storage())
        let config = try APIConfiguration(baseURL: base)
        let granted = try OperationEndpointApproval(baseURL: base, namespace: "fixture", accountID: 7, paths: [TopicPublicationPath.check, TopicPublicationPath.status])
        let service = ProjectEditHTTPService(configuration: config, transport: wire, owner: .personal, approval: granted, store: store,
                                             currentCredentials: { try? .init(session: session, token: "synthetic") })
        XCTAssertTrue(service.supportsPublishCheck)
        wire.reply = Data(#"{"code":200,"data":[{"level":"warn","message":"note"}]}"#.utf8)
        let report = try await service.publishCheck(topicID: 12, session: session)
        XCTAssertTrue(report.structurePassed)
        XCTAssertEqual(wire.requests.last?.url?.query, "topicId=12&scope=")
        wire.reply = Data(#"{"code":200,"data":\#(publicPending)}"#.utf8)
        let status = try await service.publicationStatus(topicID: 12, session: session)
        XCTAssertEqual(status.review?.state, "AWAITING")
        XCTAssertEqual(wire.requests.count, 2)

        let ungranted = ProjectEditHTTPService(configuration: config, transport: wire, owner: .personal,
                                               approval: try OperationEndpointApproval(baseURL: base, namespace: "fixture", accountID: 7, paths: ["api/topic/edit-detail"]),
                                               store: store, currentCredentials: { try? .init(session: session, token: "synthetic") })
        XCTAssertFalse(ungranted.supportsPublicationStatus)
        do { _ = try await ungranted.publicationStatus(topicID: 12, session: session); XCTFail("read without grant") } catch {}
        XCTAssertEqual(wire.requests.count, 2)
    }
}
