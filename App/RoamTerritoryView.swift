import SwiftUI

/// Merged Roam + CITY territory screen. Functional wiring only using existing CY components;
/// owners earn in-game POINTS only, never money.
@MainActor struct SessionRoamTerritoryView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        let territoryService = session.makeRoamTerritoryService()
        let photoContext = session.makeRoamTerritoryPhotoContext()
        let cityGameService = session.makeUnifiedCityGameHTTPService()
        let boardId = session.playCityGame?.snapshot?.boardId
        let center = session.roamReader.searchArea?.coordinate
        RoamTerritoryView(
            service: territoryService,
            cityGameService: cityGameService,
            boardId: boardId,
            initialCoordinate: center,
            photoContext: photoContext,
            captureFix: { try await RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true)) }
        )
        .id(session.cityPlayerReadIdentity)
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

    @Environment(\.locale) private var locale
    @State private var selectedTab: Tab = .nearby
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
                } else {
                    tabBar
                    if let statusMessage {
                        CYNoteBanner(text: Text(verbatim: statusMessage), symbol: "checkmark.seal", tone: .success)
                    }
                    if let errorMessage {
                        CYNoteBanner(text: Text(verbatim: errorMessage), symbol: "exclamationmark.triangle", tone: .warning)
                    }
                    if loading {
                        CYSkeleton()
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

    private var tabBar: some View {
        HStack(spacing: CYSpacing.sm) {
            CYPillButton(verbatim: copy("附近格子", "Nearby"), style: selectedTab == .nearby ? .primary : .secondary, fullWidth: false) {
                selectedTab = .nearby
                Task { await reloadAll() }
            }
            CYPillButton(verbatim: copy("我的领地", "Mine"), style: selectedTab == .mine ? .primary : .secondary, fullWidth: false) {
                selectedTab = .mine
                Task { await reloadAll() }
            }
            CYPillButton(verbatim: copy("赛季排行", "Leaderboard"), style: selectedTab == .leaderboard ? .primary : .secondary, fullWidth: false) {
                selectedTab = .leaderboard
                Task { await reloadAll() }
            }
        }
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
            CYPillButton(verbatim: copy("刷新附近", "Refresh nearby"), style: .secondary, fullWidth: false, systemImage: "arrow.clockwise") {
                Task { await loadNearby(useGPS: false) }
            }
            .disabled(loading || busyAction)
            if captureFix != nil {
                CYPillButton(verbatim: copy("用当前位置加载", "Use GPS"), style: .tertiary, fullWidth: false, systemImage: "location") {
                    Task { await loadNearby(useGPS: true) }
                }
                .disabled(loading || busyAction)
            }
        }

        if let items = nearby?.items, !items.isEmpty {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: item.title ?? item.pointId ?? item.id)
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    HStack(spacing: CYSpacing.sm) {
                        CYStatusChip(verbatim: item.status, tone: item.isProtected ? .warning : (item.claimed ? .info : .success))
                        if let track = item.trackIndex {
                            CYStatusChip(verbatim: copy("格 #\(track)", "Tile #\(track)"), tone: .neutral)
                        }
                        if let dist = item.distanceM {
                            CYStatusChip(verbatim: "\(Int(dist))m", tone: .neutral)
                        }
                    }
                    CYFactRow(label: Text(verbatim: copy("地主", "Owner")), value: item.ownerNickname ?? (item.ownerMemberId.map { "#\($0)" } ?? "—"))
                    CYFactRow(label: Text(verbatim: copy("打卡积分收益", "Check-in revenue (pts)")), value: "\(item.ownerRevenuePoints) pts")
                    CYFactRow(label: Text(verbatim: copy("访客过路积分", "Visitor toll (pts)")), value: "\(item.checkinTollPoints) pts")
                    HStack(spacing: CYSpacing.sm) {
                        CYPillButton(verbatim: copy("照片占领", "Claim (Photo)"), style: .primary, fullWidth: false) {
                            claimingItem = item
                            uploadedPhotoURL = nil
                            errorMessage = nil
                        }
                        .disabled(busyAction || item.isProtected || photoContext == nil || captureFix == nil)

                        if item.claimed {
                            CYPillButton(verbatim: copy("打卡 (+积分)", "Check in"), style: .secondary, fullWidth: false) {
                                Task { await submitCheckin(item) }
                            }
                            .disabled(busyAction || captureFix == nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
            }
        } else if !loading {
            CYEmptyState(systemImage: "map", LocalizedStringKey(copy("附近暂无已映射棋盘格子", "No mapped board spaces nearby")))
        }
    }

    @ViewBuilder private var myTerritoriesSection: some View {
        if myRows.isEmpty, !loading {
            CYEmptyState(systemImage: "flag", LocalizedStringKey(copy("暂未占领领地", "No claimed territories yet")))
        } else {
            ForEach(myRows) { row in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: row.title ?? row.pointId ?? row.territoryId)
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    CYFactRow(label: Text(verbatim: copy("状态", "Status")), value: row.status ?? "—")
                    CYFactRow(label: Text(verbatim: copy("累计积分收益", "Total revenue (pts)")), value: "\(row.revenueTotalPoints ?? 0) pts")
                    CYFactRow(label: Text(verbatim: copy("打卡次数", "Check-ins")), value: "\(row.checkinCount ?? 0)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
            }
        }
    }

    @ViewBuilder private var leaderboardSection: some View {
        if let board = leaderboard, !board.leaders.isEmpty {
            CYSectionHeader(LocalizedStringKey(copy("赛季积分地主榜", "Season Points Leaders")))
            ForEach(board.leaders) { leader in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: leader.ownerNickname ?? "#\(leader.ownerMemberId)")
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    CYFactRow(label: Text(verbatim: copy("领地数", "Territories")), value: "\(leader.territoryCount)")
                    CYFactRow(label: Text(verbatim: copy("打卡人次", "Check-ins")), value: "\(leader.totalCheckins)")
                    CYFactRow(label: Text(verbatim: copy("积分总收益", "Total points")), value: "\(leader.totalRevenuePoints) pts")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
            }
        } else if !loading {
            CYEmptyState(systemImage: "trophy", LocalizedStringKey(copy("暂无赛季排行数据", "No leaderboard entries yet")))
        }

        if let cityGameService, let resolvedBoardId = boardId ?? nearby?.boardId ?? leaderboard?.boardId {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYSectionHeader(LocalizedStringKey(copy("统一骰子与审计", "Unified Dice & Audit")))
                HStack(spacing: CYSpacing.sm) {
                    CYPillButton(verbatim: copy("统一掷骰", "Unified Roll"), style: .primary, fullWidth: false, systemImage: "dice") {
                        Task { await rollUnifiedDice(service: cityGameService, boardId: resolvedBoardId) }
                    }
                    .disabled(busyAction)
                    CYPillButton(verbatim: copy("读取审计", "Load Audit"), style: .secondary, fullWidth: false) {
                        Task { await loadDiceAudit(service: cityGameService, boardId: resolvedBoardId) }
                    }
                    .disabled(busyAction)
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
                .font(CYTypography.cardTitle)
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
                CYPillButton(verbatim: copy("取消", "Cancel"), style: .tertiary, fullWidth: false) {
                    claimingItem = nil
                    uploadedPhotoURL = nil
                }
            }
        }
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
    }

    private func reloadAll() async {
        guard service != nil else { return }
        await loadNearby(useGPS: false)
        await loadMineAndLeaderboard()
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
                "打卡完成：地主获得 \(receipt.ownerRevenuePoints) 游戏积分",
                "Checked in: owner earned \(receipt.ownerRevenuePoints) points"
            )
            await reloadAll()
        } catch {
            errorMessage = describeError(error)
        }
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
