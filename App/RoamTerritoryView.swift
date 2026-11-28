import SwiftUI

/// Merged Roam + CITY territory screen. Functional wiring only using existing CY components;
/// owners earn in-game POINTS only, never money.
@MainActor struct SessionRoamTerritoryView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        let territoryService = session.makeRoamTerritoryService()
        let photoContext = session.makeRoamTerritoryPhotoContext()
        let cityGameService = session.makeUnifiedCityGameHTTPService()
        let growth = session.growthCenterReader
        let boardId = session.playCityGame?.snapshot?.boardId
        let center = session.roamReader.searchArea?.coordinate
        RoamTerritoryView(
            service: territoryService,
            cityGameService: cityGameService,
            boardId: boardId,
            initialCoordinate: center,
            photoContext: photoContext,
            captureFix: { try await RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true)) },
            monopolyService: session.makeCityMonopolyService(),
            monopolyPointsBalance: { (try? await growth.overview())?.center.value?.points.map { Int64($0) } }
        )
        .id(session.cityPlayerReadIdentity)
        .toolbar {
            // Design hand-off r1 PL-16: N01 is the CITY home. 收藏据点 is a row here, and the retired A10 page's tools
            // (snapshot, map updates, team participation, action budget) stay one tap away, never hidden.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        List { CityFavoriteNodesSection() }
                            .cyPageTitle("playerGap.cityFavorites.title")
                            .cyPushedChrome()
                    } label: {
                        Label("playerGap.cityFavorites.title", systemImage: "star")
                    }
                    .accessibilityIdentifier("city.home.favorites")
                    NavigationLink {
                        SessionCityPlayerView().cyPushedChrome()
                    } label: {
                        Label("city.read.title", systemImage: "building.2")
                    }
                    .accessibilityIdentifier("city.home.tools")
                } label: {
                    Label("homeFeed.more", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("city.home.more")
            }
        }
    }
}

@MainActor struct RoamTerritoryView: View {
    enum Tab: Int, CaseIterable {
        case nearby = 0
        case mine = 1
        case leaderboard = 2
    }

    let service: RoamTerritoryService?
    var cityGameService: CityGameHTTPService? = nil
    var boardId: String? = nil
    var initialCoordinate: RoamCoordinate? = nil
    var photoContext: RetainedImageSelectionContext? = nil
    var captureFix: (@MainActor () async throws -> RoamDeviceFix)? = nil
    /// City Monopoly numbers (tiers, upgrades, rent, caps, protection, challenge, decay, season); points only.
    var monopolyService: (any CityMonopolyReading)? = nil
    /// The member's points balance (growth center); the one currency on City screens.
    var monopolyPointsBalance: (@MainActor () async -> Int64?)? = nil

    @Environment(\.locale) private var locale
    @State private var selectedTab: Tab

    init(
        service: RoamTerritoryService?,
        cityGameService: CityGameHTTPService? = nil,
        boardId: String? = nil,
        initialCoordinate: RoamCoordinate? = nil,
        photoContext: RetainedImageSelectionContext? = nil,
        captureFix: (@MainActor () async throws -> RoamDeviceFix)? = nil,
        monopolyService: (any CityMonopolyReading)? = nil,
        monopolyPointsBalance: (@MainActor () async -> Int64?)? = nil,
        initialTab: Tab = .nearby
    ) {
        self.service = service
        self.cityGameService = cityGameService
        self.boardId = boardId
        self.initialCoordinate = initialCoordinate
        self.photoContext = photoContext
        self.captureFix = captureFix
        self.monopolyService = monopolyService
        self.monopolyPointsBalance = monopolyPointsBalance
        self._selectedTab = State(initialValue: initialTab)
    }
    @State private var loading = false
    @State private var busyAction = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var nearby: RoamTerritoryNearbyResponse?
    @State private var myRows: [RoamTerritoryRow] = []
    @State private var leaderboard: RoamTerritoryLeaderboardResponse?
    @State private var auditReport: CityDiceAuditReport?
    @State private var lastRollReceipt: CityUnifiedDiceRollReceipt?
    @State private var claimingItem: RoamTerritoryItem?
    @State private var uploadedPhotoURL: String?
    @State private var monopolyFocusID: String?
    @State private var monopolyReload = 0

