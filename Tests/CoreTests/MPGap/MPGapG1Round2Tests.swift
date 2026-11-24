import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class MPGapR2MockTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var responseBody = #"{"code":200,"data":{}}"#
    var statusCode = 200

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(responseBody.utf8), statusCode)
    }
}

final class MPGapG1Round2Tests: XCTestCase {
    // MARK: - PlayerContent Round-1 & Round-2 Types

    func testPlayerContentRound1Models() {
        let pin = TopicRouteNodePin(id: "n1", sequence: 1, name: "起点", latitude: 31.2, longitude: 121.4, isCompleted: true)
        let team = TopicRouteTeamSummary(id: 1, name: "探索小队", memberCount: 3, missingCount: 1)
        let merchant = TopicFreeExploreMerchantCard(id: 2, merchantName: "咖啡馆", address: "南京路", perkTitle: "九折", coverURL: nil)
        let ageRange = ActivityChildAgeRange(minAge: 6, maxAge: 10)
        let delivery = ActivityDeliveryItem(id: "d1", label: "包含", value: "实体手册")
        let resv = ActivityHostReservationState(isShown: true, statusText: "待确认", canRequest: true)
        let priceField = TopicPricingPerTicketField(id: 10, ticketName: "单人票", priceText: "68")
        let extra = TopicPricingExtraStatus(saleStatusText: "售卖中", settlementPendingText: "无", platformFeeRatePercent: 6.0)
        let lb = OfficialEventLeaderboardRow(id: "r1", rank: 1, displayName: "玩家甲", scoreText: "100", isSelf: true)

        XCTAssertEqual(pin.sequence, 1)
        XCTAssertEqual(team.missingCount, 1)
        XCTAssertEqual(merchant.perkTitle, "九折")
        XCTAssertEqual(ageRange.options, [6, 7, 8, 9, 10])
        XCTAssertEqual(delivery.value, "实体手册")
        XCTAssertTrue(resv.canRequest)
        XCTAssertEqual(priceField.priceText, "68")
        XCTAssertEqual(extra.platformFeeRatePercent, 6.0)
        XCTAssertTrue(lb.isSelf)
        XCTAssertEqual(MerchantHostWorkbenchAction.allCases.count, 6)
    }

    func testTemplateShelfPaginationAndGrouping() {
        XCTAssertTrue(TemplateShelfPagination.hasMore(loadedInPage: 50, totalLoaded: 50, serverTotal: 120))
        XCTAssertFalse(TemplateShelfPagination.hasMore(loadedInPage: 50, totalLoaded: 100, serverTotal: 100))
        XCTAssertFalse(TemplateShelfPagination.hasMore(loadedInPage: 20, totalLoaded: 20, serverTotal: nil))

        let items = [
            TemplateShelfPagedItem(id: 1, title: "A", groupName: "推理"),
            TemplateShelfPagedItem(id: 2, title: "B", groupName: ""),
            TemplateShelfPagedItem(id: 3, title: "C", groupName: "推理")
        ]
        let grouped = TemplateShelfPagination.grouped(items)
        XCTAssertEqual(grouped.map(\.group), ["推理", "其他玩法"])
        XCTAssertEqual(grouped[0].items.count, 2)
    }

    func testUnifiedSearchValidationAndScope() {
        XCTAssertFalse(UnifiedSearchValidator.canSubmit(keyword: "  ", categoryID: nil))
        XCTAssertTrue(UnifiedSearchValidator.canSubmit(keyword: "城", categoryID: nil))
        XCTAssertTrue(UnifiedSearchValidator.canSubmit(keyword: "", categoryID: 3))

        let row = UnifiedSearchResultRow(id: "p1", targetID: 9, kind: .post, title: "攻略", subtitle: "广场")
        XCTAssertEqual(row.kind, .post)

        let scope = TemplateDetailQueryScope(templateID: 5, scope: "my", operationScope: "MERCHANT", readonly: "1")
        XCTAssertTrue(scope.isMyScope)
        XCTAssertTrue(scope.isMerchantOperationScope)
        XCTAssertTrue(scope.isReadonly)
    }

    func testTopicOwnerReviewChipAndActivityTicketWindow() {
        XCTAssertEqual(TopicOwnerReviewChipState.from(userStatus: 0, status: nil, rejectReason: nil)?.label, "审核中")
        let rejected = TopicOwnerReviewChipState.from(userStatus: 2, status: nil, rejectReason: "封面模糊")
        XCTAssertEqual(rejected?.label, "未通过")
        XCTAssertTrue(rejected?.isDanger == true)
        XCTAssertEqual(TopicOwnerReviewChipState.from(userStatus: nil, status: 3, rejectReason: nil)?.label, "已下架")

        let ticket = ActivityTicketWindowInfo(id: 1, name: "早鸟票", windowText: "10:00-12:00", lineupNames: ["主持A"])
        XCTAssertEqual(ticket.lineupNames, ["主持A"])
    }

