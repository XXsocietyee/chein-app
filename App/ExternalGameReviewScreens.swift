import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

@available(macOS 14.0, *)
@MainActor struct ExternalGameCatalogSection: View {
    let model: ExternalGameReviewModel
    let session: ExternalGameSessionBridge?
    var onSubmissions: () -> Void
    @State private var showCreatorMonetization = false

    var body: some View {
        catalogBody
            .sheet(isPresented: $showCreatorMonetization) { Group {
                ExternalGameCreatorMonetizationSheet(model: model, session: session)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder private var catalogBody: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: W8Text.t("可玩的 HTML 游戏", "HTML games you can play"))
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("externalGame.catalog")
            CurA11yNotice(
                text: Text(verbatim: indexNotice),
                hint: Text("curA11y.external.notice.hint", tableName: "CurA11y"),
                identifier: "externalGame.reviewIndex",
                tone: CYColor.textSecondary
            )
            if !model.removedByKillSwitch.isEmpty {
                Text(verbatim: W8Text.t("已下架并从本机移除：\(model.removedByKillSwitch.joined(separator: ", "))", "Removed from this device because they are no longer published: \(model.removedByKillSwitch.joined(separator: ", "))"))
                    .cyText(.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.killSwitch")
            }
            if model.catalogFailed, model.catalog.isEmpty {
                Text(verbatim: W8Text.t("目录没有加载出来。", "The catalog did not load."))
                    .cyText(.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.catalog.error")
            } else if model.catalog.isEmpty {
                Text(verbatim: W8Text.t("还没有已通过的游戏。", "No approved games yet."))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.catalog.empty")
            } else {
                ForEach(model.catalog, id: \.gameID) { row in catalogRow(row) }
            }
            CurA11yTextButton(
                title: Text(verbatim: W8Text.t("我的提交", "My submissions")),
                hint: Text("curA11y.external.submissions.hint", tableName: "CurA11y"),
                identifier: "externalGame.submissions",
                action: onSubmissions
            )
            if session != nil {
                Button(W8Text.t("创作者定价与流量收益", "Creator Pricing & Traffic")) {
                    showCreatorMonetization = true
                }
                .cyText(.label)
                .accessibilityLabel(W8Text.t("创作者定价与流量收益", "Creator Pricing & Traffic"))
                .accessibilityHint(W8Text.t("打开创作者变现配置与节点绑定面板", "Open creator monetization and node binding sheet"))
                .accessibilityIdentifier("externalGame.creatorMonetization")
            }
        }
    }

    private var indexNotice: String {
        let bridge = ExternalGameReviewClient.bridgeActions.joined(separator: ", ")
        return W8Text.t(
            "仅 HTML / JavaScript，不下载原生代码。桥接 \(ExternalGameReviewClient.bridgeVersion) 只开放 \(bridge)。收费为 NONE。仍在待审核的提交会在服务器审核窗口后升级（默认 3 天，原因 REVIEW_TIMEOUT）。已从已通过目录下架的游戏会在下次启动时从本机删除。举报保持未处理，直到服务器标为已解决。",
            "HTML and JavaScript only. No native code is downloaded. Bridge \(ExternalGameReviewClient.bridgeVersion) allows only \(bridge). Monetization is NONE. A submission still pending is escalated after the server review window (default 3 days, reason REVIEW_TIMEOUT). A game that leaves the approved catalog is removed from this device on the next launch. A report stays open until the server marks it resolved.")
    }

    private func catalogRow(_ row: ExternalGameCatalogFact) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: row.name)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            CurA11yDashText(shown: meta(row), font: CYTypography.meta, color: CYColor.textSecondary)
            CurA11yDashText(shown: dash(row.summary), font: CYTypography.body, color: CYColor.textPrimary)
            if let cfg = model.monetizationByGame[row.gameID] {
                Text(verbatim: monetizationLabel(cfg, moneyOn: Self.moneyOn(session)))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
            if let cfg = model.monetizationByGame[row.gameID],
               cfg.reviewStatus == "APPROVED",
               cfg.pricingMode == "PAID",
               cfg.priceFen > 0,
               !cfg.entitled {
                if let session,
                   ReviewedAreaSwitch.moneyPayments(apiHost: session.baseURL.host),
                   !ReleaseMoneyWriteSwitch.blocks(ExternalGameReviewPaths.orders) {
                    Button(W8Text.t("TEST 解锁购买 (¥\(String(format: "%.2f", Double(cfg.priceFen) / 100.0)))", "TEST Purchase (¥\(String(format: "%.2f", Double(cfg.priceFen) / 100.0)))")) {
                        Task { _ = await model.purchaseGame(gameID: row.gameID, session: session) }
                    }
                    .cyText(.label)
                    .accessibilityLabel(W8Text.t("解锁购买 \(row.name)", "Purchase \(row.name)"))
                    .accessibilityHint(W8Text.t("发起 TEST 环境模拟购买并解锁下载", "Trigger a test purchase to unlock download and play"))
                    .accessibilityIdentifier("externalGame.purchase.\(row.gameID)")
                } else {
                    Text(verbatim: W8Text.t("付费内容 · 当前环境未开启支付", "Paid game · payments disabled here"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("externalGame.paymentsDisabled.\(row.gameID)")
                }
            } else {
                CurA11yTextButton(
                    title: Text(verbatim: W8Text.t("下载并安装", "Download and install")),
                    hint: Text("curA11y.external.install.hint", tableName: "CurA11y"),
                    identifier: "externalGame.install.\(row.gameID)",
                    action: { Task { await model.install(gameID: row.gameID, session: session) } }
                )
            }
        }
        .task(id: row.gameID) {
            await model.loadMonetization(gameID: row.gameID, session: session)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("externalGame.catalog.\(row.gameID)")
    }

    /// Design hand-off r1 CF-48 / CF-62: 积分 is the only currency. A cash price stays TEST-only and is
    /// shown only behind the money switch; traffic rewards read as 积分. Review status is a word, never a code.
    static func moneyOn(_ session: ExternalGameSessionBridge?) -> Bool {
        guard let session else { return false }
        return ReviewedAreaSwitch.moneyPayments(apiHost: session.baseURL.host)
            && !ReleaseMoneyWriteSwitch.blocks(ExternalGameReviewPaths.orders)
    }

    static func reviewStatusText(_ raw: String?) -> String {
        switch EditorReviewStatus(raw: raw) {
        case .pending: return W8Text.t("审核中", "In review")
        case .rejected: return W8Text.t("未通过", "Not approved")
        case .approved: return W8Text.t("已通过", "Approved")
        case .draft: return W8Text.t("草稿", "Draft")
        case .unknown: return EditorUnknown.dash
        }
    }

    private func monetizationLabel(_ cfg: ExternalGameMonetizationFact, moneyOn: Bool) -> String {
        let priceText: String
        switch cfg.pricingMode {
        case "PAID":
            priceText = moneyOn
                ? W8Text.t("测试价 ", "Test price ") + String(format: "¥%.2f", Double(cfg.priceFen) / 100.0)
                : W8Text.t("付费（测试）", "Paid (test)")
        case "TRAFFIC_ONLY": priceText = W8Text.t("游玩奖励积分", "Play rewards in points")
        default: priceText = W8Text.t("免费", "Free")
        }
        let trafficText: String
        switch cfg.trafficRewardMode {
        case "POINTS": trafficText = W8Text.t(" · 游玩积分", " · Play points")
        case "TEST_MONEY": trafficText = moneyOn ? W8Text.t(" · 现金激励（测试）", " · Cash reward (test)") : ""
        default: trafficText = ""
        }
        let status = EditorReviewStatus(raw: cfg.reviewStatus)
        let statusText = status == .pending || status == .rejected ? " · " + Self.reviewStatusText(cfg.reviewStatus) : ""
        return "\(priceText)\(trafficText)\(statusText)"
    }

    private func meta(_ row: ExternalGameCatalogFact) -> String {
        let author = dash(row.author)
        let domains = row.allowedDomains.isEmpty ? "—" : row.allowedDomains.joined(separator: ", ")
        let permissions = row.permissions.isEmpty ? "—" : row.permissions.joined(separator: ", ")
        return "v\(row.version) · \(row.contentRating) · \(author) · \(row.monetization) · \(row.sha256) · \(permissions) · \(domains)"
    }

    private func dash(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value
    }
}

@available(macOS 14.0, *)
@MainActor struct ExternalGameSubmissionsScreen: View {
    let model: ExternalGameReviewModel
    let session: ExternalGameSessionBridge?
    @State private var resubmitID: String?
    @State private var picking = false

    var body: some View {
        submissionsBody
            .navigationTitle(W8Text.t("我的提交", "My submissions")).navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("externalGame.submissions.root")
            .fileImporter(isPresented: $picking, allowedContentTypes: [.json, .data], allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url), let target = resubmitID else { return }
                Task { await model.resubmit(submissionID: target, archive: data, session: session) }
            }
    }

    @ViewBuilder private var submissionsBody: some View {
        List {
            if let requestID = model.unconfirmedRequestID {
                Section {
                    Text(verbatim: W8Text.t("结果未知，仍保留请求 \(requestID)。", "The result is unknown. Request \(requestID) is still saved."))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHint(Text("curA11y.playGap.result.hint", tableName: "CurA11y"))
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityIdentifier("externalGame.unconfirmed")
                }
            }
            if !model.notice.isEmpty {
                Text(verbatim: model.notice)
                    .cyText(.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                CurA11yLabeled(
                    title: Text(verbatim: W8Text.t("审核状态", "Review status")),
                    value: Text(verbatim: model.workshopStatusText),
                    hint: Text("curA11y.external.notice.hint", tableName: "CurA11y"),
                    identifier: "externalGame.workshopStatus"
                )
            }
            if model.submissionsFailed, model.submissions.isEmpty {
                Text(verbatim: W8Text.t("提交列表没有加载出来。", "Submissions did not load."))
                    .cyText(.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.submissions.error")
            } else if model.submissions.isEmpty {
                Text(verbatim: W8Text.t("还没有提交。", "No submissions yet."))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.submissions.empty")
            } else {
                ForEach(model.submissions, id: \.submissionID) { row in submissionRow(row) }
            }
        }
    }

    private func submissionRow(_ row: ExternalGameSubmissionFact) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: row.name)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            CurA11yDashText(shown: "v\(row.version) · " + ExternalGameCatalogSection.reviewStatusText(row.status?.rawValue), font: CYTypography.meta, color: CYColor.textSecondary)
            CurA11yDashText(shown: W8Text.t("驳回原因", "Reject reason") + " " + (row.rejectReason ?? "—"), font: CYTypography.body, color: CYColor.textPrimary)
                .accessibilityIdentifier("externalGame.rejectReason.\(row.submissionID)")
            if row.canCancel {
                CurA11yTextButton(
                    title: Text(verbatim: W8Text.t("撤回", "Cancel")),
                    hint: Text("curA11y.external.cancel.hint", tableName: "CurA11y"),
                    identifier: "externalGame.cancel.\(row.submissionID)",
                    action: { Task { await model.cancel(submissionID: row.submissionID, session: session) } }
                )
            }
            if row.canResubmit {
                CurA11yTextButton(
                    title: Text(verbatim: W8Text.t("重新提交", "Resubmit")),
                    hint: Text("curA11y.external.resubmit.hint", tableName: "CurA11y"),
                    identifier: "externalGame.resubmit.\(row.submissionID)",
                    action: {
                        resubmitID = row.submissionID
                        picking = true
                    }
                )
            }
        }
        .accessibilityIdentifier("externalGame.submission.\(row.submissionID)")
    }
}

@available(macOS 14.0, *)
@MainActor struct ExternalGameAgeGateSheet: View {
    let game: InstalledExternalGame
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text(verbatim: W8Text.t("这个游戏的分级是 \(game.manifest.contentRating)。确认你的年龄符合这个分级后再开始。", "This game is rated \(game.manifest.contentRating). Confirm you meet that rating before you play."))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: game.manifest.name)
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(CYSpacing.lg)
            .navigationTitle(Text(verbatim: W8Text.t("年龄分级", "Age rating"))).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CurA11yTextButton(
                        title: Text(verbatim: W8Text.t("取消", "Cancel")),
                        hint: Text("curA11y.external.ageCancel.hint", tableName: "CurA11y"),
                        expands: false,
                        action: onCancel
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    CurA11yTextButton(
                        title: Text(verbatim: W8Text.t("符合分级", "I meet this rating")),
                        hint: Text("curA11y.external.ageConfirm.hint", tableName: "CurA11y"),
                        identifier: "externalGame.ageGate.confirm",
                        expands: false,
                        action: onConfirm
                    )
                }
            }
        }
        .accessibilityIdentifier("externalGame.ageGate")
    }
}

