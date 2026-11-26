import SwiftUI

@MainActor struct CityAcquisitionEntry: View {
    private let table = "CityAcquisition"
    let factory: (@MainActor () -> CityAcquisitionController)?
    var open: (@MainActor () -> Void)? = nil
    @Environment(\.locale) private var locale
    var body: some View {
        Group {
            if let open { Button(action: open) { entryLabel } }
            else { NavigationLink { CityAcquisitionView(controller: factory?() ?? .init(service: nil, journal: nil)) } label: { entryLabel } }
        }
        .accessibilityIdentifier("city.acquisition.entry")
    }
    private var entryLabel: some View {
        CYListRow(verbatim: cloud06Phrase("cityAcquire.entry", table: table, locale: locale), trailing: .chevron) {
            CYRowIcon(systemImage: "building.2.crop.circle")
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityLabel(Text("cityAcquire.entry", tableName: table))
    }
}
/// Authoritative current title read for this exact selected board/point, never a POI tag.
@MainActor struct CityAcquisitionPointStatus: View {
    @Environment(\.scenePhase) private var scenePhase
    private let table = "CityAcquisition"
    let board: CityReadBoard
    let pointID: String
    let factory: (@MainActor () -> CityAcquisitionController)?
    var open: (@MainActor () -> Void)? = nil
    @State private var controller: CityAcquisitionController?
    @State private var visible = false
    @State private var readID = UUID()
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            statusLine
            CityAcquisitionEntry(factory: factory, open: open)
        }
        .task(id: readID) {
            guard visible, scenePhase == .active, !Task.isCancelled else { return }
            let reader = factory?(); controller = reader; await reader?.load()
        }
        .onAppear { visible = true; readID = UUID() }
        .onDisappear { visible = false; controller?.suspend(); controller = nil }
        .onChange(of: scenePhase) { _, phase in
            controller?.suspend(); controller = nil
            if visible, phase == .active { readID = UUID() }
        }
        .onChange(of: controller?.current) { _, current in if current != true { controller?.invalidate() } }
    }
    @ViewBuilder private var statusLine: some View {
        if let snapshot = controller?.snapshot, snapshot.binding?.boardId == board.boardId, snapshot.binding?.seasonId == board.seasonId, snapshot.binding?.regionId == board.regionId, snapshot.binding?.contentHash == board.rulesHash, snapshot.binding?.rulesReleaseId == board.rulesReleaseId {
            if let title = snapshot.ownership.first(where: { $0.pointId == pointID }) {
                if title.contentHash == board.rulesHash {
                    CYNoteBanner(text: Text("cityAcquire.map.owned", tableName: table), symbol: "checkmark.seal", tone: .success)
                    Text(verbatim: cloud06Shown(title.ownerTeamId)).cyText(.meta).foregroundStyle(CYColor.textSecondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    CYNoteBanner(text: Text(CityAcquisitionView.status(title.status), tableName: table), symbol: "seal")
                } else {
                    CYNoteBanner(text: Text("cityAcquire.map.releaseReview", tableName: table), symbol: "exclamationmark.triangle", tone: .warning)
                }
            } else {
                CYNoteBanner(text: Text("cityAcquire.map.noRecordedTitle", tableName: table), symbol: "questionmark")
            }
        } else {
            CYNoteBanner(text: Text("cityAcquire.map.unavailable", tableName: table), symbol: "wifi.slash")
        }
    }
}
@MainActor struct CityAcquisitionView: View {
    private let table = "CityAcquisition"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @State private var controller: CityAcquisitionController
    @State private var visible = false
    @State private var readID = UUID()
    private var interactive: Bool { visible && scenePhase == .active && controller.current }
    private enum Lead { case review, quote, recover, refresh }
    private var reviewReady: Bool {
        guard let quote = controller.selectedQuote else { return false }
        return interactive && controller.canWrite && quote.writeApproved && quote.unexpired
    }
    private var leadQuoteID: String? {
        controller.snapshot?.candidates.first(where: { interactive && controller.allows($0) })?.id
    }
    private var lead: Lead {
        if reviewReady { return .review }
        if leadQuoteID != nil { return .quote }
        if controller.current, controller.originalRequestID != nil, interactive, !controller.busy { return .recover }
        return .refresh
    }
    init(controller: CityAcquisitionController) { _controller = State(initialValue: controller) }
    var body: some View {
        screenWithLifecycle
            .cyHapticEvent(.claimSuccess, trigger: controller.receipt?.requestId) { old, next in
                next != nil && old != next && controller.receipt?.succeeded == true
            }
            .cyHapticEvent(.wrongAnswer, trigger: controller.receipt?.requestId) { old, next in
                next != nil && old != next && controller.receipt?.succeeded == false
            }
            .onDisappear { visible = false; controller.suspend() }
    }
    private var screenWithLifecycle: some View {
        ScrollView { pageColumn }
            .scrollDismissesKeyboard(.interactively)
            .cyDomainPageBackground()
            .cyHeroScreen()
            .roleTheme(.player)
            .accessibilityIdentifier("city.acquisition.screen")
            .cySheet(item: confirmationBinding) { captured in Group { confirmationSheet(captured) }.cySheet(detents: [.large]) }
            .task(id: readID) { guard visible, scenePhase == .active, !Task.isCancelled else { return }; await controller.open(activity: controller.activityID) }
            .onAppear { visible = true; controller.activate(); readID = UUID() }
            .onChange(of: scenePhase) { _, phase in
                controller.suspend()
                if visible, phase == .active { controller.activate(); readID = UUID() }
            }
            .onChange(of: controller.current) { _, current in if !current { controller.invalidate() } }
    }
    private var confirmationBinding: Binding<CityAcquisitionQuote?> {
        Binding(get: { controller.confirmation }, set: { if $0 == nil { controller.cancelConfirmation() } })
    }
    private var pageColumn: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxl) {
            CYHeroHeader("cityAcquire.title", subtitle: "cityAcquire.boundary", tableName: table)
            statusBanner
            refreshControl
            recoverControl
            selectedQuoteControl
            if let receipt = controller.receipt { receiptBlock(receipt) }
            if let snapshot = controller.snapshot { tasksBlock(snapshot) }
            titlesBlock
            Text("cityAcquire.lifecycleBoundary", tableName: table)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.vertical, CYSpacing.lg)
    }
    private var statusBanner: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYNoteBanner(text: keyed(controller.messageKey), symbol: controller.busy ? "hourglass" : "info.circle")
            if controller.busy { CYSkeleton().accessibilityHidden(true) }
        }
    }
    private var refreshControl: some View {
        CYPillButton("cityAcquire.refresh", style: lead == .refresh ? .primary : .secondary, systemImage: "arrow.clockwise", tableName: table) {
            guard interactive else { return }
            readID = UUID()
        }
        .disabled(controller.busy || !interactive)
        .accessibilityLabel(Text("cityAcquire.refresh", tableName: table))
    }
    @ViewBuilder private var recoverControl: some View {
        if controller.current, controller.originalRequestID != nil {
            CYNoteBanner(text: Text(controller.pendingRequestID == nil ? "cityAcquire.original.hint" : "cityAcquire.pending.hint", tableName: table), symbol: "clock.arrow.circlepath")
            CYPillButton("cityAcquire.recover", style: lead == .recover ? .primary : .secondary, tableName: table, action: recoverOriginal)
                .disabled(controller.busy || !interactive)
                .accessibilityLabel(Text("cityAcquire.recover", tableName: table))
        }
    }
    @ViewBuilder private var selectedQuoteControl: some View {
        if let quote = controller.selectedQuote {
            quoteContent(quote)
            CYPillButton("cityAcquire.reviewConfirmation", style: lead == .review ? .primary : .secondary, tableName: table) {
                guard interactive else { return }
                controller.prepareConfirmation()
            }
            .disabled(!interactive || !controller.canWrite || !quote.writeApproved || !quote.unexpired)
            .accessibilityLabel(Text("cityAcquire.reviewConfirmation", tableName: table))
        }
    }
    private func tasksBlock(_ snapshot: CityAcquisitionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            sectionTitle("cityAcquire.tasks.title")
            if snapshot.candidates.isEmpty {
                CYEmptyState(systemImage: "flag", "cityAcquire.tasks.none", tableName: table)
            }
            ForEach(snapshot.candidates) { candidate in candidateCard(candidate) }
        }
    }
    private var titlesBlock: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            sectionTitle("cityAcquire.titles.title")
            ForEach(controller.titles) { title in titleContent(title) }
        }
    }
    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key, tableName: table)
            .cyText(.sectionTitle)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func confirmationSheet(_ captured: CityAcquisitionQuote) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    CYHeroHeader("cityAcquire.confirm.title", tableName: table)
                    quoteContent(captured)
                    Text("cityAcquire.confirm.hint", tableName: table)
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive) { confirm(captured) } label: {
                        Text("cityAcquire.confirm.pay", tableName: table)
                    }
                    .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                    .disabled(!interactive || !controller.canWrite || !captured.unexpired)
                    .accessibilityLabel(Text("cityAcquire.confirm.pay", tableName: table))
                    CYPillButton("cityAcquire.confirm.cancel", style: .secondary, tableName: table) { controller.cancelConfirmation() }
                        .accessibilityLabel(Text("cityAcquire.confirm.cancel", tableName: table))
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .cyDomainPageBackground()
            .cyHeroScreen()
            .roleThemedPresentation()
        }
    }
    private func requestQuote(_ candidate: CityAcquisitionCandidate) {
        guard interactive else { return }; let activity = controller.activityID
        Task { await controller.requestQuote(candidate, activity: activity) }
    }
    private func confirm(_ quote: CityAcquisitionQuote) {
        guard interactive else { return }; let activity = controller.activityID
        Task { await controller.confirm(quote, activity: activity) }
    }
    private func recoverOriginal() {
        guard interactive else { return }; let activity = controller.activityID
        Task { await controller.recover(activity: activity) }
    }
    private func keyed(_ key: String) -> Text {
        cloud06Phrase(key, table: table, locale: locale) == "—" ? Text(verbatim: "—") : Text(LocalizedStringKey(key), tableName: table)
    }
    @ViewBuilder private func quoteContent(_ q: CityAcquisitionQuote) -> some View {
        Text("cityAcquire.quote.title", tableName: table)
            .cyText(.sectionTitle)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
        CYImageCard(verbatim: cloud06Shown(q.pointId), fallback: "—", meta: cloud06Shown(q.beneficiaryTeamId), style: .hero)
            .accessibilityHidden(true)
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                metric("cityAcquire.quote.points", String(q.pointCost))
                metric("cityAcquire.quote.actions", String(q.actionCost))
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                metric("cityAcquire.quote.points", String(q.pointCost))
                metric("cityAcquire.quote.actions", String(q.actionCost))
            }
        }
        quoteFacts(q)
        Text("cityAcquire.quote.currentRelease", tableName: table).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        Text("cityAcquire.quote.assurance", tableName: table).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        Text(verbatim: cloud06Shown(q.evidenceAcceptanceReason)).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        Text(verbatim: cloud06Shown(q.quoteHash)).cyText(.caption).monospacedDigit().foregroundStyle(palette.textTertiary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        if !q.unexpired {
            CYNoteBanner(text: Text("cityAcquire.quote.expired", tableName: table), symbol: "clock.badge.exclamationmark", tone: .danger)
        }
    }
    @ViewBuilder private func quoteFacts(_ q: CityAcquisitionQuote) -> some View {
        CYFactRow(label: Text("cityAcquire.quote.payer", tableName: table), value: String(q.payerMemberId))
        CYFactRow(label: Text("cityAcquire.quote.team", tableName: table), value: cloud06Shown(q.beneficiaryTeamId))
        CYFactRow(label: Text("cityAcquire.quote.point", tableName: table), value: cloud06Shown(q.pointId))
        CYFactRow(label: Text("cityAcquire.quote.balance", tableName: table), value: String(q.pointsBalanceAtQuote))
        CYFactRow(label: Text("cityAcquire.quote.remainingActions", tableName: table), value: String(q.actionsRemainingAtQuote))
        CYFactRow(label: Text("cityAcquire.quote.limit", tableName: table), value: String(q.maxHoldingsPerTeam))
        CYFactRow(label: Text("cityAcquire.quote.term", tableName: table), value: String(q.termSeconds))
        CYFactRow(label: Text("cityAcquire.quote.expiry", tableName: table), value: cloud06Shown(q.expiresAt))
        CYFactRow(label: Text("cityAcquire.quote.release", tableName: table), value: String(q.releaseId))
        CYFactRow(label: Text("cityAcquire.quote.pointVersion", tableName: table), value: String(q.pointVersion))
        CYFactRow(label: Text("cityAcquire.quote.budgetVersion", tableName: table), value: String(q.budgetVersion))
    }
    private func metric(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(label, tableName: table).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: value).cyText(.dataXL).monospacedDigit().foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private func candidateCard(_ candidate: CityAcquisitionCandidate) -> some View {
        let eligible = candidate.eligibility == "QUOTE_AVAILABLE"
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(verbatim: cloud06Shown(candidate.pointId), meta: cloud06Shown(candidate.taskId), trailing: .none, card: true) {
                CYRowIcon(systemImage: "mappin.and.ellipse")
            }
            CYNoteBanner(text: Text(eligible ? "cityAcquire.task.eligible" : "cityAcquire.task.unavailable", tableName: table), symbol: eligible ? "checkmark" : "clock", tone: eligible ? .success : .neutral)
            CYPillButton("cityAcquire.quote", style: lead == .quote && leadQuoteID == candidate.id ? .primary : .secondary, tableName: table) { requestQuote(candidate) }
                .disabled(!interactive || !controller.allows(candidate))
                .accessibilityLabel(Text("cityAcquire.quote", tableName: table))
        }
    }
    @ViewBuilder private func titleContent(_ t: CityAcquisitionTitle) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(verbatim: cloud06Shown(t.pointId), trailing: .none, card: true) {
                CYRowIcon(systemImage: "seal")
            }
            CYNoteBanner(text: Text(Self.status(t.status), tableName: table), symbol: "seal", tone: titleTone(t.status))
            CYFactRow(label: Text("cityAcquire.quote.team", tableName: table), value: cloud06Shown(t.ownerTeamId))
            CYFactRow(label: Text("cityAcquire.title.debit", tableName: table), value: t.pointCost.map { String($0) } ?? "—")
            CYFactRow(label: Text("cityAcquire.title.after", tableName: table), value: t.pointsAfter.map { String($0) } ?? "—")
            CYFactRow(label: Text("cityAcquire.quote.actions", tableName: table), value: t.actionCost.map { String($0) } ?? "—")
            Text(verbatim: cloud06Shown(t.titleId)).cyText(.caption).foregroundStyle(palette.textTertiary).textSelection(.enabled)
        }
        .accessibilityElement(children: .contain)
    }
    private func titleTone(_ value: String) -> CYStatusTone {
        switch value {
        case "ACTIVE_TERM": return .success
        case "PAUSED_TERM_FROZEN": return .warning
        case "TERM_REVIEW_REQUIRED": return .info
        default: return .neutral
        }
    }
    @ViewBuilder private func receiptBlock(_ receipt: CityAcquisitionReceipt) -> some View {
        CYNoteBanner(text: Text(receipt.succeeded ? "cityAcquire.receipt.success" : "cityAcquire.receipt.rejected", tableName: table), symbol: receipt.succeeded ? "checkmark.seal" : "xmark.octagon", tone: receipt.succeeded ? .success : .danger)
        if let code = receipt.errorCode {
            Text(Self.failure(code), tableName: table).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        Text(verbatim: cloud06Shown(receipt.requestId)).cyText(.caption).monospacedDigit().foregroundStyle(palette.textTertiary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        if let title = receipt.title {
            Text("cityAcquire.receipt.historical", tableName: table).cyText(.meta).foregroundStyle(palette.textSecondary)
            titleContent(title)
        }
    }
    static func failure(_ code: String) -> LocalizedStringKey {
        switch code {
        case "POINT_ALREADY_OWNED", "TASK_EFFECT_ALREADY_COMMITTED": return "cityAcquire.failure.owned"
        case "INSUFFICIENT_POINTS": return "cityAcquire.failure.points"
        case "ACTION_BUDGET_EXHAUSTED", "ACTION_VERSION_CHANGED": return "cityAcquire.failure.actions"
        case "HOLDING_LIMIT_REACHED": return "cityAcquire.failure.limit"
        case "QUOTE_EXPIRED", "EVIDENCE_EXPIRED": return "cityAcquire.failure.expired"
        case "ORIGINAL_OUTCOME_UNRESOLVED", "ORIGINAL_CONFIRM_KEY_REQUIRED": return "cityAcquire.failure.original"
        default: return "cityAcquire.failure.changed"
        }
    }
    static func statusKey(_ value: String) -> String {
        switch value {
        case "ACTIVE_TERM": return "cityAcquire.title.active"
        case "PAUSED_TERM_FROZEN": return "cityAcquire.title.paused"
        case "TERM_REVIEW_REQUIRED": return "cityAcquire.title.review"
        default: return "cityAcquire.title.sourceUnavailable"
        }
    }
    static func status(_ value: String) -> LocalizedStringKey { LocalizedStringKey(statusKey(value)) }
}

private func cloud06Phrase(_ key: String, table: String, locale: Locale) -> String {
    let value = String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: table, locale: locale))
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == key { return "—" }
    return trimmed
}

private func cloud06Shown(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "—" : trimmed
}