    func testSearchMapRichBlocksAnalysisPolicyAndIMMenu() {
        let place = SearchMapPlaceItem(id: "m1", title: "书店", subtitle: "站点", address: "淮海路", latitude: 31.2, longitude: 121.4, kindLabel: "商家")
        let chip = SearchMapCategoryChip(id: 1, name: "咖啡")
        XCTAssertEqual(place.kindLabel, "商家")
        XCTAssertEqual(chip.name, "咖啡")

        let block = SocialArticleRichBlock.link(id: "b1", title: "查看", url: "https://example.com")
        XCTAssertEqual(block.id, "b1")

        let now = Date()
        let cutoff = now.addingTimeInterval(-86400 * 180)
        XCTAssertTrue(WalletAnalysisPagingPolicy.shouldContinue(pageItemCount: 200, oldestItemDate: now, cutoffDate: cutoff))
        XCTAssertFalse(WalletAnalysisPagingPolicy.shouldContinue(pageItemCount: 200, oldestItemDate: cutoff.addingTimeInterval(-10), cutoffDate: cutoff))
        XCTAssertEqual(IMComposerPlusItem.allCases.map(\.title), ["图片", "位置", "路线", "投票"])
    }

    @MainActor
    func testPlayerContentRound2ServicePaths() async {
        let transport = MPGapR2MockTransport()
        let service = PlayerContentRound2Service(baseURL: URL(string: "https://example.com")!, token: { "tok-1234" }, transport: transport)

        _ = await service.fetchTemplateShelfPage(pageNum: 1, keyword: "城")
        _ = await service.searchUnified(keyword: "城")
        _ = await service.fetchMerchantCategories()
        _ = await service.fetchMyTemplateDetail(id: 7, operationScope: "MERCHANT")
        _ = await service.fetchMerchantPrefillInfo()
        _ = await service.fetchMerchantRegistrations()
        _ = await service.fetchMerchantChapterApplications()
        _ = await service.fetchActivityCancelPreview(activityID: 12)
        _ = await service.fetchCoopFinance()
        _ = await service.markConversationRead(conversationID: "c1", readToMessageID: "m9")
        _ = await service.reportPeerMember(memberID: 88, reason: "违规")

        XCTAssertEqual(transport.requests.compactMap { $0.url?.path }, [
            "/api/template/list",
            "/api/search/unified",
            "/api/category/list",
            "/api/template/my/info",
            "/api/merchant/info",
            "/api/registration/merchant/list",
            "/api/merchant/chapter-application/mine",
            "/api/activity/cancel_preview",
            "/api/coop/finance",
            "/api/im/read",
            "/api/report/create"
        ])
    }

    // MARK: - PlayRoam Round-1 & Round-2 Types

