#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CloudL5IMSquareTests: XCTestCase {
    func testLedgerKeepsOnlyIdsAndRetiresStaleHandles() {
        var ledger = IMSendRecoveryLedger()
        let receipt = ledger.begin(owner: "8", conversation: "3", id: "im_1")
        XCTAssertEqual(receipt?.id, "im_1")
        XCTAssertEqual(ledger.storedIDs(owner: "8", conversation: "3"), ["im_1"])
        XCTAssertTrue(ledger.current(receipt!))
        XCTAssertEqual(ledger.begin(owner: "8", conversation: "3", id: "im_1")?.generation, receipt?.generation)
        XCTAssertEqual(ledger.storedIDs(owner: "8", conversation: "3"), ["im_1"])
        ledger.invalidate()
        XCTAssertFalse(ledger.current(receipt!))
        XCTAssertEqual(ledger.pending(owner: "8", conversation: "3").map(\.id), ["im_1"])
        XCTAssertTrue(ledger.pending(owner: "8", conversation: "3").allSatisfy { ledger.current($0) })
        XCTAssertFalse(ledger.complete(receipt!))
        let live = ledger.pending(owner: "8", conversation: "3")[0]
        XCTAssertTrue(ledger.complete(live))
        XCTAssertTrue(ledger.storedIDs(owner: "8", conversation: "3").isEmpty)
        XCTAssertTrue(ledger.abandon(owner: "8", conversation: "4"))
        XCTAssertFalse(ledger.current(live))
    }

    func testFailedSendDoesNotResendUntilReceiptSaysMissing() {
        var transcript = IMSendTranscript()
        let payload = IMOutgoingPayload(clientMessageID: "im_9", kind: .text("hello"))
        let receipt = transcript.start(owner: "4", conversation: "7", payload: payload)
        XCTAssertEqual(transcript.sendCount, 1)
        XCTAssertNil(transcript.start(owner: "4", conversation: "7", payload: payload))
        XCTAssertEqual(transcript.sendCount, 1)
        transcript.finish(receipt: receipt!, accepted: false, serverID: nil)
        XCTAssertEqual(transcript.locals.map(\.state), [.failed])
        XCTAssertEqual(transcript.sendCount, 1)
        let pending = transcript.resendReceipt(owner: "4", conversation: "7", temporaryID: "tmp_im_9")
        XCTAssertEqual(transcript.recover(receipt: pending!, answer: .notFound), .hold)
        XCTAssertEqual(transcript.locals.map(\.state), [.failed])
        XCTAssertEqual(transcript.sendCount, 1)
        XCTAssertEqual(transcript.retry(receipt: pending!, answer: .unconfirmed), .hold)
        XCTAssertEqual(transcript.sendCount, 1)
        guard case .sendOriginal(let again) = transcript.retry(receipt: pending!, answer: .notFound) else {
            return XCTFail("expected the original payload")
        }
        XCTAssertEqual(again.clientMessageID, "im_9")
        XCTAssertEqual(transcript.sendCount, 2)
        XCTAssertEqual(transcript.locals.map(\.state), [.sending])
        transcript.finish(receipt: pending!, accepted: true, serverID: "15")
        XCTAssertTrue(transcript.locals.isEmpty)
        XCTAssertEqual(transcript.sendCount, 2)
    }

    func testFoundReceiptMergesAndNeverSends() {
        var transcript = IMSendTranscript()
        let card = IMOutgoingPayload(clientMessageID: "im_card", kind: .card("{\"cardType\":\"location\"}"))
        let receipt = transcript.start(owner: "4", conversation: "7", payload: card)!
        XCTAssertEqual(card.content, "[卡片]")
        XCTAssertEqual(card.messageType, 3)
        transcript.finish(receipt: receipt, accepted: false, serverID: "0")
        let pending = transcript.resendReceipt(owner: "4", conversation: "7", temporaryID: "tmp_im_card")!
        XCTAssertEqual(transcript.recover(receipt: pending, answer: .found(serverID: "20", senderID: "4", clientMessageID: "im_card")), .merge(serverID: "20"))
        XCTAssertTrue(transcript.locals.isEmpty)
        XCTAssertEqual(transcript.sendCount, 1)
        XCTAssertEqual(transcript.retry(receipt: pending, answer: .notFound), .hold)
        XCTAssertEqual(transcript.sendCount, 1)
    }

    func testStaleReceiptCannotSendOrMerge() {
        var transcript = IMSendTranscript()
        let payload = IMOutgoingPayload(clientMessageID: "im_2", kind: .text("a"))
        let receipt = transcript.start(owner: "1", conversation: "1", payload: payload)!
        transcript.invalidate()
        transcript.finish(receipt: receipt, accepted: false, serverID: nil)
        XCTAssertEqual(transcript.locals.map(\.state), [.sending])
        XCTAssertEqual(transcript.recover(receipt: receipt, answer: .notFound), .hold)
        XCTAssertEqual(transcript.retry(receipt: receipt, answer: .notFound), .hold)
        XCTAssertEqual(transcript.sendCount, 1)
    }

    func testMergeReplacesSameClientAndSenderButHistoryDoesNot() {
        let existing = [IMMergeRow(id: "tmp_1", clientMessageID: "im_1", senderID: "4")]
        let server = [IMMergeRow(id: "20", clientMessageID: "im_1", senderID: "4")]
        XCTAssertEqual(IMMessageMerge.merge(existing: existing, incoming: server, prepend: false).map(\.id), ["20"])
        let older = [IMMergeRow(id: "3", clientMessageID: "im_3", senderID: "4")]
        let kept = IMMessageMerge.merge(existing: existing, incoming: older, prepend: true)
        XCTAssertEqual(kept.map(\.id), ["3", "tmp_1"])
    }

    func testReceiptReadsAreSharedAndAMissIsNotSilentForRetry() {
        var share = IMReceiptQueryShare()
        guard case .start(let token) = share.join(key: "4:7:im_1", purpose: .recover, flightStillCurrent: true) else {
            return XCTFail("first read starts")
        }
        guard case .attach(let same) = share.join(key: "4:7:im_1", purpose: .retry, flightStillCurrent: true) else {
            return XCTFail("retry joins the open read")
        }
        XCTAssertEqual(same, token)
        let delivered = share.finish(key: "4:7:im_1", token: token, foundFalse: true, foundValid: false)
        XCTAssertEqual(delivered?.purposes, .some([.recover, .retry]))
        XCTAssertEqual(delivered?.unconfirmedTip, false)
        XCTAssertNil(share.finish(key: "4:7:im_1", token: token, foundFalse: false, foundValid: false))
        guard case .start(let next) = share.join(key: "4:7:im_1", purpose: .retry, flightStillCurrent: false) else {
            return XCTFail("a stale flight starts a new read")
        }
        let tip = share.finish(key: "4:7:im_1", token: next, foundFalse: false, foundValid: false)
        XCTAssertEqual(tip, IMReceiptQueryShare.Delivery(purposes: [], unconfirmedTip: true))
        XCTAssertEqual(IMSendReceiptMerge.receiptPath, "api/im/send-receipt")
        XCTAssertEqual(IMSendReceiptMerge.receiptFields(conversation: "7", clientMessageID: "im_1")["client_message_id"], "im_1")
    }

    func testCardKindsAndSystemTargets() {
        let generic = IMCardDecode.card(messageType: 3, content: "x&lt;y", extraJSON: "{}", activityNotice: false)
        XCTAssertEqual(generic?.kind, .generic)
        XCTAssertEqual(generic?.title, "x<y")
        let route = IMCardDecode.card(messageType: 3, content: "[路线] 江边", extraJSON: "{\"cardType\":\"route\",\"topicId\":31}", activityNotice: false)
        XCTAssertEqual(route?.kind, .route)
        XCTAssertEqual(route?.topicID, "31")
        let named = IMSystemCardTarget.routeCache(kind: .route, content: "[路线] 江边", topicID: "31", imageURL: "https://example.com/a.jpg", mileage: 2, locations: 4)
        XCTAssertEqual(named?.value, .some(.named("江边", imageURL: "https://example.com/a.jpg", mileage: 2, locations: 4)))
        XCTAssertEqual(named?.fetch, false)
        XCTAssertEqual(IMSystemCardTarget.routeCache(kind: .route, content: "别的", topicID: "31")?.value, .some(.unavailable))
        XCTAssertEqual(IMSystemCardTarget.routeCache(kind: .signup, content: nil, topicID: "31", cached: nil)?.fetch, true)
        XCTAssertNil(IMSystemCardTarget.routeCache(kind: .signup, content: nil, topicID: "31", cached: .unavailable))
        XCTAssertEqual(IMSystemCardTarget.openURL("/pages/square/detail/index?id=41"), .some(.squarePost(41)))
        XCTAssertEqual(IMSystemCardTarget.openURL("/pages/topic/index/index?id=8"), .some(.topic(8)))
        XCTAssertEqual(IMSystemCardTarget.openURL("/subpackageMember/coupon-wallet/index"), .some(.blockedCouponWallet))
        XCTAssertNil(IMSystemCardTarget.openURL("/pages/wallet/index?id=1"))
        let notice = IMSystemCardTarget.activityNoticeOpen(senderID: "0", messageType: "1", extraJSON: "{\"type\":\"ACTIVITY_CANCELLED\",\"activityId\":9}")
        XCTAssertEqual(notice, .some(.activity(9)))
        XCTAssertNil(IMSystemCardTarget.activityNoticeOpen(senderID: "0", messageType: "1", extraJSON: "{\"type\":\"CLUB_CAMPAIGN\",\"activityId\":9}"))
        let action = IMSystemCardTarget.genericAction(senderID: "0", messageType: "3", card: ["cardType": "generic", "action": "/pages/activity/detail/index?id=6"])
        XCTAssertEqual(action.flatMap(\.open), .some(.activity(6)))
        let wallet = IMSystemCardTarget.genericAction(senderID: "0", messageType: "3", card: ["cardType": "generic", "action": "/subpackageMember/coupon-wallet/index"])
        XCTAssertEqual(wallet.flatMap(\.open), .some(.blockedCouponWallet))
        XCTAssertNil(IMSystemCardTarget.genericAction(senderID: "0", messageType: "3", card: ["cardType": "generic", "result": ["bizId": 1], "action": "/pages/topic/index/index?id=1"]))
    }

    func testRefreshPillOnlyOnSilentReloadOfALoadedList() {
        XCTAssertEqual(IMRefreshPill.begin(silent: false, loaded: false, identityChanged: false), .firstLoad)
        XCTAssertFalse(IMRefreshPill.showsPill(.firstLoad))
        XCTAssertEqual(IMRefreshPill.begin(silent: true, loaded: true, identityChanged: false), .pill)
        XCTAssertTrue(IMRefreshPill.showsPill(.pill))
        XCTAssertEqual(IMRefreshPill.text, "正在刷新消息")
        XCTAssertEqual(IMRefreshPill.begin(silent: true, loaded: true, identityChanged: true), .firstLoad)
        XCTAssertEqual(IMRefreshPill.fail(preserveConfirmed: true, denied: false, message: "x", loginRequired: false), .retainedFailure)
        XCTAssertEqual(IMRefreshPill.retainedFailure, "没刷新成功，显示的是之前的消息")
        XCTAssertEqual(IMRefreshPill.fail(preserveConfirmed: false, denied: false, message: "消息加载失败，请重试", loginRequired: true), .fullFailure(message: "消息加载失败，请重试", loginRequired: true))
        XCTAssertEqual(IMRefreshPill.fail(preserveConfirmed: true, denied: true, message: "请登录", loginRequired: true), .deniedCleared(message: "请登录", loginRequired: true))
        XCTAssertEqual(IMRefreshPill.succeed(), .ready)
    }

    func testReportNoticesKeepTheNewestReportAndMarkReadWithAStableKey() {
        let items = [
            IMReportNoticeItem(id: "5", notificationType: "SYSTEM_GOVERNANCE", payload: .init(reportID: "9", action: "REPORT_UPDATE", publicNote: " 已处理 "), createTime: "t", readAt: nil),
            IMReportNoticeItem(id: "4", notificationType: "SYSTEM_GOVERNANCE", payload: .init(reportID: "9", action: "REPORT_OPEN", publicNote: "旧"), createTime: "older", readAt: ""),
            IMReportNoticeItem(id: "3", notificationType: "SYSTEM_GOVERNANCE", payload: .init(reportID: "1", action: "POST_HIDDEN", publicNote: "不是举报"), createTime: "", readAt: "x")
        ]
        let rows = IMReportNotices.rows(items)
        XCTAssertEqual(rows?.map(\.reportID), ["9"])
        XCTAssertEqual(rows?.first?.title, "已处理")
        XCTAssertEqual(rows?.first?.unread, true)
        XCTAssertEqual(rows?.first?.notificationID, "5")
        XCTAssertNil(IMReportNotices.rows(nil))
        XCTAssertEqual(IMReportNotices.entry(rows: nil, failed: false).visible, true)
        XCTAssertEqual(IMReportNotices.entry(rows: [], failed: false).visible, false)
        XCTAssertEqual(IMReportNotices.entry(rows: rows, failed: false).unread, 1)
        XCTAssertEqual(IMReportNotices.readPath(notificationID: "5"), "api/v1/community/notifications/5/read")
        XCTAssertEqual(IMReportNotices.readRequestID(notificationID: "5", now: 1000, random: "ab"), "ntr-5-rs-ab")
        XCTAssertNil(IMReportNotices.readPath(notificationID: "0"))
    }

    func testCommunityWritesUseV1IncludingPatchAndDeleteAndKeepTheRequestId() throws {
        var wire = CommunityV1Wire()
        let minted = { "minted-1" }
        let like = try wire.like(id: 7, type: 1, viewerLiked: false, proposedID: nil, mint: minted).get()
        XCTAssertEqual(like.method, "POST")
        XCTAssertEqual(like.path, "api/v1/community/posts/7/actions")
        XCTAssertFalse(like.path.contains("creativesquare"))
        let again = try wire.like(id: 7, type: 1, viewerLiked: false, proposedID: "other", mint: { "minted-2" }).get()
        XCTAssertEqual(requestID(again), "minted-1")
        wire.settle(key: "action:7:LIKE:true", requestID: "minted-1", code: 503)
        XCTAssertEqual(wire.ledger.current("action:7:LIKE:true"), "minted-1")
        wire.settle(key: "action:7:LIKE:true", requestID: "nope", code: 200)
        XCTAssertEqual(wire.ledger.current("action:7:LIKE:true"), "minted-1")
        wire.settle(key: "action:7:LIKE:true", requestID: "minted-1", code: nil)
        wire.settle(key: "action:7:LIKE:true", requestID: "minted-1", code: 302)
        XCTAssertEqual(wire.ledger.current("action:7:LIKE:true"), "minted-1")
        wire.settle(key: "action:7:LIKE:true", requestID: "minted-1", code: 200)
        XCTAssertNil(wire.ledger.current("action:7:LIKE:true"))
        let unlike = try wire.like(id: 7, type: 1, viewerLiked: true, proposedID: "gone", mint: { "minted-3" }).get()
        XCTAssertEqual(unlike.method, "DELETE")
        XCTAssertEqual(unlike.path, "api/v1/community/posts/7/actions/LIKE")
        wire.settle(key: "action:7:LIKE:false", requestID: requestID(unlike), code: 409)
        XCTAssertNil(wire.ledger.current("action:7:LIKE:false"))
        XCTAssertEqual(wire.like(id: 7, type: 2, viewerLiked: false, proposedID: nil, mint: minted), .failure(.unsupported))
        XCTAssertEqual(wire.like(id: 7, type: 1, viewerLiked: nil, proposedID: nil, mint: minted), .failure(.refreshPost))
        let removal = try wire.deletePost(id: 7, version: 3, knownPost: true, proposedID: "del-1", mint: minted).get()
        XCTAssertEqual(removal.method, "DELETE")
        XCTAssertEqual(removal.path, "api/v1/community/posts/7")
        let commentLike = try wire.likeComment(id: 8, viewerLiked: true, proposedID: "c1", mint: minted).get()
        XCTAssertEqual(commentLike.method, "DELETE")
        XCTAssertEqual(commentLike.path, "api/v1/community/comments/8/actions/LIKE")
        let commentDelete = try wire.deleteComment(postID: 7, commentID: 8, version: 2, known: true, proposedID: "cd", mint: minted).get()
        XCTAssertEqual(commentDelete.method, "DELETE")
        XCTAssertEqual(commentDelete.path, "api/v1/community/posts/7/comments/8")
        XCTAssertEqual(wire.deleteComment(postID: 7, commentID: 8, version: 2, known: false, proposedID: nil, mint: minted), .failure(.refreshComment))
        let created = try wire.publish(contents: "走过", dataType: 1, dataID: 44, clientRequestID: "wire-1", guidelineID: 5, editing: nil, closedAttachment: false).get()
        XCTAssertEqual(created.method, "POST")
        XCTAssertEqual(created.path, "api/v1/community/posts")
        XCTAssertEqual(created.body, .object([
            "audience": .string("PUBLIC"),
            "body": .string("走过"),
            "clientRequestId": .string("wire-1"),
            "commentPolicy": .string("EVERYONE"),
            "guidelineVersionId": .int(5),
            "locationPrecision": .string("NONE"),
            "mediaIds": .array([]),
            "postType": .string("ACTIVITY_RECAP"),
            "references": .array([.object(["referenceId": .int(44), "referenceType": .string("ACTIVITY")])])
        ]))
        let patched = try wire.publish(contents: "改", dataType: 3, dataID: 9, clientRequestID: "wire-1", guidelineID: 5, editing: .init(id: 70, expectedVersion: 4), closedAttachment: false).get()
        XCTAssertEqual(patched.method, "PATCH")
        XCTAssertEqual(patched.path, "api/v1/community/posts/70")
        if case .object(let fields) = patched.body {
            XCTAssertEqual(fields["postType"], .string("ROUTE_DISCOVERY"))
            XCTAssertEqual(fields["expectedVersion"], .int(4))
        } else { XCTFail("patch body") }
        XCTAssertEqual(wire.publish(contents: "x", dataType: 9, dataID: 1, clientRequestID: "wire-1", guidelineID: 5, editing: nil, closedAttachment: false), .failure(.unsupportedLink))
        XCTAssertEqual(wire.publish(contents: "x", dataType: nil, dataID: nil, clientRequestID: "wire-1", guidelineID: 5, editing: nil, closedAttachment: true), .failure(.attachmentClosed))
        let topic = try wire.publish(contents: "题", dataType: 2, dataID: 3, clientRequestID: "wire-1", guidelineID: 5, editing: nil, closedAttachment: false).get()
        if case .object(let fields) = topic.body { XCTAssertEqual(fields["postType"], .string("MOMENT")) } else { XCTFail("topic body") }
        XCTAssertEqual(wire.drafts().method, "GET")
        XCTAssertEqual(wire.drafts().path, "api/v1/community/drafts")
        let published = try wire.publishDraft(id: 70, expectedVersion: 4, requestID: "pub-1").get()
        XCTAssertEqual(published.method, "POST")
        XCTAssertEqual(published.path, "api/v1/community/posts/70/publish")
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let request = try removal.urlRequest(configuration: configuration, token: "fixture-token")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.path, "/api/v1/community/posts/7")
        let money = CommunityV1Call(method: "POST", path: "api/pay/app")
        XCTAssertThrowsError(try money.urlRequest(configuration: configuration, token: "fixture-token")) { error in
            XCTAssertEqual(error as? CommunityWireBlock, .moneyOff)
        }
        XCTAssertFalse(CloudL5Money.enabled)
        XCTAssertTrue(CloudL5Money.isPaymentPath("api/wallet/balance"))
    }

    func testFeedPagesAndDraftRecovery() throws {
        var wire = CommunityV1Wire()
        let first = try wire.list(page: 1, pageSize: 10, favoriteOnly: false, mine: false, authorID: nil).get()
        XCTAssertEqual(first.method, "GET")
        XCTAssertEqual(first.path, "api/v1/community/feeds/LATEST")
        XCTAssertEqual(wire.list(page: 2, pageSize: 10, favoriteOnly: false, mine: false, authorID: nil), .failure(.stalePage))
        wire.noteListPage(favoriteOnly: false, mine: false, authorID: nil, page: 1, next: "99")
        let second = try wire.list(page: 2, pageSize: 10, favoriteOnly: false, mine: false, authorID: nil).get()
        XCTAssertEqual(second.query["cursor"], "99")
        let saved = try wire.list(page: 1, pageSize: 10, favoriteOnly: true, mine: false, authorID: nil).get()
        XCTAssertEqual(saved.path, "api/v1/community/me/bookmarks")
        let mine = try wire.list(page: 1, pageSize: 10, favoriteOnly: false, mine: true, authorID: 4).get()
        XCTAssertEqual(mine.path, "api/v1/community/me/posts")
        XCTAssertEqual(try wire.detail(id: 70).get().path, "api/v1/community/posts/70")
        var book = CommunityPageBook.firstPage()
        XCTAssertEqual(try wire.comments(postID: 70, page: 1, pageSize: 20, book: book).get().path, "api/v1/community/posts/70/comments")
        book.recordNext(page: 1, next: nil)
        XCTAssertNil(try wire.comments(postID: 70, page: 2, pageSize: 20, book: book).get().query["cursor"])
        XCTAssertEqual(CommunityDraftMatch.match(items: [.init(id: 5, clientRequestID: "wire-1"), .init(id: 6, clientRequestID: "wire-1")], hasMore: false, wireKey: "wire-1"), .ambiguous)
        XCTAssertEqual(CommunityDraftMatch.match(items: [.init(id: 5, clientRequestID: "wire-1")], hasMore: false, wireKey: "wire-1"), .found(5))
        XCTAssertEqual(CommunityDraftMatch.match(items: [], hasMore: false, wireKey: "wire-1"), .absent)
        XCTAssertEqual(CommunityDraftMatch.match(items: [], hasMore: true, wireKey: "wire-1"), .unreadable)
        let row = CommunityPostProjection.normalize(postID: "70", body: "a&amp;b", lifecycle: "PUBLISHED", viewerFollowing: true, mediaURLs: ["a.jpg", ""], referenceType: "ACTIVITY", referenceID: "44", topicProjection: "12")
        XCTAssertEqual(row?.body, "a&b")
        XCTAssertEqual(row?.following, 1)
        XCTAssertEqual(row?.legacyStatus, .published)
        XCTAssertEqual(row?.dataType, 1)
        XCTAssertEqual(row?.sportTopicID, "12")
        XCTAssertEqual(row?.pics, "a.jpg")
        XCTAssertNil(CommunityPostProjection.normalize(postID: "1", body: "", lifecycle: "DRAFT", viewerFollowing: nil, mediaURLs: [], referenceType: nil, referenceID: nil, topicProjection: nil)?.following)
    }

    func testShareFollowDraftsActivityAndRouteMap() {
        let hidden = SquareShareCard.build(.init(id: "9", audience: "FOLLOWERS", status: "1", contents: "秘密", pics: "https://example.com/a.jpg", picList: nil))
        XCTAssertEqual(hidden.path, SquareShareCard.genericPath)
        XCTAssertNil(hidden.imageURL)
        let shared = SquareShareCard.build(.init(id: "9", audience: nil, status: nil, contents: "  城墙  夜跑  ", pics: "https://example.com/a.jpg;not-a-url", picList: nil))
        XCTAssertEqual(shared.title, "城墙 夜跑")
        XCTAssertEqual(shared.path, "/pages/square/detail/index?id=9")
        XCTAssertEqual(shared.imageURL, "https://example.com/a.jpg")
        let long = String(repeating: "城", count: 30)
        XCTAssertEqual(SquareShareCard.build(.init(id: "1", audience: "public", status: "1", contents: long, pics: nil, picList: nil)).title.count, 29)
        XCTAssertNil(SquareFollowWrite.toggle(memberID: 8, isFollowing: true, inFlight: true))
        let unfollow = SquareFollowWrite.toggle(memberID: 8, isFollowing: true, inFlight: false)
        XCTAssertEqual(unfollow?.follow, 0)
        XCTAssertEqual(unfollow?.fields["follow_member_id"], "8")
        XCTAssertEqual(SquareFollowWrite.displayedFollowing(intended: 0), 0)
        XCTAssertEqual(SquareFollowWrite.commentFollow(memberID: 8, inFlight: false)?.follow, 1)
        XCTAssertNil(SquareDraftSheet.select(keys: ["a"], index: 3))
        XCTAssertEqual(SquareDraftSheet.delete(keys: ["a", "b"], index: 1)?.key, "b")
        var picker = SquareActivityPicker()
        XCTAssertTrue(picker.beginFetch())
        XCTAssertFalse(picker.beginFetch())
        picker.endFetch(activities: [.init(id: 1, topicID: nil), .init(id: 2, topicID: "31")])
        XCTAssertEqual(picker.select(index: 0), .immediate(.init(id: 1, topicID: nil)))
        guard case .preview(let activity, let generation) = picker.select(index: 1) else { return XCTFail("preview") }
        XCTAssertEqual(activity.topicID, "31")
        XCTAssertTrue(picker.beginSnapshot(generation: generation))
        XCTAssertFalse(picker.beginSnapshot(generation: generation))
        XCTAssertEqual(picker.finish(generation: generation)?.id, 2)
        XCTAssertNil(picker.finish(generation: generation))
        _ = picker.select(index: 1)
        let stale = picker.generation
        picker.close()
        XCTAssertNil(picker.finish(generation: stale))
        let straight = SquareRouteMap.build([.init(nodes: [
            .init(latitude: .number(31.2), longitude: .number(121.5), name: "甲", sortID: 2),
            .init(latitude: .text("31.3"), longitude: .text("121.4"), name: "乙", sortID: 1)
        ])])
        XCTAssertTrue(straight.routeReady)
        XCTAssertFalse(straight.routeIsRoad)
        XCTAssertEqual(straight.markers.map(\.callout), ["1 乙", "2 甲"])
        XCTAssertEqual(straight.routeSourceText, "节点直线预览 · 尚未规划步行路线，章间未规划")
        let brokenRoad = SquareRouteMap.build([.init(nodes: [.init(lat: .number(1), lng: .number(2), sortID: 1)], routeGeometryAvailable: true, routeGeometry: [
            .init(latitude: .number(1), longitude: .number(2)),
            .init(latitude: .text("nope"), longitude: .number(3))
        ])])
        XCTAssertFalse(brokenRoad.routeIsRoad)
        XCTAssertTrue(brokenRoad.lines.isEmpty)
        let road = SquareRouteMap.build([.init(nodes: [.init(latitude: .number(1), longitude: .number(2))], routeGeometryAvailable: true, routeGeometryError: false, routeGeometry: [
            .init(latitude: .number(1), longitude: .number(2)),
            .init(latitude: .number(1.1), longitude: .number(2.1))
        ])])
        XCTAssertTrue(road.routeIsRoad)
        XCTAssertEqual(road.lines.first?.road, true)
        XCTAssertEqual(SquareRouteMap.build([]).routeReady, false)
        var repost = ClubPostRepostToggle()
        XCTAssertNil(repost.begin(postID: "9", rows: [.init(id: "9", isCommunity: true, state: .init(reposted: false, count: 2))]))
    }

    private func requestID(_ call: CommunityV1Call) -> String? {
        guard case .object(let fields) = call.body, case .string(let id) = fields["requestId"] else { return nil }
        return id
    }
}
#endif
