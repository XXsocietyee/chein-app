import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Pins account-publish requests the mini-program sends with `sendRequest`, `req`, or
/// `sendUiStateRequest`. hengyin `chengyinhub-xcx` `25eb6a0c`. Money writes stay off.
final class AccountPublishMPContractTests: XCTestCase {
    private let base = URL(string: "https://example.com")!

    func testUserInfoPinsMemberIDForSettings() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7", token: "synthetic")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/info")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(try body(request), "member_id=7")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        let access = AccountPublishMPContract.settingsAccess(status: 200, body: Data(#"{"code":"200","data":{"role":"merchant","phone":"13800138000","isClubLeader":false}}"#.utf8))
        guard case let .ready(read) = access else { return XCTFail("expected a settings read") }
        XCTAssertEqual(read.role, "merchant")
        XCTAssertFalse(read.viewKeys.contains("phone"))
        XCTAssertEqual(AccountPublishMPContract.settingsAccess(status: 403, body: Data(#"{"code":403}"#.utf8)), .denied)
        XCTAssertEqual(AccountPublishMPContract.settingsAccess(status: 200, body: Data(#"{"code":"401"}"#.utf8)), .signedOut)
    }

    func testUserInfoPinsMemberIDForSettingsProfileForm() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/info")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        let form = try XCTUnwrap(AccountPublishMPContract.settingsProfileForm(from: Data(#"{"code":200,"data":{"name":"小城","email":"a@example.com"}}"#.utf8)))
        XCTAssertEqual(form.nickname, "小城")
        XCTAssertEqual(form.email, "a@example.com")
    }

    func testUserInfoPinsMemberIDForHome() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/info")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        let home = try XCTUnwrap(AccountPublishMPContract.homeAccount(from: Data(#"{"code":200,"data":{"role":"player","userType":1,"isClubLeader":true,"avatar":"a.png","nickname":"小林"}}"#.utf8)))
        XCTAssertEqual(home.role, "player")
        XCTAssertEqual(home.userType, 1 as Int?)
        XCTAssertTrue(home.isClubLeader)
        XCTAssertEqual(home.avatar, "a.png")
        XCTAssertEqual(home.nickname, "小林")
        XCTAssertEqual(home.greeting, "你好，小林")
        let placeholder = try XCTUnwrap(AccountPublishMPContract.homeAccount(from: Data(#"{"code":200,"data":{"role":"club","nickname":"用户123"}}"#.utf8)))
        XCTAssertTrue(placeholder.isClubLeader)
        XCTAssertEqual(placeholder.greeting, "你好")
    }

    func testUserInfoPinsMemberIDForProfileEditor() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        let editor = try XCTUnwrap(AccountPublishMPContract.profileEditor(from: Data(#"{"code":200,"data":{"name":"  ","nickname":"小城","phone":"13800138000","avatar":"a.png","casePics":"u1; ;u2","introduction":"hi","wechat":"qr.png"}}"#.utf8)))
        XCTAssertEqual(editor.shownName, "小城")
        XCTAssertEqual(editor.phone, "13800138000")
        XCTAssertEqual(editor.phoneMasked, "138****8000")
        XCTAssertEqual(editor.avatar, "a.png")
        XCTAssertEqual(editor.casePictures, ["u1", "u2"])
        XCTAssertEqual(editor.introduction, "hi")
        XCTAssertEqual(editor.wechat, "qr.png")
    }

    func testUserInfoPinsMemberIDForBoundPhone() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        XCTAssertEqual(AccountPublishMPContract.boundMobile(from: Data(#"{"code":200,"data":{"mobilePhone":"13800138000"}}"#.utf8)), "13800138000")
        XCTAssertNil(AccountPublishMPContract.boundMobile(from: Data(#"{"code":200,"data":{"phone":"123"}}"#.utf8)))
    }

    func testUserInfoPinsMemberIDForDeregisterSMS() throws {
        let info = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(info.httpMethod, "POST")
        XCTAssertEqual(info.url?.path, "/api/user/info")
        XCTAssertEqual(formKeys(try body(info)), ["member_id"])
        let phone = try XCTUnwrap(AccountPublishMPContract.deregisterPhone(from: Data(#"{"code":200,"data":{"phone":" 13800138000 "}}"#.utf8)))
        XCTAssertEqual(phone, "13800138000")
        XCTAssertNil(AccountPublishMPContract.deregisterPhone(from: Data(#"{"code":200,"data":{"phone":"  "}}"#.utf8)))
        XCTAssertThrowsError(try AccountPublishMPContract.smsSendRequest(baseURL: base, phone: " "))
        let sms = try AccountPublishMPContract.smsSendRequest(baseURL: base, phone: phone)
        XCTAssertEqual(sms.httpMethod, "POST")
        XCTAssertEqual(sms.url?.path, "/api/sms/send")
        XCTAssertEqual(try body(sms), "phone=13800138000")
        XCTAssertEqual(formKeys(try body(sms)), ["phone"])
    }

    func testSMSSendPinsPhone() throws {
        let request = try AccountPublishMPContract.smsSendRequest(baseURL: base, phone: "13800138000")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/sms/send")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(formKeys(try body(request)), ["phone"])
    }

    func testUserInfoPinsMemberIDForPublishOwner() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        let fabu = try XCTUnwrap(AccountPublishMPContract.fabuOwner(from: Data(#"{"code":200,"data":{"id":42,"nickname":"我","avatar":"a.png"}}"#.utf8)))
        XCTAssertEqual(fabu.id, 42)
        XCTAssertEqual(fabu.nickname, "我")
        XCTAssertEqual(fabu.avatar, "a.png")
        let activity = try XCTUnwrap(AccountPublishMPContract.activityOwner(from: Data(#"{"code":200,"data":{"id":42,"nickname":" 发起人 ","avatar":"b.png"}}"#.utf8)))
        XCTAssertEqual(activity.nickname, "发起人")
        XCTAssertNil(AccountPublishMPContract.activityOwner(from: Data(#"{"code":200,"data":{"id":42,"nickname":"  "}}"#.utf8)))
    }

    func testUserInfoPinsMemberIDForSelfProfile() throws {
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        let profile = try XCTUnwrap(AccountPublishMPContract.selfProfile(from: Data(#"{"code":200,"data":{"role":"player","city":"杭州","createTime":"2026-01-02 08:00:00","balance":null,"casePics":"p1;p2","sysCategoryList":[{"id":1,"categoryName":"徒步"}],"friendNum":null,"followNum":2,"fansNum":3,"topicNum":1,"activityNum":0,"likeNum":4}}"#.utf8)))
        XCTAssertEqual(profile.role, "player")
        XCTAssertEqual(profile.city, "杭州")
        XCTAssertEqual(profile.joinDate, "2026.01.02")
        XCTAssertNil(profile.balanceText)
        XCTAssertEqual(profile.casePictures, ["p1", "p2"])
        XCTAssertEqual(profile.categories, ["徒步"])
        XCTAssertEqual(profile.friendDisplay, 0.0)
        XCTAssertEqual(profile.followNum, 2 as Double?)
        XCTAssertEqual(profile.fanNum, 3 as Double?)
        XCTAssertTrue(profile.metricsReady)
    }

    func testUserInfoEarningsBalanceStaysReadOnly() throws {
        XCTAssertFalse(AccountPublishMPContract.moneyEnabled)
        let request = try AccountPublishMPContract.userInfoRequest(baseURL: base, memberID: "7")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/info")
        XCTAssertEqual(formKeys(try body(request)), ["member_id"])
        XCTAssertFalse(request.url?.path.contains("pay") == true)
        XCTAssertFalse(request.url?.path.contains("withdraw") == true)
        XCTAssertEqual(AccountPublishMPContract.earningsBalance(from: Data(#"{"code":200,"data":{"balance":"12.5"}}"#.utf8)), .amount("12.50"))
        XCTAssertEqual(AccountPublishMPContract.earningsBalance(from: Data(#"{"code":200,"data":{"balance":null}}"#.utf8)).display, "0.00" as String?)
        XCTAssertEqual(AccountPublishMPContract.earningsBalance(from: Data(#"{"code":200,"data":{"balance":-1}}"#.utf8)), .invalid)
    }

    func testDeregisterStatusPinsGet() throws {
        let request = try AccountPublishMPContract.deregisterStatusRequest(baseURL: base)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/user/deregister/status")
        XCTAssertNil(request.httpBody)
        let read = AccountPublishMPContract.deregisterStatus(status: 200, body: Data(#"{"code":200,"data":{"status":"PENDING","executeAfter":"2026-09-24T10:30:00.000+08:00"}}"#.utf8))
        guard case let .ready(status) = read else { return XCTFail("expected a status") }
        XCTAssertEqual(status.status, "PENDING")
        XCTAssertEqual(status.executeAfter, "2026-09-24T10:30:00.000+08:00")
        XCTAssertEqual(AccountPublishMPContract.deregisterStatus(status: 401, body: Data()), .loginRequired)
        XCTAssertEqual(AccountPublishMPContract.deregisterStatus(status: 200, body: Data(#"{"code":200,"data":{"status":1}}"#.utf8)), .unreadable)
    }

    func testDeregisterPrecheckPinsPost() throws {
        let request = try AccountPublishMPContract.deregisterPrecheckRequest(baseURL: base)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/deregister/precheck")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertNil(request.httpBody)
        let precheck = try XCTUnwrap(AccountPublishMPContract.deregisterPrecheck(from: Data(#"{"code":200,"data":{"status":"ELIGIBLE","blockers":[],"verificationMethod":null}}"#.utf8)))
        XCTAssertEqual(precheck.status, "ELIGIBLE")
        XCTAssertEqual(precheck.blockers, [])
        XCTAssertEqual(precheck.verificationMethod, "SMS")
        let blocked = try XCTUnwrap(AccountPublishMPContract.deregisterPrecheck(from: Data(#"{"code":200,"data":{"status":"BLOCKED","blockers":[" 还有未完成的订单 "]}}"#.utf8)))
        XCTAssertEqual(blocked.blockers, ["还有未完成的订单"])
        XCTAssertEqual(blocked.verificationMethod, "UNAVAILABLE")
        XCTAssertNil(AccountPublishMPContract.deregisterPrecheck(from: Data(#"{"code":200,"data":{"status":"ELIGIBLE","blockers":["还有订单"]}}"#.utf8)))
    }

    func testDeregisterApplyPinsRequestIDAndSMSCode() throws {
        let request = try AccountPublishMPContract.deregisterApplyRequest(baseURL: base, requestID: "deregister-1", smsCode: "123456")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/deregister/apply")
        XCTAssertEqual(try body(request), "requestId=deregister-1&smscode=123456")
        XCTAssertEqual(formKeys(try body(request)), ["requestId", "smscode"])
        let outcome = AccountPublishMPContract.deregisterApply(from: Data(#"{"code":200,"data":{"status":"PENDING","executeAfter":"2026-09-24T10:30:00.000+08:00"}}"#.utf8))
        XCTAssertEqual(outcome, .pending(executeAfter: "2026-09-24T10:30:00.000+08:00") as AccountPublishMPContract.DeregisterApplyOutcome?)
    }

    func testDeregisterApplyPinsRequestIDAndWXCode() throws {
        let request = try AccountPublishMPContract.deregisterApplyRequest(baseURL: base, requestID: "deregister-1", wxCode: "wx-code")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/deregister/apply")
        XCTAssertEqual(try body(request), "requestId=deregister-1&wxcode=wx-code")
        XCTAssertEqual(formKeys(try body(request)), ["requestId", "wxcode"])
        let outcome = AccountPublishMPContract.deregisterApply(from: Data(#"{"code":200,"data":{"status":"BLOCKED","blockers":["还有订单"]}}"#.utf8))
        XCTAssertEqual(outcome, .blocked(["还有订单"]) as AccountPublishMPContract.DeregisterApplyOutcome?)
    }

    func testDeregisterCancelPinsPost() throws {
        let request = try AccountPublishMPContract.deregisterCancelRequest(baseURL: base)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/user/deregister/cancel")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(AccountPublishMPContract.deregisterCancel(from: Data(#"{"code":200,"data":{"status":"CANCELLED"}}"#.utf8)), "CANCELLED" as String?)
        XCTAssertNil(AccountPublishMPContract.deregisterCancel(from: Data(#"{"code":200,"data":{"status":"PENDING"}}"#.utf8)))
    }

    func testTeamHandlePinsCommand() throws {
        let requestID = "0123456789abcdef0123456789abcdef"
        let request = try AccountPublishMPContract.teamHandleRequest(
            baseURL: base, memberID: "990007", approved: true, targetID: "31", requestID: requestID)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/team/command")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(
            try body(request),
            #"{"memberId":"990007","approved":true,"targetId":"31","action":"handle","requestId":"\#(requestID)"}"#)
        XCTAssertFalse(request.url?.path.hasSuffix("api/team/handle") == true)
        let receipt = try XCTUnwrap(AccountPublishMPContract.teamHandleReceipt(from: Data(#"{"code":200,"data":{"requestId":"0123456789abcdef0123456789abcdef","state":"REJECTED","message":"申请状态已变化，请刷新后重试","errorCode":"TEAM_CHANGED"}}"#.utf8)))
        XCTAssertEqual(receipt.requestID, requestID)
        XCTAssertEqual(receipt.state, "REJECTED")
        XCTAssertEqual(receipt.rejectNotice, "申请状态已变化，请刷新后重试")
        XCTAssertEqual(receipt.errorCode, "TEAM_CHANGED")
        XCTAssertFalse(receipt.showsRecoveryCard)
        XCTAssertNil(AccountPublishMPContract.teamHandleReceipt(from: Data(#"{"code":500,"data":{}}"#.utf8)))
    }

    func testClubPostFeedPinsScopeLimitAndBeforeID() throws {
        let first = try AccountPublishMPContract.clubPostFeedRequest(baseURL: base, limit: 20)
        XCTAssertEqual(first.httpMethod, "POST")
        XCTAssertEqual(first.url?.path, "/api/club/post/feed")
        XCTAssertEqual(try body(first), #"{"scope":"all","limit":20}"#)
        let next = try AccountPublishMPContract.clubPostFeedRequest(baseURL: base, limit: 20, beforeID: 9)
        XCTAssertEqual(try body(next), #"{"scope":"all","limit":20,"beforeId":9}"#)
        let page = try AccountPublishMPContract.discoverFeed(from: Data(#"{"code":200,"data":{"hasMore":true,"rows":[{"id":9,"clubId":3,"authorMemberId":4,"nickname":"小城","avatar":"a.png","content":"x&lt;y","images":"p1;p2,p3;p4","createTime":"2026-10-21 10:00:00","refType":2}]}}"#.utf8))
        XCTAssertEqual(page.hasMore, true as Bool?)
        XCTAssertNil(page.clubCount)
        let post = try XCTUnwrap(page.posts.first)
        XCTAssertEqual(post.id, 9 as Int?)
        XCTAssertEqual(post.clubID, 3 as Int?)
        XCTAssertEqual(post.authorMemberID, 4 as Int?)
        XCTAssertEqual(post.nickname, "小城")
        XCTAssertEqual(post.avatar, "a.png")
        XCTAssertEqual(post.content, "x<y")
        XCTAssertEqual(post.images, ["p1", "p2", "p3"])
        XCTAssertEqual(post.createTime, "2026-10-21 10:00:00")
        XCTAssertEqual(post.formattedCreateTime, "10-21 10:00")
        XCTAssertEqual(post.refType, 2 as Int?)
        XCTAssertThrowsError(try AccountPublishMPContract.discoverFeed(from: Data(#"{"code":200,"data":{"hasMore":1,"rows":[]}}"#.utf8)))
    }

    func testClubPostFeedPinsAuthorMe() throws {
        let request = try AccountPublishMPContract.ownClubPostsRequest(baseURL: base)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/club/post/feed")
        XCTAssertEqual(try body(request), #"{"scope":"all","author":"me","limit":20}"#)
        let posts = AccountPublishMPContract.ownClubPosts(from: Data(#"{"code":200,"data":{"rows":[{"id":8,"clubId":3,"authorMemberId":7,"nickname":"我","avatar":"a.png","content":"x&lt;y","images":"one","createTime":"2026-10-21 10:00:00"}]}}"#.utf8))
        let post = try XCTUnwrap(posts.first)
        XCTAssertEqual(post.id, 8 as Int?)
        XCTAssertEqual(post.clubID, 3 as Int?)
        XCTAssertEqual(post.content, "x&lt;y")
        XCTAssertEqual(post.images, ["one"])
        XCTAssertEqual(AccountPublishMPContract.ownClubPosts(from: Data(#"{"code":200,"data":{"rows":"bad"}}"#.utf8)), [])
    }

    private func body(_ request: URLRequest) throws -> String {
        String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
    }

    private func formKeys(_ body: String) -> [String] {
        body.split(separator: "&").map { String($0.split(separator: "=", maxSplits: 1).first ?? "") }
    }
}