    private func copy(_ zh: String, _ en: String) -> String {
        ChannelCopy.text(zh, en, locale: locale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader(
                    verbatim: copy("漫游领地与棋盘", "Roam Territory & Board"),
                    subtitle: copy("实景格子以带定位照片占领，访客打卡仅结算游戏积分。", "Claim board spaces with a geotagged photo; visitor check-ins settle in-game points only.")
                )

                if service == nil {
                    CYStateLayout(
                        kind: .empty,
                        title: Text(verbatim: copy("领地功能未开启", "Territory unavailable")),
                        detail: Text(verbatim: copy("请先登录并在已开放的城市区域中打开。", "Sign in inside an open CITY region to use merged territory.")),
                        primaryVerbatim: nil
                    )
                    .accessibilityIdentifier("roamTerritory.unavailable")
                } else {
                    tabBar
                    if let statusMessage {
                        CYNoteBanner(text: Text(verbatim: statusMessage), symbol: "checkmark.seal", tone: .success)
                            .accessibilityIdentifier("roamTerritory.status")
                    }
                    if let errorMessage {
                        CYNoteBanner(text: Text(verbatim: errorMessage), symbol: "exclamationmark.triangle", tone: .warning)
                            .accessibilityIdentifier("roamTerritory.error")
                    }
                    if loading {
                        CYSkeleton(label: LocalizedStringKey(copy("正在加载领地信息", "Loading territory data")))
                            .accessibilityIdentifier("roamTerritory.loading")
                    }
                    if let monopolyService {
                        CityMonopolyTerritorySection(service: monopolyService, items: nearby?.items ?? [],
                                                     focusedItemID: $monopolyFocusID, reloadSignal: monopolyReload,
                                                     captureFix: captureFix, pointsBalance: monopolyPointsBalance)
                    }
                    if let item = claimingItem {
                        claimSheetCard(item)
                    }
                    contentSection
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
        .task { await reloadAll() }
    }

    /// native-r3-b: the MP three-tab switcher as a system segmented picker (was three pill buttons).
    private var tabBar: some View {
        Picker(selection: $selectedTab) {
            Text(verbatim: copy("附近格子", "Nearby")).tag(Tab.nearby)
            Text(verbatim: copy("我的领地", "Mine")).tag(Tab.mine)
            Text(verbatim: copy("赛季排行", "Leaderboard")).tag(Tab.leaderboard)
        } label: {
            Text(verbatim: copy("领地", "Territory"))
        }
        .cyAdaptiveSegmented()
        .onChange(of: selectedTab) { _, _ in Task { await reloadAll() } }
        .accessibilityIdentifier("roamTerritory.tabs")
    }

    @ViewBuilder private var contentSection: some View {
        switch selectedTab {
        case .nearby:
            nearbySection
        case .mine:
            myTerritoriesSection
        case .leaderboard:
            leaderboardSection
        }
    }

    @ViewBuilder private var nearbySection: some View {
        HStack(spacing: CYSpacing.sm) {
            CYPillButton(verbatim: copy("刷新附近", "Refresh nearby"), style: .secondary, systemImage: "arrow.clockwise", fullWidth: false) {
                Task { await loadNearby(useGPS: false) }
            }
            .disabled(loading || busyAction)
            .accessibilityLabel(Text(verbatim: copy("刷新附近格子", "Refresh nearby spaces")))
            .accessibilityIdentifier("roamTerritory.nearby.refresh")
            if captureFix != nil {
                CYPillButton(verbatim: copy("用当前位置加载", "Use GPS"), style: .tertiary, systemImage: "location", fullWidth: false) {
                    Task { await loadNearby(useGPS: true) }
                }
                .disabled(loading || busyAction)
                .accessibilityLabel(Text(verbatim: copy("用当前位置加载附近格子", "Load nearby spaces with GPS")))
                .accessibilityIdentifier("roamTerritory.nearby.gps")
            }
        }

        if let items = nearby?.items, !items.isEmpty {
            ForEach(items) { item in
                let resolvedOwner = item.ownerNickname ?? item.ownerMemberId.map { "#\($0)" }
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: item.title ?? item.pointId ?? item.id)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    HStack(spacing: CYSpacing.sm) {
                        CYStatusChip(verbatim: item.status, tone: item.isProtected ? .warning : (item.claimed ? .info : .success))
                        if let track = item.trackIndex {
                            CYStatusChip(verbatim: copy("格 #\(track)", "Tile #\(track)"), tone: .neutral)
                        }
                        if let dist = item.distanceM {
                            CYStatusChip(verbatim: "\(Int(dist))m", tone: .neutral)
                        }
                        if let tier = item.tier {
                            CYStatusChip(verbatim: tier.code + " " + tier.name(chinese: ChannelCopy.isChinese(locale)), tone: .info)
                        }
                        if let level = item.upgradeLevel {
                            CYStatusChip(verbatim: "Lv\(level) " + CityMonopolyLevel.name(level, chinese: ChannelCopy.isChinese(locale)), tone: .neutral)
                        }
                        if let decay = CityDecayState(wire: item.decayState), decay != .ok {
                            CYStatusChip(verbatim: decay.label(chinese: ChannelCopy.isChinese(locale)), tone: .warning)
                        }
                    }
                    CYFactRow(label: Text(verbatim: copy("地主", "Owner")), value: resolvedOwner ?? "—")
                        .accessibilityLabel(Text(verbatim: copy("地主 \(resolvedOwner ?? copy("未知", "Unknown"))", "Owner \(resolvedOwner ?? copy("Unknown", "Unknown"))")))
                    CYFactRow(label: Text(verbatim: copy("打卡积分收益", "Check-in revenue (pts)")), value: "\(item.ownerRevenuePoints) pts")
                    CYFactRow(label: Text(verbatim: copy("访客过路积分", "Visitor toll (pts)")), value: "\(item.checkinTollPoints) pts")
                    HStack(spacing: CYSpacing.sm) {
                        CYPillButton(verbatim: copy("照片占领", "Claim (Photo)"), style: .primary, fullWidth: false) {
                            claimingItem = item
                            uploadedPhotoURL = nil
                            errorMessage = nil
                        }
                        .disabled(busyAction || item.isProtected || photoContext == nil || captureFix == nil)
                        .accessibilityLabel(Text(verbatim: copy("照片占领 \(item.title ?? item.pointId ?? item.id)", "Claim \(item.title ?? item.pointId ?? item.id) with photo")))
                        .accessibilityIdentifier("roamTerritory.claim.\(item.id)")

                        if item.claimed {
                            CYPillButton(verbatim: copy("打卡 (+积分)", "Check in"), style: .secondary, fullWidth: false) {
                                Task { await submitCheckin(item) }
                            }
                            .disabled(busyAction || captureFix == nil)
                            .accessibilityLabel(Text(verbatim: copy("打卡 \(item.title ?? item.pointId ?? item.id)", "Check in at \(item.title ?? item.pointId ?? item.id)")))
                            .accessibilityIdentifier("roamTerritory.checkin.\(item.id)")
                        }
                        if monopolyService != nil, item.propertyId != nil {
                            CYPillButton(verbatim: copy("地产卡", "Deed card"), style: .tertiary, fullWidth: false) {
                                monopolyFocusID = monopolyFocusID == item.id ? nil : item.id
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                .accessibilityIdentifier("roamTerritory.nearby.card.\(item.id)")
            }
        } else if !loading {
            CYEmptyState(systemImage: "map", LocalizedStringKey(copy("附近暂无已映射棋盘格子", "No mapped board spaces nearby")))
                .accessibilityIdentifier("roamTerritory.nearby.empty")
        }
    }

    @ViewBuilder private var myTerritoriesSection: some View {
        if myRows.isEmpty, !loading {
            CYEmptyState(systemImage: "flag", LocalizedStringKey(copy("暂未占领领地", "No claimed territories yet")))
                .accessibilityIdentifier("roamTerritory.mine.empty")
        } else {
            ForEach(myRows) { row in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: row.title ?? row.pointId ?? row.territoryId)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    CYFactRow(label: Text(verbatim: copy("状态", "Status")), value: row.status ?? "—")
                        .accessibilityLabel(Text(verbatim: copy("状态 \(row.status ?? copy("未知", "Unknown"))", "Status \(row.status ?? "Unknown")")))
                    CYFactRow(label: Text(verbatim: copy("累计积分收益", "Total revenue (pts)")), value: "\(row.revenueTotalPoints ?? 0) pts")
                    CYFactRow(label: Text(verbatim: copy("打卡次数", "Check-ins")), value: "\(row.checkinCount ?? 0)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                .accessibilityIdentifier("roamTerritory.mine.card.\(row.territoryId)")
            }
        }
    }

    @ViewBuilder private var leaderboardSection: some View {
        if let board = leaderboard, !board.leaders.isEmpty {
            CYSectionHeader(LocalizedStringKey(copy("赛季积分地主榜", "Season Points Leaders")))
            ForEach(board.leaders) { leader in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: leader.ownerNickname ?? "#\(leader.ownerMemberId)")
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    CYFactRow(label: Text(verbatim: copy("领地数", "Territories")), value: "\(leader.territoryCount)")
                    CYFactRow(label: Text(verbatim: copy("打卡人次", "Check-ins")), value: "\(leader.totalCheckins)")
                    CYFactRow(label: Text(verbatim: copy("积分总收益", "Total points")), value: "\(leader.totalRevenuePoints) pts")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                .accessibilityIdentifier("roamTerritory.leaderboard.card.\(leader.ownerMemberId)")
            }
        } else if !loading {
            CYEmptyState(systemImage: "trophy", LocalizedStringKey(copy("暂无赛季排行数据", "No leaderboard entries yet")))
                .accessibilityIdentifier("roamTerritory.leaderboard.empty")
        }

        if let cityGameService, let resolvedBoardId = boardId ?? nearby?.boardId ?? leaderboard?.boardId {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYSectionHeader(LocalizedStringKey(copy("统一骰子与审计", "Unified Dice & Audit")))
                HStack(spacing: CYSpacing.sm) {
                    CYPillButton(verbatim: copy("统一掷骰", "Unified Roll"), style: .primary, systemImage: "dice", fullWidth: false) {
                        Task { await rollUnifiedDice(service: cityGameService, boardId: resolvedBoardId) }
                    }
                    .disabled(busyAction)
                    .accessibilityLabel(Text(verbatim: copy("统一掷骰", "Unified Roll")))
                    .accessibilityIdentifier("roamTerritory.dice.roll")
                    CYPillButton(verbatim: copy("读取审计", "Load Audit"), style: .secondary, fullWidth: false) {
                        Task { await loadDiceAudit(service: cityGameService, boardId: resolvedBoardId) }
                    }
                    .disabled(busyAction)
                    .accessibilityLabel(Text(verbatim: copy("读取骰子审计记录", "Load dice audit")))
                    .accessibilityIdentifier("roamTerritory.dice.audit")
                }
                if let receipt = lastRollReceipt {
                    CYNoteBanner(
                        text: Text(verbatim: copy(
                            "点数 \(receipt.faceValue ?? receipt.diceFace ?? 0)，位置 \(receipt.previousPosition ?? 0) → \(receipt.newPosition ?? 0)",
                            "Rolled \(receipt.faceValue ?? receipt.diceFace ?? 0), tile \(receipt.previousPosition ?? 0) -> \(receipt.newPosition ?? 0)"
                        )),
                        symbol: "dice",
                        tone: .success
                    )
                    .accessibilityIdentifier("roamTerritory.dice.receipt")
                }
                if let audit = auditReport {
                    ForEach(audit.rolls.prefix(10)) { row in
                        CYFactRow(
                            label: Text(verbatim: row.sourcePath ?? "UNIFIED_ROLL"),
                            value: copy(
                                "点\(row.faceValue ?? 0) · 位置\(row.previousPosition ?? 0)->\(row.newPosition ?? 0)",
                                "face \(row.faceValue ?? 0) · pos \(row.previousPosition ?? 0)->\(row.newPosition ?? 0)"
                            )
                        )
                        .accessibilityIdentifier("roamTerritory.dice.auditRow.\(row.id)")
                    }
                }
            }
            .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
        }
    }

    @ViewBuilder private func claimSheetCard(_ item: RoamTerritoryItem) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYSectionHeader(LocalizedStringKey(copy("实景占领证明", "Photo + GPS Claim")))
            Text(verbatim: item.title ?? item.pointId ?? item.id)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            if let photoContext {
                RetainedImageSelectionView(context: photoContext) { uploaded in
                    uploadedPhotoURL = uploaded.url.absoluteString
                    return true
                }
            }
            if let url = uploadedPhotoURL {
                CYStatusChip(verbatim: copy("照片已上传", "Photo ready") + ": " + String(url.suffix(24)), tone: .success)
            }
            HStack(spacing: CYSpacing.sm) {
                CYPillButton(verbatim: copy("确认 GPS 占领", "Confirm Claim"), style: .primary, fullWidth: false) {
                    Task { await submitClaim(item) }
                }
                .disabled(busyAction || uploadedPhotoURL == nil || captureFix == nil)
                .accessibilityLabel(Text(verbatim: copy("确认 GPS 占领", "Confirm Claim")))
                .accessibilityIdentifier("roamTerritory.claimSheet.confirm")
                CYPillButton(verbatim: copy("取消", "Cancel"), style: .tertiary, fullWidth: false) {
                    claimingItem = nil
                    uploadedPhotoURL = nil
                }
                .accessibilityLabel(Text(verbatim: copy("取消占领", "Cancel claim")))
                .accessibilityIdentifier("roamTerritory.claimSheet.cancel")
            }
        }
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
        .accessibilityIdentifier("roamTerritory.claimSheet")
    }