@available(macOS 14.0, *)
@MainActor struct ExternalGameReportSheet: View {
    let manifest: ExternalGameManifest
    let onSend: (ExternalGameReportDraft) -> Void
    let onCancel: () -> Void
    @State private var reason = "BROKEN"
    @State private var detail = ""
    @State private var blocked = true

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $reason) {
                    ForEach(ExternalGameReviewClient.reasonCodes, id: \.self) { code in
                        Text(verbatim: code).tag(code)
                    }
                } label: {
                    Text(verbatim: W8Text.t("原因", "Reason"))
                }
                .frame(minHeight: CurA11y.hit)
                .accessibilityLabel(Text(verbatim: W8Text.t("原因", "Reason")))
                .accessibilityHint(Text("curA11y.external.reason.hint", tableName: "CurA11y"))
                CurA11yField(
                    title: Text(verbatim: W8Text.t("补充说明", "Details")),
                    hint: Text("curA11y.external.detail.hint", tableName: "CurA11y"),
                    text: $detail
                )
                Toggle(isOn: $blocked) {
                    Text(verbatim: W8Text.t("同时在本机屏蔽", "Also block on this device"))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: CurA11y.hit)
                .accessibilityHint(Text("curA11y.external.block.hint", tableName: "CurA11y"))
                .accessibilityAddTraits(blocked ? .isSelected : [])
            }
            .navigationTitle(Text(verbatim: W8Text.t("举报", "Report"))).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CurA11yTextButton(
                        title: Text(verbatim: W8Text.t("取消", "Cancel")),
                        hint: Text("curA11y.external.reportCancel.hint", tableName: "CurA11y"),
                        expands: false,
                        action: onCancel
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    CurA11yTextButton(
                        title: Text(verbatim: W8Text.t("提交举报", "Send report")),
                        hint: Text("curA11y.external.reportSend.hint", tableName: "CurA11y"),
                        identifier: "externalGame.reportSubmit",
                        expands: false,
                        action: {
                            onSend(ExternalGameReportDraft(gameID: manifest.id, version: manifest.version, sha256: manifest.sha256, reasonCode: reason, detail: detail, blocked: blocked))
                        }
                    )
                }
            }
        }
        .accessibilityIdentifier("externalGame.reportSheet")
    }
}