    func testPlayRoamModelsAndMergeDedupe() {
        let skip = PlayLeadSkipRequest(memberID: 1, nodeID: 2, nickname: "小明", nodeName: "钟楼")
        let lead = PlayLeadToolsState(exists: true, isLeader: true, skipRequests: [skip])
        let thought = PlayStoryThoughtItem(id: "t1", name: "神秘钥匙", isDone: false, progress: 2, needed: 3)
        let runner = RoamNearbyRunner(id: 3, nickname: "旅人", distanceMeters: 120)
        let slip = CityStampSlipData(place: "外滩", timeLabel: "10:30", serial: "001", senderTime: "10:00")
        let cat = ObjectCardCategoryOption(id: "c1", title: "建筑", systemImage: "building.2")
        let photo = JourneyReportNodePhotoItem(id: "p1", nodeName: "第一站", photoURL: "https://example.com/1.jpg")

        XCTAssertTrue(lead.isLeader)
        XCTAssertEqual(thought.statusText, "2/3 步")
        XCTAssertEqual(runner.distanceMeters, 120)
        XCTAssertEqual(RoamMapStyleOption.allCases.count, 3)
        XCTAssertEqual(slip.serial, "001")
        XCTAssertEqual(cat.title, "建筑")
        XCTAssertEqual(photo.nodeName, "第一站")

        let local = [
            MergedRoamHistoryRow(id: "l1", sessionID: "s1", timestamp: 100, title: "本地1", distanceKM: 1.2, durationText: "10分", isLocalOnly: true),
            MergedRoamHistoryRow(id: "l2", sessionID: nil, timestamp: 200, title: "本地2", distanceKM: 2.0, durationText: "20分", isLocalOnly: true)
        ]
        let remote = [
            MergedRoamHistoryRow(id: "r1", sessionID: "s1", timestamp: 100, title: "服务端1", distanceKM: 1.2, durationText: "10分", isLocalOnly: false)
        ]
        let merged = MergedRoamHistoryRow.merge(local: local, remote: remote)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first?.title, "本地2")
        XCTAssertEqual(merged.last?.title, "服务端1")
    }

    func testBadgeWallPendingCheckInScopeDateAndGoals() {
        let medals = [
            BadgeWallMedalItem(id: "1", title: "A", familyName: "F1", imageURL: nil, isUnlocked: true),
            BadgeWallMedalItem(id: "2", title: "B", familyName: "F1", imageURL: nil, isUnlocked: false, isIdentityPin: true)
        ]
        let split = BadgeWallGrouping.split(medals)
        XCTAssertEqual(split.unlocked.count, 1)
        XCTAssertEqual(split.locked.count, 1)
        XCTAssertTrue(split.locked[0].isIdentityPin)

        let pending = RoamPendingCheckInContext(poiID: 7, attemptID: "att-1", method: 3)
        XCTAssertEqual(pending.poiID, 7)

        let goalNoProg = ExplorationGoalProgressItem(id: 1, title: "走 5 站", progress: nil, target: 5)
        XCTAssertFalse(goalNoProg.showsProgressBar)

        let formatted = JourneyDateFormatterHelper.monthDayTime(Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(formatted.contains("月"))
        XCTAssertTrue(formatted.contains("日"))

        let pin = NearbyTeamMapPin(id: 1, teamName: "T", leaderName: "L", leaderAvatarURL: nil, memberCount: 2, capacity: 4, latitude: 31.2, longitude: 121.4)
        XCTAssertEqual(pin.capacity, 4)
    }

    @MainActor
    func testPlayRoamRound2ServicePaths() async {
        let transport = MPGapR2MockTransport()
        let service = PlayRoamRound2Service(baseURL: URL(string: "https://example.com")!, token: { "tok-1234" }, transport: transport)

        _ = await service.fetchCityStrip()
        _ = await service.fetchTeamApplications(teamID: 4)
        _ = await service.fetchLeaderboard(JourneyLeaderboardScopeQuery(scope: "team", scopeID: "4"))
        _ = await service.fetchStampAlbum(pageNum: 1)

        XCTAssertEqual(transport.requests.compactMap { $0.url?.path }, [
            "/api/roam/city-strip",
            "/api/team/applications",
            "/api/rank/list",
            "/api/roam/stamp/album"
        ])
        XCTAssertFalse(PlayRoamRound2Service.paths.contains("api/roam/history/list"))
    }

    // MARK: - Member Round-1 & Round-2 Types

    func testMemberModelsAndKeepOnRefreshBuffer() {
        let unit = FreeExploreBundleUnitItem(id: 1, chapterName: "第一章", statusText: "可用", validTo: "2026-12-31", canReserve: true)
        let exitCase = FreeExploreExitCaseItem(id: "e1", text: "已退款")
        let receipt = FreeExploreReceiptSummary(registrationNo: "R001", paymentText: "已支付", registrationText: "已确认", units: [unit], exitCases: [exitCase])
        XCTAssertEqual(receipt.units.count, 1)

        let lb = OrientScoreLeaderboardItem(id: "1", rank: 1, isMine: true, scoreText: "99", elapsedText: "20分")
        XCTAssertTrue(lb.isMine)
        XCTAssertEqual(OrientReviewSheetKind.appeal.title, "计分申诉")
        XCTAssertEqual(PassOrderActionKind.refundApply.title, "申请退款")
        XCTAssertEqual(ReportAppealSheetPhase.unknown, .unknown)

        var buffer = PagedKeepOnRefreshBuffer<String>(items: ["old1", "old2"], currentPage: 1, hasMore: true)
        buffer.applyRefreshFailure()
        XCTAssertEqual(buffer.items, ["old1", "old2"])
        XCTAssertEqual(buffer.lastRefreshError, "刷新失败，稍后再试")

        buffer.appendPage(["p2"], hasMore: false)
        XCTAssertEqual(buffer.items, ["old1", "old2", "p2"])
        XCTAssertEqual(buffer.currentPage, 2)

        buffer.applyRefreshSuccess(["new1"], hasMore: false)
        XCTAssertEqual(buffer.items, ["new1"])
        XCTAssertNil(buffer.lastRefreshError)

        let extra = OrderDetailExtraActionsModel(hasTeamSection: true, hasSeatsEntry: true, clubID: 5, clubName: "城瘾俱乐部")
        XCTAssertTrue(extra.hasSeatsEntry)

        let subline = TicketWalletCardSubline(typeLabel: "城市定向", daysLeftText: "剩 3 天", partyLabel: "1大1小")
        XCTAssertEqual(subline.combinedSubline, "城市定向 · 剩 3 天 · 1大1小")
    }

    @MainActor
    func testMemberRound2ServicePaths() async {
        let transport = MPGapR2MockTransport()
        let service = MemberRound2Service(baseURL: URL(string: "https://example.com")!, token: { "tok-1234" }, transport: transport)

        _ = await service.fetchOrdersPage(pageNum: 1)
        _ = await service.fetchPointsPage(pageNum: 2)
        _ = await service.fetchWithdrawalsPage(pageNum: 1)
        _ = await service.followClub(clubID: 10)
        _ = await service.joinClub(clubID: 10)
        _ = await service.fetchMyTemplates(scope: .merchant)
        _ = await service.fetchOrientScoring(sessionID: 99)

        XCTAssertEqual(transport.requests.compactMap { $0.url?.path }, [
            "/api/registration/my",
            "/api/points/list",
            "/api/withdrawal/list",
            "/api/club/follow",
            "/api/club/join",
            "/api/template/my/list",
            "/api/orient/scoring"
        ])
    }
}
