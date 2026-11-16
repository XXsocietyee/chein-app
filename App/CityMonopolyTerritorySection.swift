import SwiftUI

/// City Monopoly numbers on the merged territory screen (CITY-MONOPOLY-SPEC §2, §3.6 HUD, §5 haptics).
/// Functional wiring only with existing CY components; layout and styling come later.
/// One currency: every amount is member points (积分).
@MainActor struct CityMonopolyTerritorySection: View {
    let items: [RoamTerritoryItem]
    @Binding var focusedItemID: String?
    var reloadSignal: Int = 0
    var captureFix: (@MainActor () async throws -> RoamDeviceFix)? = nil

    @StateObject private var model: CityMonopolyTerritoryModel
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var fixes: [RoamDeviceFix] = []
    @State private var samplingTask: Task<Void, Never>?
    @State private var showsRevenue = false
    @State private var showsSeasonBoard = false
    /// Design hand-off r1 PL-13 (N51): the property whose 地盘已释放 sheet is showing.
    @State private var releasedPropertyID: String?

    init(service: any CityMonopolyReading, items: [RoamTerritoryItem], focusedItemID: Binding<String?>,
         reloadSignal: Int = 0, captureFix: (@MainActor () async throws -> RoamDeviceFix)? = nil,
         pointsBalance: (@MainActor () async -> Int64?)? = nil) {
        _model = StateObject(wrappedValue: CityMonopolyTerritoryModel(service: service, pointsSource: pointsBalance))
        self.items = items
        _focusedItemID = focusedItemID
        self.reloadSignal = reloadSignal
        self.captureFix = captureFix
    }

