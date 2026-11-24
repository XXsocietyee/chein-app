import XCTest
@testable import QuestifyCore

/// One Core check per mini-program club call this branch touches.
@MainActor final class ClubCoreClubContractTests: XCTestCase {
    private let scope = ClubGovernanceScope(clubID: 81, topicID: 91)

    func testBanPostsDurationDays() throws {
        XCTAssertEqual(ClubGovernanceMutation.ban.path, "api/club/governance/ban")
        let command = try ClubGovernanceCommand(operation: .ban, scope: .init(clubID: 81), values: [
            "targetMemberId": .integer(704), "reason": .string("骚扰"), "durationDays": .integer(30), "requestId": .string("ban-1")
        ])
        XCTAssertEqual(command.fields["clubId"], .integer(81))
        XCTAssertEqual(command.fields["durationDays"], .integer(30))
        XCTAssertNil(command.fields["expiresAt"])
        XCTAssertNil(command.fields["expiresAtEpochMs"])
        for days in [7, 90] {
            XCTAssertEqual(try ClubGovernanceCommand(operation: .ban, scope: .init(clubID: 81), values: [
                "targetMemberId": .integer(704), "reason": .string("R"), "durationDays": .integer(days), "requestId": .string("ban-1")
            ]).fields["durationDays"], .integer(days))
        }
    }

    func testAccessMeGatesMemberGovernanceToOwnerAndCoOwner() throws {
        XCTAssertEqual(ClubGovernanceRead.access.path, "api/club/access/me")
        func permissions(roles: [String], codes: [String]) throws -> ClubGovernancePermissions {
            try .init(value: .object([
                "active": .bool(true), "club": .object(["id": .integer(81)]),
                "roleCodes": .array(roles.map(ClubGovernanceValue.string)),
                "permissions": .array(codes.map(ClubGovernanceValue.string))
            ]), scope: .init(clubID: 81))
        }
        let owner = try permissions(roles: ["CLUB_OWNER"], codes: ["club:member:manage"])
        let coOwner = try permissions(roles: ["CLUB_CO_OWNER"], codes: ["club:member:manage"])
        let member = try permissions(roles: ["CLUB_MEMBER"], codes: ["club:member:manage"])
        let bareOwner = try permissions(roles: ["CLUB_OWNER"], codes: [])
        XCTAssertTrue(owner.canGovernMembers)
        XCTAssertTrue(coOwner.canGovernMembers)
        XCTAssertFalse(member.canGovernMembers)
        XCTAssertFalse(bareOwner.canGovernMembers)
        XCTAssertTrue(owner.allows("club:member:manage", scope: .init(clubID: 81)))
        XCTAssertFalse(member.allows("club:member:manage", scope: .init(clubID: 81)))
        XCTAssertEqual(ClubGovernancePermissions.memberGovernanceDenial, "仅主理人与联合主理人可进行成员治理")
    }

    func testTopicRegistrationsCountSignupsAndPaidStatusTwo() throws {
        XCTAssertEqual(ClubGovernanceRead.registrations.path, "api/club/topic-registrations")
        let roster = try ClubEnrollmentRoster(value: .object([
            "clubId": .integer(81), "topicId": .integer(91), "canRefund": .bool(false),
            "omsTicketList": .array([.object([
                "id": .integer(1), "totalInventory": .integer(10),
                "cmsRegistrationList": .array([
                    .object(["id": .integer(1), "paymentStatus": .integer(2)]),
                    .object(["id": .integer(2), "paymentStatus": .integer(1)]),
                    .object(["id": .integer(3), "paymentStatus": .null])
                ])
            ])])
        ]), scope: scope)
        let ticket = try XCTUnwrap(roster.tickets.first)
        XCTAssertEqual(ticket.signups, 3)
        XCTAssertEqual(ticket.signupNumeratorText, "3 / 10")
        XCTAssertEqual(roster.paidCount, 1)
    }

