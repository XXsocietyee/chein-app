import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

@available(macOS 14.0, *)
@MainActor struct ExternalGameCatalogSection: View {
    let model: ExternalGameReviewModel
    let session: ExternalGameSessionBridge?
    var onSubmissions: () -> Void

    var body: some View {
        catalogBody
    }

    @ViewBuilder private var catalogBody: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: W8Text.t("可玩的 HTML 游戏", "HTML games you can play"))
                .font(CYTypography.cardTitle)
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
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.killSwitch")
            }
            if model.catalogFailed, model.catalog.isEmpty {
                Text(verbatim: W8Text.t("目录没有加载出来。", "The catalog did not load."))
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.catalog.error")
            } else if model.catalog.isEmpty {
                Text(verbatim: W8Text.t("还没有已通过的游戏。", "No approved games yet."))
                    .font(CYTypography.body)
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
                .font(CYTypography.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            CurA11yDashText(shown: meta(row), font: CYTypography.meta, color: CYColor.textSecondary)
            CurA11yDashText(shown: dash(row.summary), font: CYTypography.body, color: CYColor.textPrimary)
            CurA11yTextButton(
                title: Text(verbatim: W8Text.t("下载并安装", "Download and install")),
                hint: Text("curA11y.external.install.hint", tableName: "CurA11y"),
                identifier: "externalGame.install.\(row.gameID)",
                action: { Task { await model.install(gameID: row.gameID, session: session) } }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("externalGame.catalog.\(row.gameID)")
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
            .navigationTitle(W8Text.t("我的提交", "My submissions"))
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
                        .font(CYTypography.body)
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
                    .font(CYTypography.body)
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
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("externalGame.submissions.error")
            } else if model.submissions.isEmpty {
                Text(verbatim: W8Text.t("还没有提交。", "No submissions yet."))
                    .font(CYTypography.body)
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
                .font(CYTypography.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            CurA11yDashText(shown: "\(row.gameID) · v\(row.version) · \(row.status?.rawValue ?? "—")", font: CYTypography.meta, color: CYColor.textSecondary)
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
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: game.manifest.name)
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(CYSpacing.lg)
            .navigationTitle(Text(verbatim: W8Text.t("年龄分级", "Age rating")))
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
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: CurA11y.hit)
                .accessibilityHint(Text("curA11y.external.block.hint", tableName: "CurA11y"))
                .accessibilityAddTraits(blocked ? .isSelected : [])
            }
            .navigationTitle(Text(verbatim: W8Text.t("举报", "Report")))
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
