import SwiftUI

/// Explicit source-only host. Caller supplies original context/revision and approved providers, never a fixture grant.
@MainActor struct CityActionBudgetView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @Bindable var model: CityActionBudgetRecovery
    let context: RuntimeDependencyContext
    let identityVersion: UInt64
    var body: some View {
        Group {
            if session.currentRuntimeDependencyContext == context, model.isCurrent {
                ready
            } else {
                unavailable
            }
        }
        .roleTheme(.player)
        .task { await model.open() }
        .onChange(of: session.currentRuntimeDependencyContext) { _, current in if current != context { model.close() } }
        .onChange(of: identityVersion) { _, _ in model.close() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.close() } }
        .onDisappear { model.close() }
    }
    private var canReopen: Bool { session.currentRuntimeDependencyContext == context && scenePhase == .active }
    private var complete: Bool { if case .complete = model.display { return true }; return false }
    private enum Lead { case submit, recheck, prepare, refresh }
    private var prepareEnabled: Bool {
        !model.busy && model.state?.status == "AVAILABLE" && model.state?.writeApproved == true && scenePhase == .active
    }
    private var submitEnabled: Bool { model.canSubmit && scenePhase == .active }
    private var lead: Lead {
        if model.prepared != nil { return submitEnabled ? .submit : .refresh }
        if model.display == .unknown { return .recheck }
        if model.prepared == nil, model.display == .empty || complete, prepareEnabled { return .prepare }
        return .refresh
    }
    private var ready: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader(verbatim: copy("行动额度", "Action budget"), subtitle: copy("仅记录掷骰结果，不移动、不发奖。", "Records the roll only. It does not move you or grant a reward."))
                budgetSection
                refreshButton
                originalSection
                if let result = model.result { resultSection(result) }
                if let prepared = model.prepared {
                    confirmSection(prepared)
                } else if model.display == .empty || complete {
                    prepareButton
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
    }
    private var unavailable: some View {
        let reopen = reopenAction
        return ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader(verbatim: copy("行动额度", "Action budget"))
                CYStateLayout(
                    kind: .failure,
                    title: Text(verbatim: copy("行动额度暂时读不到", "Couldn't read action budget")),
                    detail: Text(verbatim: copy("保留原请求，不会自动重新提交。", "The original request is kept and will not be submitted again.")),
                    primaryVerbatim: reopen,
                    primaryStyle: .primary
                )
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
    }
    @ViewBuilder private var budgetSection: some View {
        if model.busy, model.state == nil {
            CYSkeleton().accessibilityHidden(true)
            focal(copy("剩余额度", "Remaining"), "—")
        } else if let state = model.state {
            CYNoteBanner(text: Text(verbatim: status(state.status)), symbol: "dice")
            focal(copy("剩余额度", "Remaining"), units(state.remainingUnits))
            CYFactRow(label: Text(verbatim: copy("每次消耗", "Cost per roll")), value: state.rules.map { String($0.rollCost) } ?? "—")
            CYFactRow(label: Text(verbatim: copy("骰子", "Dice")), value: state.dice.map { cloud06Shown($0.diceId) } ?? "—")
        } else {
            CYNoteBanner(text: Text(verbatim: copy("当前额度未读取，请刷新。", "The current budget has not been read yet. Refresh to load it.")), symbol: "arrow.clockwise")
            focal(copy("剩余额度", "Remaining"), "—")
        }
    }
    @ViewBuilder private var originalSection: some View {
        CYSectionHeader(LocalizedStringKey(copy("原请求", "Original request")))
        switch model.display {
        case .unknown:
            CYNoteBanner(text: Text(verbatim: copy("结果待确认。不会再次提交原请求。", "The result is still unconfirmed. The original request will not be submitted again.")), symbol: "clock.badge.questionmark", tone: .warning)
            CYPillButton(verbatim: copy("查询原结果", "Check the original result"), style: lead == .recheck ? .primary : .secondary) {
                Task { await model.recheck() }
            }
            .disabled(model.busy)
            .accessibilityLabel(Text(verbatim: copy("查询原结果", "Check the original result")))
        case .complete(let code):
            CYNoteBanner(text: Text(verbatim: code == 200
                         ? copy("原请求已完成", "The original request is complete")
                         : copy("原请求未获执行，请刷新后查看状态。", "The original request did not run. Refresh to see the status.")),
                         symbol: code == 200 ? "checkmark.seal" : "exclamationmark.triangle",
                         tone: code == 200 ? .success : .warning)
        case .storageBlocked:
            CYNoteBanner(text: Text(verbatim: copy("原记录暂不可读，暂不能提交。", "The original record cannot be read, so nothing can be submitted.")), symbol: "externaldrive.badge.exclamationmark", tone: .danger)
        case .unavailable, .hidden:
            CYNoteBanner(text: Text(verbatim: copy("当前入口不可用", "This entry is unavailable")), symbol: "lock", tone: .neutral)
        case .empty:
            CYEmptyState(systemImage: "dice", LocalizedStringKey(copy("没有待确认请求", "No request is waiting")))
        }
    }
    private var refreshButton: some View {
        CYPillButton(verbatim: copy("刷新额度", "Refresh budget"), style: lead == .refresh ? .primary : .secondary, systemImage: "arrow.clockwise") {
            Task { await model.refresh() }
        }
        .disabled(model.busy)
        .accessibilityLabel(Text(verbatim: copy("刷新额度", "Refresh budget")))
    }
    private var prepareButton: some View {
        CYPillButton(verbatim: copy("准备掷骰", "Prepare roll"), style: lead == .prepare ? .primary : .secondary, systemImage: "dice") { model.prepare() }
            .disabled(!prepareEnabled)
            .accessibilityLabel(Text(verbatim: copy("准备掷骰", "Prepare roll")))
    }
    private func resultSection(_ result: CityActionBudgetResult) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYSectionHeader(LocalizedStringKey(copy("已核原结果", "Verified original result")))
            CYFactRow(label: Text(verbatim: copy("骰面", "Face")), value: String(result.faceValue))
            CYFactRow(label: Text(verbatim: copy("消耗", "Spent")), value: String(result.costUnits))
            CYFactRow(label: Text(verbatim: copy("剩余", "Remaining")), value: String(result.afterUnits))
            Text(verbatim: cloud06Shown(result.resultId))
                .cyText(.caption)
                .foregroundStyle(palette.textTertiary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private func confirmSection(_ prepared: CityActionBudgetPrepared) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYSectionHeader(LocalizedStringKey(copy("确认本次掷骰", "Confirm this roll")))
            Text(verbatim: copy("消耗 \(prepared.cost) 行动额度，仅记录服务器结果。", "Spends \(prepared.cost) action units and only records the server result."))
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            CYPillButton(verbatim: copy("确认提交", "Confirm and submit"), style: lead == .submit ? .primary : .secondary, systemImage: "checkmark") {
                Task { await model.submit() }
            }
            .disabled(!model.canSubmit || scenePhase != .active)
            .accessibilityLabel(Text(verbatim: copy("确认提交", "Confirm and submit")))
            CYPillButton(verbatim: copy("取消", "Cancel"), style: .secondary) { model.cancelPreparation() }
                .disabled(model.busy)
                .accessibilityLabel(Text(verbatim: copy("取消", "Cancel")))
            if !model.canSubmit {
                Text(verbatim: copy("尚未取得本次原请求授权。", "This original request is not authorized yet."))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func focal(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: label).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: value).font(typeSize.isAccessibilitySize ? CYTypography.sectionTitle : CYTypography.dataXL)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    private var reopenAction: (title: String, action: () -> Void)? {
        guard canReopen else { return nil }
        return (title: copy("重新打开", "Open again"), action: { _ = Task { await model.open() } })
    }
    private func units(_ value: Int?) -> String {
        if let number = value { return String(number) }
        return "—"
    }
    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }
    private func status(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "—" }
        switch trimmed {
        case "JOIN_REQUIRED": return copy("请先加入城市队伍", "Join a city team first")
        case "TEAM_NOT_READY": return copy("队伍尚未就绪", "The team is not ready yet")
        case "NOT_CONFIGURED": return copy("当前规则未配置行动额度", "These rules have no action budget")
        case "EXHAUSTED": return copy("本轮行动额度已用完", "This round's action budget is used up")
        default: return copy("当前行动额度可用", "Action budget is available")
        }
    }
}

private func cloud06Shown(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "—" : trimmed
}