    private func reloadAll() async {
        guard service != nil else { return }
        await loadNearby(useGPS: false)
        await loadMineAndLeaderboard()
        monopolyReload += 1
    }

    private func loadNearby(useGPS: Bool) async {
        guard let service else { return }
        loading = true; errorMessage = nil
        defer { loading = false }
        do {
            let coord: RoamCoordinate
            if useGPS, let captureFix {
                coord = try await captureFix().coordinate
            } else if let initialCoordinate {
                coord = initialCoordinate
            } else if let captureFix {
                coord = try await captureFix().coordinate
            } else {
                return
            }
            nearby = try await service.nearby(lat: coord.latitude, lng: coord.longitude, radius: 5000, boardId: boardId)
        } catch {
            errorMessage = describeError(error)
        }
    }

    private func loadMineAndLeaderboard() async {
        guard let service else { return }
        do {
            async let mine = service.myTerritories()
            async let board = service.leaderboard(boardId: boardId, limit: 20)
            myRows = try await mine
            leaderboard = try await board
        } catch {
            if errorMessage == nil { errorMessage = describeError(error) }
        }
    }

    private func submitClaim(_ item: RoamTerritoryItem) async {
        guard let service, let captureFix, let photoUrl = uploadedPhotoURL else { return }
        busyAction = true; errorMessage = nil; statusMessage = nil
        defer { busyAction = false }
        do {
            let fix = try await captureFix()
            let request = RoamTerritoryClaimRequest(
                lat: fix.coordinate.latitude,
                lng: fix.coordinate.longitude,
                accuracyM: fix.accuracyMeters,
                photoUrl: photoUrl,
                poiId: item.poiId,
                boardId: item.boardId ?? boardId,
                propertyId: item.propertyId,
                pointId: item.pointId,
                title: item.title
            )
            let receipt = try await service.claim(request)
            claimingItem = nil
            uploadedPhotoURL = nil
            statusMessage = copy("占领成功，保护期 \(receipt.protectionSeconds ?? 0) 秒", "Claimed with \(receipt.protectionSeconds ?? 0)s protection")
            await reloadAll()
        } catch {
            errorMessage = describeError(error)
        }
    }