    func testCreatePostRespectsMemberPostAllowed() throws {
        XCTAssertEqual("api/club/post/" + ClubCommunityOperation.create(content: "hi", images: []).suffix, "api/club/post/create")
        let identity = ClubReadIdentity(accountID: 8, epoch: 1)
        let blocked = ClubCommunityEvidence(identity: identity, clubID: 9, joined: true, owner: false, administrator: false, memberPostAllowed: false)
        let open = ClubCommunityEvidence(identity: identity, clubID: 9, joined: true, owner: false, administrator: false)
        let owner = ClubCommunityEvidence(identity: identity, clubID: 9, joined: true, owner: true, administrator: false, memberPostAllowed: false)
        XCTAssertFalse(blocked.allows(.create(content: "hi", images: [])))
        XCTAssertTrue(open.allows(.create(content: "hi", images: [])))
        XCTAssertTrue(owner.allows(.create(content: "hi", images: [], notice: false)))
        XCTAssertFalse(blocked.allows(.create(content: "hi", images: [], notice: true)))
        XCTAssertTrue(owner.allows(.create(content: "公告", images: [], notice: true)))
        let review = try ClubCommunityReview(operation: .create(content: "hello", images: []), evidence: open)
        XCTAssertEqual(try review.fields()["clubId"] as? Int, 9)
        XCTAssertNil(try review.fields()["type"])
        let notice = try ClubCommunityReview(operation: .create(content: "公告", images: [], notice: true), evidence: owner)
        XCTAssertEqual(try notice.fields()["type"] as? Int, 2)
    }