    private var chinese: Bool { ChannelCopy.isChinese(locale) }
    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }
    private func points(_ value: Int64) -> String { CityMonopolyFormat.points(value, chinese: chinese) }

    private var focusedItem: RoamTerritoryItem? {
        guard let focusedItemID else { return nil }
        return items.first { $0.id == focusedItemID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            hud
            if let issue = model.issueCode {
                CYNoteBanner(text: Text(verbatim: copy("城市大富翁：", "City Monopoly: ") + issue), symbol: "exclamationmark.triangle", tone: .warning)
            }
            if let result = model.lastResult {
                resultBanner(result)
            }
            if let item = focusedItem {
                propertyCard(item)
            }
            if let pending = model.pendingQuote {
                quoteCard(pending)
            }
            HStack(spacing: CYSpacing.sm) {
                CYPillButton(verbatim: copy("收租明细", "Rent ledger"), style: .secondary, systemImage: "list.bullet.rectangle", fullWidth: false) {
                    showsRevenue.toggle()
                    if showsRevenue { Task { await model.loadRevenue() } }
                }
                CYPillButton(verbatim: copy("赛季榜", "Season board"), style: .tertiary, systemImage: "trophy", fullWidth: false) {
                    showsSeasonBoard.toggle()
                    if showsSeasonBoard { Task { await model.loadSeasonBoard() } }
                }
            }
            if showsRevenue { revenueSection }
            if showsSeasonBoard { seasonBoardSection }
        }
        .task { await model.reload() }
        .onChange(of: reloadSignal) { _, _ in Task { await model.reload() } }
        .onChange(of: focusedItemID) { _, newValue in
            model.cancelQuote()
            model.closeCard()
            fixes = []
            if let id = newValue, let propertyId = items.first(where: { $0.id == id })?.propertyId {
                Task { await model.openCard(propertyId: propertyId) }
            }
        }
        .onDisappear { samplingTask?.cancel() }
        .cityMonopolyHaptics(model.haptic, reduceMotion: reduceMotion)
        .onChange(of: model.card?.decay) { _, decay in
            // The opened deed has been released: say so in a fit sheet with the place and one way back in.
            if decay == .released, let id = model.card?.propertyId { releasedPropertyID = id }
        }
        .cyResizableSheet(
            isPresented: Binding(get: { releasedPropertyID != nil }, set: { if !$0 { releasedPropertyID = nil } }),
            kind: .released,
            title: Text("released.title", tableName: "DesignR1"),
            primary: CYSheetPrimary("released.reclaim", tableName: "DesignR1", isEnabled: !model.busy) {
                guard let propertyId = releasedPropertyID else { return }
                releasedPropertyID = nil
                Task { await quote(.claim, propertyId: propertyId) }
            }
        ) {
            releasedSheetBody
        }
    }

    /// N51 as a sheet: the place card with its 可圈 tag, one line on why, and 完成 as the text action.
    @ViewBuilder private var releasedSheetBody: some View {
        let item = items.first { $0.propertyId == releasedPropertyID }
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: CYUnknownValue.string(model.card?.title ?? item?.title))
                    .font(.headline)
                    .foregroundStyle(CYColor.textPrimary)
                CYStatusTag("released.claimable", state: .neutral, tableName: "DesignR1")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
            Text("released.body", tableName: "DesignR1")
                .font(.subheadline)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            CYPillButton("sheet.done", style: .tertiary, tableName: "DesignR1") { releasedPropertyID = nil }
                .accessibilityIdentifier("city.released.done")
        }
        .accessibilityIdentifier("city.released.sheet")
    }

    // MARK: HUD (§3.6: points balance with pending, holdings / limit, season countdown)

    private var hud: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYSectionHeader(LocalizedStringKey(copy("城市大富翁", "City Monopoly")))
            if let balance = model.pointsBalance {
                CYFactRow(label: Text(verbatim: copy("积分余额", "Points balance")), value: points(balance))
            }
            if let pending = model.revenue?.todayPending, pending > 0 {
                CYFactRow(label: Text(verbatim: copy("今日租金待入账（03:00 风控后可用）", "Today's rent pending (usable after 03:00 review)")), value: points(pending))
            }
            if let available = model.revenue?.todayAvailable {
                CYFactRow(label: Text(verbatim: copy("今日租金已入账", "Today's rent settled")), value: points(available))
            }
            let holdings = model.holdings()
            CYFactRow(label: Text(verbatim: copy("持有 / 上限", "Held / limit")), value: "\(holdings.count) / \(holdings.limit)")
            if let season = model.season {
                CYFactRow(label: Text(verbatim: copy("赛季", "Season")), value: season.seasonId + (season.seasonPhase.map { " · " + $0.label(chinese: chinese) } ?? ""))
                if let ends = season.freezesAt ?? season.endsAt {
                    CYFactRow(label: Text(verbatim: copy("赛季剩余", "Season ends in")),
                              value: CityMonopolyFormat.countdown(seconds: ends.secondsRemaining(now: Date()), chinese: chinese))
                }
                if let score = season.myScore {
                    CYFactRow(label: Text(verbatim: copy("我的赛季分 / 排名", "My season score / rank")),
                              value: "\(Int(score.rounded()))" + (season.myRank.map { " · #\($0)" } ?? ""))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
    }

    // MARK: Deed card (tier, level, rent, protection, decay, DC)

    @ViewBuilder private func propertyCard(_ item: RoamTerritoryItem) -> some View {
        let property = model.property(id: item.propertyId)
        let card = model.card?.propertyId == item.propertyId ? model.card : nil
        let tier = card?.tier ?? property?.tier ?? item.tier
        let level = card?.lvl ?? property?.lvl ?? item.upgradeLevel ?? 0
        let decay = card?.decay ?? property?.decay ?? CityDecayState(wire: item.decayState)
        let isMine = card?.holder?.isMe ?? property?.isMine ?? false
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYSectionHeader(LocalizedStringKey(copy("地产卡", "Deed card")))
            Text(verbatim: card?.title ?? item.title ?? item.id)
                .font(CYTypography.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            HStack(spacing: CYSpacing.sm) {
                if let tier {
                    CYStatusChip(verbatim: tier.code + " " + tier.name(chinese: chinese), tone: .info)
                }
                CYStatusChip(verbatim: "Lv\(level) " + CityMonopolyLevel.name(level, chinese: chinese), tone: .neutral)
                if let decay, decay != .ok {
                    CYStatusChip(verbatim: decay.label(chinese: chinese), tone: .warning)
                }
            }
            if let tier {
                CYFactRow(label: Text(verbatim: copy("占领价", "Claim price")), value: points(tier.claimCost))
                CYFactRow(label: Text(verbatim: copy("累计投入", "Invested")),
                          value: points(card?.invested ?? CityMonopolyRules.invested(tier: tier, level: level)))
                CYFactRow(label: Text(verbatim: copy("每次到访租金（基础）", "Rent per visit (base)")),
                          value: points(card?.estimatedYield ?? CityMonopolyRules.rent(tier: tier, level: level, weathered: decay == .weathered)))
                if let next = CityMonopolyRules.upgradeCost(tier: tier, fromLevel: level) {
                    CYFactRow(label: Text(verbatim: copy("升到 Lv\(level + 1)", "Upgrade to Lv\(level + 1)")), value: points(next))
                }
                CYFactRow(label: Text(verbatim: copy("挑战费", "Challenge fee")),
                          value: points(CityMonopolyRules.challengeFee(invested: card?.invested ?? CityMonopolyRules.invested(tier: tier, level: level),
                                                                       finale: model.season?.seasonPhase == .finale)))
            }
            if let holder = card?.holder ?? property?.holder {
                CYFactRow(label: Text(verbatim: copy("持有人", "Holder")),
                          value: [holder.maskedName, holder.archetype?.display(chinese: chinese), holder.title?.display(chinese: chinese)]
                            .compactMap { $0 }.joined(separator: " · "))
            }
            if let until = card?.protectedUntil ?? property?.protectedUntil, until.secondsRemaining(now: Date()) > 0 {
                CYFactRow(label: Text(verbatim: copy("保护剩余", "Protected for")),
                          value: CityMonopolyFormat.countdown(seconds: until.secondsRemaining(now: Date()), chinese: chinese))
            }
            if let visits = card?.weeklyVisits {
                CYFactRow(label: Text(verbatim: copy("本周到访", "Visits this week")), value: "\(visits)")
            }
            if let multipliers = card?.multipliers, !multipliers.isEmpty {
                ForEach(multipliers.keys.sorted(), id: \.self) { key in
                    CYFactRow(label: Text(verbatim: copy("租金乘数 ", "Rent multiplier ") + key), value: CityMonopolyFormat.multiplier(multipliers[key] ?? 1))
                }
            }
            if let propertyId = item.propertyId, let dc = card?.dc ?? model.scoutedDC[propertyId] {
                CYFactRow(label: Text(verbatim: copy("挑战 DC / 无修正胜率", "Challenge DC / base win chance")),
                          value: "\(dc) · \(CityMonopolyRules.winChancePercent(dc: dc, mod: 0))%")
            }
            if let propertyId = item.propertyId {
                actionButtons(propertyId: propertyId, isMine: isMine, claimed: item.claimed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
    }

    @ViewBuilder private func actionButtons(propertyId: String, isMine: Bool, claimed: Bool) -> some View {
        HStack(spacing: CYSpacing.sm) {
            if isMine {
                CYPillButton(verbatim: copy("升级报价", "Upgrade quote"), style: .primary, fullWidth: false) {
                    Task { await quote(.upgrade, propertyId: propertyId) }
                }
                .disabled(model.busy)
                CYPillButton(verbatim: copy("护盾 ", "Shield ") + points(CityMonopolyRules.shieldCost), style: .secondary, fullWidth: false) {
                    Task { await model.shield(propertyId: propertyId) }
                }
                .disabled(model.busy)
            } else if claimed {
                CYPillButton(verbatim: copy("挑战报价", "Challenge quote"), style: .primary, fullWidth: false) {
                    Task { await quote(.challenge, propertyId: propertyId) }
                }
                .disabled(model.busy)
                CYPillButton(verbatim: copy("侦察 DC", "Scout DC"), style: .secondary, fullWidth: false) {
                    Task { await model.scout(propertyId: propertyId) }
                }
                .disabled(model.busy)
            } else {
                CYPillButton(verbatim: copy("占领报价", "Claim quote"), style: .secondary, fullWidth: false) {
                    Task { await quote(.claim, propertyId: propertyId) }
                }
                .disabled(model.busy)
            }
        }
    }

    // MARK: Quote → presence → command

    @ViewBuilder private func quoteCard(_ pending: CityPendingTerritoryQuote) -> some View {
        let quote = pending.quote
        let anchor = items.first { $0.propertyId == pending.propertyId }.flatMap { RoamCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let checks = CityPresencePreflight.evaluate(fixes: fixes, anchor: anchor, requirePhoto: false, hasPhoto: false)
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYSectionHeader(LocalizedStringKey(actionTitle(pending.kind)))
            if let price = quote.price {
                CYFactRow(label: Text(verbatim: copy("费用", "Cost")), value: points(price))
            }
            if let hours = quote.protectionHours {
                CYFactRow(label: Text(verbatim: copy("保护期", "Protection")), value: copy("\(hours) 小时", "\(hours) h"))
            }
            if let toLevel = quote.toLevel {
                CYFactRow(label: Text(verbatim: copy("升级到", "Upgrade to")), value: "Lv\(toLevel) " + CityMonopolyLevel.name(toLevel, chinese: chinese))
            }
            if let dc = quote.dc {
                CYFactRow(label: Text(verbatim: copy("DC / 无修正胜率", "DC / base win chance")),
                          value: "\(dc) · \(CityMonopolyRules.winChancePercent(dc: dc, mod: 0))%")
            }
            if let task = quote.task {
                CYFactRow(label: Text(verbatim: copy("在地任务", "On-site task")), value: task.title ?? task.kind ?? "—")
            }
            if let expires = quote.expiresAt {
                CYFactRow(label: Text(verbatim: copy("报价有效", "Quote valid for")),
                          value: CityMonopolyFormat.countdown(seconds: expires.secondsRemaining(now: Date()), chinese: chinese))
            }
            if pending.kind == .claim {
                CYNoteBanner(text: Text(verbatim: copy("占领需用“照片占领”现场拍照提交；此处仅显示积分报价。",
                                                      "Claims are submitted with the in-app photo claim; this shows the points quote only.")),
                             symbol: "camera", tone: .info)
            } else {
                ForEach(checks) { check in
                    CYStatusChip(verbatim: check.detail(chinese: chinese), tone: check.passed ? .success : .warning,
                                 systemImage: check.passed ? "checkmark.circle" : "exclamationmark.circle")
                }
            }
            HStack(spacing: CYSpacing.sm) {
                if pending.kind != .claim {
                    CYPillButton(verbatim: samplingTask == nil ? copy("采集驻留定位（60 秒）", "Collect dwell fixes (60 s)") : copy("采集中…", "Collecting…"),
                                 style: .secondary, systemImage: "location", fullWidth: false) {
                        startSampling(anchor: anchor)
                    }
                    .disabled(captureFix == nil || samplingTask != nil || model.busy)
                    CYPillButton(verbatim: copy("确认", "Confirm"), style: .primary, fullWidth: false) {
                        Task { await model.confirm(fixes: fixes) }
                    }
                    .disabled(model.busy || fixes.isEmpty || samplingTask != nil)
                }
                CYPillButton(verbatim: copy("取消", "Cancel"), style: .tertiary, fullWidth: false) {
                    samplingTask?.cancel()
                    samplingTask = nil
                    model.cancelQuote()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
    }

    private func actionTitle(_ kind: CityTerritoryActionKind) -> String {
        switch kind {
        case .claim: return copy("占领报价", "Claim quote")
        case .upgrade: return copy("升级报价", "Upgrade quote")
        case .challenge: return copy("挑战报价", "Challenge quote")
        }
    }

    private func quote(_ kind: CityTerritoryActionKind, propertyId: String) async {
        let fix = try? await captureFix?()
        fixes = fix.map { [$0] } ?? []
        await model.requestQuote(kind, propertyId: propertyId, fix: fix)
    }

    /// Four fixes 20 s apart (≥ 3 samples spanning ≥ 60 s, §2.2), then one feedback pass over the checks.
    private func startSampling(anchor: RoamCoordinate?) {
        guard let captureFix, samplingTask == nil else { return }
        samplingTask = Task { @MainActor in
            defer { samplingTask = nil }
            for index in 0..<4 {
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                }
                if Task.isCancelled { return }
                let captured = try? await captureFix()
                if let captured { fixes.append(captured) }
            }
            let checks = CityPresencePreflight.evaluate(fixes: fixes, anchor: anchor, requirePhoto: false, hasPhoto: false)
            let passed = checks.filter { $0.passed }.count
            CityMonopolyHapticPlayer.play(.presenceChecks(passed: passed, failed: passed < checks.count), reduceMotion: reduceMotion)
        }
    }

    // MARK: Result, revenue, season board

    @ViewBuilder private func resultBanner(_ result: CityTerritoryCommandResult) -> some View {
        let kind = result.kind
        let success = kind == .applied || kind == .challengerWon
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYNoteBanner(text: Text(verbatim: outcomeText(result)), symbol: success ? "flag.fill" : "flag.slash", tone: success ? .success : .warning)
            if let roll = result.roll {
                CYFactRow(label: Text(verbatim: copy("d20 + 修正 / DC", "d20 + mods / DC")), value: rollSummary(result, roll: roll))
            }
            if let split = result.feeSplit {
                CYFactRow(label: Text(verbatim: copy("费用去向（守方 / 销毁）", "Fee split (defender / burned)")),
                          value: points(split.defender ?? 0) + " / " + points(split.burned ?? 0))
            }
            ForEach(result.reasons ?? [], id: \.self) { reason in
                CYStatusChip(verbatim: reason, tone: .warning)
            }
        }
    }

    private func rollSummary(_ result: CityTerritoryCommandResult, roll: Int) -> String {
        let mods = (result.mods ?? []).reduce(0) { $0 + $1.value }
        let total = result.total ?? (roll + mods)
        let dc = result.dc.map { String($0) } ?? "—"
        return "\(roll) + \(mods) = \(total) / " + dc
    }

    private func outcomeText(_ result: CityTerritoryCommandResult) -> String {
        switch result.kind {
        case .applied: return copy("已生效", "Applied") + (result.protectionHours.map { copy("，保护 \($0) 小时", ", protected \($0) h") } ?? "")
        case .challengerWon: return copy("挑战成功，地产转手", "Challenge won, property taken")
        case .challengerLost: return copy("挑战失败，守方获得保护", "Challenge lost, defender protected")
        case .rejected: return copy("未通过校验", "Not accepted")
        case .pendingReview: return copy("等待审核", "Pending review")
        case .unknown: return result.outcome
        }
    }

    @ViewBuilder private var revenueSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYSectionHeader(LocalizedStringKey(copy("收租明细（积分）", "Rent ledger (points)")))
            if let page = model.revenue {
                if let pending = page.todayPending {
                    CYFactRow(label: Text(verbatim: copy("今日待入账", "Today pending")), value: points(pending))
                }
                if let available = page.todayAvailable {
                    CYFactRow(label: Text(verbatim: copy("今日可用", "Today available")), value: points(available))
                }
                if let threshold = page.threshold {
                    CYFactRow(label: Text(verbatim: copy("每日全额阈值（超出按 50%）", "Daily full-rate threshold (50% beyond)")), value: points(threshold))
                }
                ForEach(page.events) { event in
                    CYFactRow(label: Text(verbatim: (event.visitorMasked ?? "—") + " · " + (event.propertyId ?? "")),
                              value: points(event.granted) + " · " + event.state + (event.capReason.map { " · " + $0 } ?? ""))
                }
                if page.events.isEmpty {
                    CYEmptyState(systemImage: "tray", LocalizedStringKey(copy("暂无收租记录", "No rent yet")))
                }
            } else {
                CYSkeleton()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
    }

    @ViewBuilder private var seasonBoardSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYSectionHeader(LocalizedStringKey(copy("赛季个人榜", "Season solo board")))
            if let board = model.seasonBoard {
                ForEach(board.rows) { row in
                    CYFactRow(label: Text(verbatim: "#\(row.rank) " + (row.name ?? row.subjectId ?? "—") + (row.isMe == true ? copy("（我）", " (me)") : "")),
                              value: "\(Int(row.score.rounded()))")
                }
                if board.rows.isEmpty {
                    CYEmptyState(systemImage: "trophy", LocalizedStringKey(copy("暂无赛季排行", "No season ranking yet")))
                }
            } else {
                CYSkeleton()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
    }
}