    private func submitCheckin(_ item: RoamTerritoryItem) async {
        guard let service, let captureFix else { return }
        busyAction = true; errorMessage = nil; statusMessage = nil
        defer { busyAction = false }
        do {
            let fix = try await captureFix()
            let request = RoamTerritoryCheckinRequest(
                territoryId: item.territoryId,
                poiId: item.poiId,
                lat: fix.coordinate.latitude,
                lng: fix.coordinate.longitude,
                accuracyM: fix.accuracyMeters
            )
            let receipt = try await service.checkin(request)
            statusMessage = copy(
                "打卡完成：地主获得 \(receipt.territory?.yieldPoints ?? receipt.ownerRevenuePoints) 积分",
                "Checked in: owner earned \(receipt.territory?.yieldPoints ?? receipt.ownerRevenuePoints) points"
            ) + checkinRentNote(receipt.territory)
            await reloadAll()
        } catch {
            errorMessage = describeError(error)
        }
    }

    /// Visitor reward and the reason no rent was produced (CITY-MONOPOLY-SPEC §2.4, §2.11).
    private func checkinRentNote(_ visit: CityTerritoryVisitYield?) -> String {
        guard let visit else { return "" }
        var note = ""
        if let reward = visit.visitorPoints, reward > 0 {
            note += copy("；你获得 \(reward) 积分", "; you earned \(reward) points")
        }
        if let reason = visit.ineligibleReason ?? visit.capReason {
            note += copy("（未产租/封顶：\(reason)）", " (no rent / capped: \(reason))")
        }
        return note
    }

    private func rollUnifiedDice(service: CityGameHTTPService, boardId: String) async {
        busyAction = true; errorMessage = nil; statusMessage = nil
        defer { busyAction = false }
        do {
            let receipt = try await service.rollUnifiedDice(boardId: boardId)
            lastRollReceipt = receipt
            auditReport = try await service.diceAudit(boardId: boardId, limit: 20)
        } catch {
            errorMessage = describeError(error)
        }
    }

    private func loadDiceAudit(service: CityGameHTTPService, boardId: String) async {
        busyAction = true; errorMessage = nil
        defer { busyAction = false }
        do {
            auditReport = try await service.diceAudit(boardId: boardId, limit: 20)
        } catch {
            errorMessage = describeError(error)
        }
    }

    private func describeError(_ error: Error) -> String {
        switch error {
        case RoamTerritoryError.rejected(_, let code, let message):
            return message?.isEmpty == false ? "\(code): \(message!)" : code
        case CityGameServiceError.rejected(_, let code):
            return code
        default:
            return error.localizedDescription
        }
    }
}