@available(macOS 14.0, *)
@MainActor struct ExternalGameCreatorMonetizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: ExternalGameReviewModel
    let session: ExternalGameSessionBridge?

    @State private var gameID = ""
    @State private var pricingMode = "TRAFFIC_ONLY"
    @State private var priceYuanText = "0"
    @State private var trafficRewardMode = "POINTS"
    @State private var channelFeeBearer = 0
    @State private var nodeIDText = ""
    @State private var minScoreText = "0"
    @State private var isSaving = false
    private var moneyOn: Bool { ExternalGameCatalogSection.moneyOn(session) }

    var body: some View {
        NavigationStack {
            Form {
                if let summary = model.creatorSummary {
                    Section(W8Text.t("创作者收益概览", "Creator Summary")) {
                        LabeledContent(W8Text.t("付费订单数", "Paid Orders"), value: "\(summary.paidOrders)")
                        LabeledContent(W8Text.t("净销售分成（测试）", "Sales net (test)"), value: moneyOn ? String(format: "¥%.2f", Double(summary.creatorSalesNetFen) / 100.0) : EditorUnknown.dash)
                        LabeledContent(W8Text.t("有效流量游玩", "Valid Traffic Plays"), value: "\(summary.trafficValidPlays)")
                        LabeledContent(W8Text.t("已结算流量积分", "Traffic Points"), value: "\(summary.trafficSettledPoints)")
                        if summary.payoutGateOpen {
                            LabeledContent(W8Text.t("流量现金（测试）", "Traffic cash (test)"), value: moneyOn ? String(format: "¥%.2f", Double(summary.trafficSettledFen) / 100.0) : EditorUnknown.dash)
                        }
                    }
                }
                Section(W8Text.t("定价与流量激励配置（发布后可设）", "Monetization Config")) {
                    // CF-03: the game is picked by name; the ID is not shown.
                    if model.catalog.isEmpty {
                        TextField(W8Text.t("小游戏编号", "Game number"), text: $gameID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel(W8Text.t("小游戏编号", "Game number"))
                            .accessibilityIdentifier("externalGame.monetization.gameID")
                    } else {
                        Picker(W8Text.t("小游戏", "Game"), selection: $gameID) {
                            ForEach(model.catalog, id: \.gameID) { row in Text(verbatim: row.name).tag(row.gameID) }
                        }
                        .accessibilityIdentifier("externalGame.monetization.gameID")
                    }
                    Picker(W8Text.t("定价模式", "Pricing Mode"), selection: $pricingMode) {
                        Text(W8Text.t("仅流量激励", "Traffic Only")).tag("TRAFFIC_ONLY")
                        // Owner Q6: the external-game price stays hidden unless the TEST money switch is on.
                        if moneyOn || pricingMode == "PAID" {
                            Text(W8Text.t("付费购买（测试）", "Paid (test)")).tag("PAID")
                        }
                        Text(W8Text.t("免费无激励", "Free")).tag("FREE")
                    }
                    .accessibilityIdentifier("externalGame.monetization.pricingMode")
                    if pricingMode == "PAID" {
                        // A cash price is TEST-only and stays behind the money switch (积分 is the only currency).
                        TextField(W8Text.t("测试售价（元）", "Test price (CNY)"), text: $priceYuanText)
                            .keyboardType(.decimalPad)
                            .disabled(!moneyOn)
                            .accessibilityLabel(W8Text.t("测试售价（元）", "Test price in CNY"))
                            .accessibilityIdentifier("externalGame.monetization.priceYuan")
                        if !moneyOn {
                            Text(verbatim: W8Text.t("支付没有开启，售价只能在测试环境设置。", "Payments are off. A price can only be set in the test environment."))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("externalGame.monetization.priceLocked")
                        }
                    }
                    Picker(W8Text.t("流量激励模式", "Traffic Mode"), selection: $trafficRewardMode) {
                        Text(W8Text.t("积分", "Points")).tag("POINTS")
                        if moneyOn || trafficRewardMode == "TEST_MONEY" {
                            Text(W8Text.t("现金（测试）", "Cash (test)")).tag("TEST_MONEY")
                        }
                        Text(W8Text.t("关闭", "None")).tag("NONE")
                    }
                    .accessibilityIdentifier("externalGame.monetization.trafficMode")
                    Picker(W8Text.t("通道手续费", "Channel Fee"), selection: $channelFeeBearer) {
                        Text(W8Text.t("创作者承担", "Creator")).tag(0)
                        Text(W8Text.t("平台承担", "Platform")).tag(1)
                    }
                    .accessibilityIdentifier("externalGame.monetization.feeBearer")
                    Button(isSaving ? W8Text.t("正在提交", "Submitting") : W8Text.t("保存并提交审核", "Save & Submit Review")) {
                        let yuan = moneyOn ? (Double(priceYuanText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) : 0
                        let fen = max(0, Int((yuan * 100.0).rounded()))
                        Task {
                            isSaving = true
                            _ = await model.saveMonetization(
                                gameID: gameID.trimmingCharacters(in: .whitespacesAndNewlines),
                                pricingMode: pricingMode,
                                priceFen: fen,
                                trafficRewardMode: trafficRewardMode,
                                channelFeeBearer: channelFeeBearer,
                                session: session
                            )
                            isSaving = false
                        }
                    }
                    .disabled(gameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .accessibilityHint(W8Text.t("保存变现配置并提交审核", "Save monetization configuration and submit for review"))
                    .accessibilityIdentifier("externalGame.saveMonetization")
                }

                Section(W8Text.t("绑定到主题节点", "Bind to Journey Node")) {
                    TextField(W8Text.t("节点编号", "Node number"), text: $nodeIDText)
                        .keyboardType(.numberPad)
                        .accessibilityLabel(W8Text.t("目标主题节点编号", "Target journey node ID"))
                        .accessibilityIdentifier("externalGame.monetization.nodeID")
                    TextField(W8Text.t("最低通关分 (0 不限)", "Min Score"), text: $minScoreText)
                        .keyboardType(.numberPad)
                        .accessibilityLabel(W8Text.t("最低通关分数", "Minimum passing score"))
                        .accessibilityIdentifier("externalGame.monetization.minScore")
                    Button(W8Text.t("绑定外部游戏到此节点", "Bind Game to Node")) {
                        guard let nid = Int(nodeIDText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                        let minScore = Int(minScoreText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        Task {
                            _ = await model.bindNode(
                                nodeID: nid,
                                gameID: gameID.trimmingCharacters(in: .whitespacesAndNewlines),
                                minScore: minScore,
                                session: session
                            )
                        }
                    }
                    .disabled(gameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(nodeIDText) == nil)
                    .accessibilityHint(W8Text.t("将所选外部游戏绑定到指定主题节点", "Bind the selected external game to the specified journey node"))
                    .accessibilityIdentifier("externalGame.bindNode")
                }

                if !model.notice.isEmpty {
                    Section {
                        Text(verbatim: model.notice).cyText(.meta)
                            .accessibilityIdentifier("externalGame.monetization.notice")
                    }
                }
            }
            .navigationTitle(W8Text.t("创作者变现与绑定", "Creator Monetization")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(W8Text.t("关闭", "Close")) { dismiss() }
                        .accessibilityIdentifier("externalGame.monetization.close")
                }
            }
            .accessibilityIdentifier("externalGame.monetizationSheet")
            .task {
                if gameID.isEmpty, let first = model.catalog.first?.gameID {
                    gameID = first
                }
                await model.loadCreatorSummary(session: session)
            }
        }
    }
}