    func testClubDetailDecodesMemberPricePerk() throws {
        func club(_ json: String) throws -> ClubRecord {
            try JSONDecoder().decode(ClubRecord.self, from: Data(json.utf8))
        }
        func perk(_ record: ClubRecord) -> String? {
            ClubMemberWelcome(id: UUID(), identity: .init(accountID: 8, epoch: 1), club: record, role: nil, namespace: "test").memberPricePerk
        }
        XCTAssertEqual(try perk(club(#"{"id":9,"memberDiscountPrice":39}"#)), "成员价 ¥39.0")
        XCTAssertEqual(try perk(club(#"{"id":9,"memberDiscountPrice":29.9,"memberDiscountPriceText":"29.9"}"#)), "成员价 29.9")
        XCTAssertEqual(try perk(club(#"{"id":9,"memberDiscountPrice":12.35}"#)), "成员价 ¥12.35")
        XCTAssertNil(try perk(club(#"{"id":9,"memberDiscountPrice":0}"#)))
        XCTAssertNil(try perk(club(#"{"id":9}"#)))
        XCTAssertNil(try club(#"{"id":9,"memberDiscountPrice":"nope"}"#).memberDiscountPrice)
    }

    func testSeriesCreateChecksTheNinetyDayWeeklyWindow() throws {
        XCTAssertEqual(ClubGovernanceMutation.createSeries.path, "api/club/event-ops/series/create")
        let now = ISO8601DateFormatter().date(from: "2026-10-11T01:00:00Z")!
        var inside = ClubSeriesScheduleDraft(form: .init(operation: .createSeries, scope: scope), now: now)
        inside.startDate = "2026-10-12"
        inside.startTime = "09:00"
        inside.occurrenceCount = 3
        XCTAssertNil(inside.issue(now: now))
        inside.occurrenceCount = 40
        XCTAssertEqual(inside.issue(now: now), .weeklyHorizon)
        XCTAssertEqual(inside.weeklyHorizonMessage(now: now), "首次日期起 90 天内最多可排 13 期")
        XCTAssertEqual(ClubEventOpsFormRules.offerWindowText(minutes: 1440), "1 天")
        XCTAssertEqual(ClubEventOpsFormRules.offerWindowText(minutes: 90), "1 小时 30 分")
        XCTAssertEqual(ClubEventOpsFormRules.offerWindowText(minutes: 4), "")
        XCTAssertFalse(ClubEventOpsFormRules.showsCapacity(sessionTicketCount: 2))
        XCTAssertTrue(ClubEventOpsFormRules.showsCapacity(sessionTicketCount: 1))
    }

    func testStoryAnswerRoutesClubAndHostReads() throws {
        let overview = ClubGovernanceValue.object(["id": .integer(91), "name": .string("Fixture"), "chaptersList": .null])
        let permissions = try ClubGovernancePermissions(value: ClubGovernanceFixtures.permissions, scope: scope)
        let clubSnapshot = ClubGovernanceSnapshot(operation: .topicOverview, scope: scope, permissions: permissions, value: overview)
        let clubStory = try ClubStoryPresentation(snapshot: clubSnapshot, hostScope: "merchant")
        XCTAssertEqual(clubStory.clubID, 81)
        XCTAssertNil(clubStory.hostScope)
        let clubCall = try XCTUnwrap(clubStory.nodeAnswerCall(nodeID: 141))
        XCTAssertEqual(clubCall.path, "api/club/topic-node-answer")
        XCTAssertEqual(clubCall.fields, ["clubId": .integer(81), "topicId": .integer(91), "nodeId": .integer(141)])
        let hostScope = ClubGovernanceScope(topicID: 91)
        let hostSnapshot = ClubGovernanceSnapshot(operation: .topicOverview, scope: hostScope, permissions: nil, value: overview)
        XCTAssertThrowsError(try ClubStoryPresentation(snapshot: hostSnapshot)) { XCTAssertEqual($0 as? ClubGovernanceFailure, .targetChanged) }
        let hostStory = try ClubStoryPresentation(snapshot: hostSnapshot, hostScope: " merchant ")
        XCTAssertNil(hostStory.clubID)
        XCTAssertEqual(hostStory.hostScope, "merchant")
        let hostCall = try XCTUnwrap(hostStory.nodeAnswerCall(nodeID: 141))
        XCTAssertEqual(hostCall.path, "api/topic/host-node-answer")
        XCTAssertEqual(hostCall.fields, ["topicId": .integer(91), "nodeId": .integer(141), "scope": .string("merchant")])
        XCTAssertNil(hostStory.nodeAnswerCall(nodeID: 0))
    }

    func testGroupCodeLinkAcceptsTopicIdWithoutActivityId() {
        let topic = MiniProgramPageLink(path: "pages/club/group-code/index", query: ["topicId": "12", "topicName": "夜路"])
        XCTAssertEqual(topic?.query["topicId"], "12")
        XCTAssertNil(topic?.query["activityId"])
        XCTAssertNil(MiniProgramPageLink(path: "pages/club/group-code/index", query: ["topicName": "夜路"]))
        XCTAssertNotNil(MiniProgramPageLink(path: "pages/club/group-code/index", query: ["activityId": "4"]))
    }

    func testClubAndPostSharePaths() {
        XCTAssertEqual(ClubShareLink.club(id: 81)?.path, "/pages/club/detail/index?id=81")
        XCTAssertEqual(ClubShareLink.post(clubID: 81, postID: 9)?.path, "/pages/club/detail/index?id=81&postId=9")
        XCTAssertEqual(ClubShareLink.parse("/pages/club/detail/index?id=81"), ClubShareLink.club(id: 81))
        XCTAssertEqual(ClubShareLink.parse("pages/club/detail/index?postId=9&id=81"), ClubShareLink.post(clubID: 81, postID: 9))
        XCTAssertNil(ClubShareLink.parse("/pages/club/detail/index?id=81&postId=09"))
        XCTAssertNil(ClubShareLink.parse("/pages/club/detail/index?id=81#x"))
        XCTAssertNil(ClubShareLink.club(id: 0))
    }

    func testTopicShareLinkMatchesTicketSource() {
        let link = TopicClubShareLinkParser.parse("pages/topic/index/index?topicId=8&sourceClubId=42")
        XCTAssertEqual(link, TopicClubShareLink(topicID: 8, sourceClubId: 42, clubCode: nil))
        let trimmed = TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42&clubCode=%20EAST%20")
        XCTAssertEqual(trimmed?.clubCode, "EAST")
        let overlong = String(repeating: "A", count: 65)
        XCTAssertNil(TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42&clubCode=\(overlong)"))
        XCTAssertEqual(TopicClubShareLink.laterRegistrationField, "sourceChannelCode")
    }

    func testCustomerDetailRefusalKeepsTheServerSentence() {
        XCTAssertEqual(ClubGovernanceRead.customer.path, "api/club/crm/customers/detail")
        XCTAssertEqual(ClubCustomerDetailRefusal.sentence(code: 400, message: "找不到这位成员"), "找不到这位成员")
        XCTAssertNil(ClubCustomerDetailRefusal.sentence(code: 403, message: "找不到这位成员"))
        XCTAssertNil(ClubCustomerDetailRefusal.sentence(code: 500, message: "系统繁忙，请稍后重试"))
        XCTAssertNil(ClubCustomerDetailRefusal.sentence(code: 401, message: "请登录"))
        let refused = ClubOpsFailureCopy(operation: .customer, failure: .rejected(code: 400, message: "找不到这位成员"))
        XCTAssertEqual(refused?.literalTitle, "找不到这位成员")
        XCTAssertEqual(refused?.backTitle, "返回")
        XCTAssertEqual(refused?.titleKey, "clubOps.customer.failed")
        XCTAssertEqual(refused?.retryKey, "clubOps.customers.retry")
        let generic = ClubOpsFailureCopy(operation: .customer, failure: .malformed)
        XCTAssertEqual(generic?.retryKey, "clubOps.customers.retry")
        XCTAssertNil(generic?.literalTitle)
    }

    func testFailureCopySplitsNetworkFromService() {
        let network = ClubGovernanceFailure.unknown(message: nil)
        XCTAssertEqual(ClubOpsNetworkFailureClassifier.notifyTitle(network), "网络连接失败")
        XCTAssertEqual(ClubOpsNetworkFailureClassifier.joinRequestsTitle(.malformed), "入会申请加载失败")
        XCTAssertEqual(ClubOpsNetworkFailureClassifier.settlementTitle(network), "网络连接失败")
        XCTAssertEqual(ClubOpsNetworkFailureClassifier.settlementTitle(.malformed), "结算数据暂不可用")
        XCTAssertEqual(ClubOpsNetworkFailureClassifier.eventOpsHubTitle(.malformed), "活动运营暂时不可用")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .series, failure: network)?.literalTitle, "网络连接失败")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .series, failure: .malformed)?.literalTitle, "系列列表加载失败")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .eventTopics, failure: .malformed)?.literalTitle, "可开场主题加载失败")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .topicOverview, failure: .malformed)?.literalTitle, "活动无法打开")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .topicOverview, failure: .targetChanged)?.literalTitle, "链接已失效")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .topicOverview, failure: .targetChanged)?.prefersBack, true)
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .topicOverview, failure: .malformed)?.titleKey, "clubOpsGov.failed")
        XCTAssertEqual(ClubOpsPageFailureCopy(operation: .audienceCounts, failure: .malformed)?.titleKey, "clubOpsNotify.failed")
        XCTAssertEqual(ClubOpsFailureCopy(operation: .settlement, failure: .malformed)?.literalTitle, "结算数据暂不可用")
        XCTAssertEqual(ClubOpsFailureCopy(operation: .settlement, failure: .malformed)?.titleKey, "clubOps.settlement.failed")
    }

    func testOwnerStageMachine() {
        func resolve(_ input: ClubOwnerStageInput) -> ClubOwnerStageResolution { ClubOwnerStageMachine.resolve(input) }
        let admin = resolve(.init(isOwner: false, canGovern: true, clubID: 81, topicState: "ready"))
        XCTAssertEqual(admin.stage, .admin)
        XCTAssertEqual(admin.label, "带好眼下这一场")
        let publish = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topicState: "ready"))
        XCTAssertEqual(publish.stage, .publish)
        XCTAssertEqual(publish.label, "发布主题")
        let failed = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topicState: "error"))
        XCTAssertEqual(failed.stage, .error)
        let recruit = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topics: [
            .init(id: 1, lifecycle: 1, name: "夜跑")
        ]))
        XCTAssertEqual(recruit.stage, .recruit)
        XCTAssertEqual(recruit.hint, "夜跑")
        let price = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topics: [
            .init(id: 1, lifecycle: 2, name: "终价")
        ]))
        XCTAssertEqual(price.stage, .price)
        let sale = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topics: [
            .init(id: 1, lifecycle: 2, saleReviewPending: true, name: "待审")
        ]))
        XCTAssertEqual(sale.stage, .saleReview)
        XCTAssertEqual(sale.hint, "待审")
        let contract = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topics: [
            .init(id: 1, lifecycle: 1, name: "夜跑", uncontractedStations: ["站A", "站B"])
        ]))
        XCTAssertEqual(contract.stage, .contract)
        XCTAssertEqual(contract.hint, "站A、站B 还没有合作单，不能开售")
        let invite = resolve(.init(isOwner: true, canGovern: true, clubID: 81, messages: [
            .init(status: 0, toType: "club", toID: 81), .init(status: 0, toType: "club", toID: 81)
        ]))
        XCTAssertEqual(invite.stage, .coopInvite)
        XCTAssertEqual(invite.hint, "有 2 条合作邀约待确认")
        let execution = resolve(.init(isOwner: true, canGovern: true, clubID: 81, topics: [.init(id: 5)],
                                      manageTopicIDs: [5], messages: [.init(status: 1, toType: "club", toID: 81, topicID: 5)]))
        XCTAssertEqual(execution.stage, .executionAccepted)
        XCTAssertEqual(execution.label, "活动运营")
    }

    func testConfirmedDissolveClearsTheLocalEditDraft() throws {
        XCTAssertEqual(ClubGovernanceMutation.dissolve.path, "api/club/dissolve")
        let storage = Memory()
        let profile = try JSONDecoder().decode(ClubOperationsProfile.self, from: Data(#"{"id":9,"name":"Example","city":"Example","isOwner":true}"#.utf8))
        let store = ClubProfileLocalDraftStore(storage: storage)
        let scope = try ClubProfileLocalDraftScope(namespace: "test", accountID: 7, clubID: 9)
        let form = ClubProfileLocalDraftForm(ClubOperationsDraft(profile: profile))
        let record = ClubProfileLocalDraftRecord(scope: scope, profile: profile, form: form)
        _ = try store.replace(record, scope: scope, expected: store.read(scope))
        let flow = ClubProfileLocalDraftFlow()
        let context = ClubProfileLocalDraftContext(store: store, namespace: "test", identity: .init(accountID: 7, epoch: 1), viewerRevision: 1, current: { true })
        _ = flow.begin(profile: profile, context: context)
        XCTAssertTrue(flow.hasRetainedDraft)
        XCTAssertTrue(flow.clearAfterConfirmedDissolve())
        XCTAssertNil(try store.read(scope).record)
        _ = try store.replace(record, scope: scope, expected: store.read(scope))
        let other = ClubProfileLocalDraftFlow()
        let stale = ClubProfileLocalDraftContext(store: store, namespace: "test", identity: .init(accountID: 8, epoch: 1), viewerRevision: 1, current: { true })
        _ = other.begin(profile: profile, context: stale)
        _ = other.clearAfterConfirmedDissolve()
        XCTAssertNotNil(try store.read(scope).record)
        XCTAssertFalse(ClubProfileLocalDraftFlow().clearAfterConfirmedDissolve())
    }

    func testWorkbenchTilesHideUnknownReads() throws {
        XCTAssertEqual(ClubWorkbenchTiles.pendingVerifyCount(.object(["pendingVerifyCount": .integer(4)])), 4)
        XCTAssertNil(ClubWorkbenchTiles.pendingVerifyCount(.object(["pendingVerifyCount": .string("4")])))
        XCTAssertNil(ClubWorkbenchTiles.pendingVerifyCount(.object([:])))
        XCTAssertNil(ClubWorkbenchTiles.pendingVerifyCount(.object(["pendingVerifyCount": .integer(-1)])))
        let month = try XCTUnwrap(ClubEventMonth(year: 2026, month: 11))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-04T04:00:00Z"))
        func row(_ id: Int, _ date: String, _ state: String) -> ClubGovernanceValue {
            .object(["activityId": .integer(id), "topicId": .null, "name": .null, "date": .string(date),
                     "startDate": .string(date + " 10:00:00"), "endDate": .null, "state": .string(state), "updatedAt": .null])
        }
        func snapshot(truncated: Bool) throws -> ClubCalendarSessionsSnapshot {
            try .init(value: .object([
                "clubId": .integer(81), "month": .string(month.key), "scope": .string("GOVERNOR"), "truncated": .bool(truncated),
                "updatedAt": .null, "sessions": .array([
                    row(1, "2026-11-02", "PUBLISHED"), row(2, "2026-11-04", "CANCELLED"), row(3, "2026-11-09", "PUBLISHED")
                ])
            ]), clubID: 81, month: month)
        }
        XCTAssertEqual(try ClubWorkbenchTiles.sessionsThisWeek(snapshot(truncated: false), now: now), 1)
        XCTAssertNil(try ClubWorkbenchTiles.sessionsThisWeek(snapshot(truncated: true), now: now))
        let sunday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T04:00:00Z"))
        XCTAssertNil(try ClubWorkbenchTiles.sessionsThisWeek(snapshot(truncated: false), now: sunday))
    }

    private final class Memory: ClubProfileLocalDraftStorage {
        var rows: [String: ClubProfileLocalDraftBytes] = [:]
        func read(key: String) throws -> ClubProfileLocalDraftBytes? { rows[key] }
        func replace(key: String, expected: ClubProfileLocalDraftBytes?, data: Data?) throws -> ClubProfileLocalDraftBytes? {
            guard rows[key] == expected else { throw ClubProfileLocalDraftIssue.changed }
            let next = data.map { ClubProfileLocalDraftBytes(data: $0, tag: Data(repeating: 7, count: 32)) }
            rows[key] = next
            return next
        }
    }
}
