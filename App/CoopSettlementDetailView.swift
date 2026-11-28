import SwiftUI

/// Adapts the existing session reader; it never constructs another endpoint or transport.
@MainActor private final class CoopSettlementJourneyAdapter: CoopSettlementJourneyReading {
    private let reader: any CoopFlowReading
    private var observed: CoopFlowSession?
    private var stamp = UUID()
    private var active = true
    init(_ reader: any CoopFlowReading) { self.reader = reader; observed = reader.session }
    var scope: UUID? {
        guard active else { return nil }
        let session = reader.session
        if session != observed { observed = session; stamp = UUID() }
        return session == nil ? nil : stamp
    }
    func matches(_ reader: any CoopFlowReading) -> Bool { active && ObjectIdentifier(self.reader) == ObjectIdentifier(reader) }
    func invalidate() { active = false; observed = nil; stamp = UUID() }
    func data(source: CoopFlowSettlement.Source) async throws -> CoopFlowJSON {
        guard let captured = scope else { throw APIError.unauthorized }
        let payload = try await reader.read(source == .finance ? .finance : .myBusiness, isCurrent: { self.scope == captured })
        guard scope == captured, !Task.isCancelled else { throw CoopFlowFailure.stale }
        return payload
    }
}

@MainActor private final class CoopSettlementJourneyViewModel: ObservableObject {
    @Published private(set) var revision = 0
    let journey = CoopSettlementReadJourney()
    private var adapter: CoopSettlementJourneyAdapter?
    func detail(reader: any CoopFlowReading, source: CoopFlowSettlement.Source, id: Int) -> CoopSettlementDetailModel? {
        guard let adapter, adapter.matches(reader) else { return nil }
        return journey.detail(reader: adapter, source: source, id: id)
    }
    func issue(reader: any CoopFlowReading, source: CoopFlowSettlement.Source, id: Int) -> CoopSettlementReadJourney.Issue? {
        guard let adapter, adapter.matches(reader) else { return nil }
        return journey.issue(reader: adapter, source: source, id: id)
    }
    func invalidate() { adapter?.invalidate(); adapter = nil; journey.invalidate(); revision += 1 }
    func load(reader: any CoopFlowReading, source: CoopFlowSettlement.Source, id: Int) async {
        if adapter?.matches(reader) != true { invalidate(); adapter = .init(reader) }
        guard let adapter else { return }
        revision += 1
        await journey.load(reader: adapter, source: source, id: id)
        revision += 1
    }
}

/// Source `pages/coop/settlement-detail` for `source=finance` (organizer) and `source=ledger` (merchant `mybiz`).
/// One read per load; the row is found client-side after the whole payload validates. A failed refresh keeps
/// the last detail visible with an inline notice, as the source `stale-error` state does.
@MainActor struct CoopSettlementDetailView: View {
    let reader: any CoopFlowReading
    let source: CoopFlowSettlement.Source
    let id: Int
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    private typealias Issue = CoopSettlementReadJourney.Issue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = CoopSettlementJourneyViewModel()
    @State private var refresh = UUID()
    private struct ReadTask: Equatable {
        let reader: ObjectIdentifier
        let account: Int?
        let epoch: UInt64?
        let source: String
        let recordID: Int
        let refresh: UUID
    }
    private var detail: CoopSettlementDetailModel? { model.detail(reader: reader, source: source, id: id) }
    private var issue: Issue? { model.issue(reader: reader, source: source, id: id) }
    private var loading: Bool { model.journey.isLoading }

    var body: some View {
        List {
            CYHeroHeader("cooperation.settlement.title").listRowBackground(Color.clear).listRowSeparator(.hidden)
            if id <= 0 { missingParameter }
            else if reader.session == nil { CYStatusChip("cooperation.login", tone: .neutral, systemImage: "person.crop.circle.badge.questionmark").accessibilityIdentifier("cooperation.settlement.login") }
            else if let detail {
                if loading { notice("cooperation.settlement.refreshing", "cooperation.settlement.refreshing.detail", id: "refreshing") }
                if case .failed(let message)? = issue {
                    Section {
                        notice("cooperation.settlement.staleError", nil, verbatim: message, id: "stale")
                        CYPillButton("cooperation.refresh", style: .secondary) { refresh = UUID() }.accessibilityIdentifier("cooperation.settlement.retry")
                    }
                }
                content(detail)
            } else if let issue, !loading { failure(issue) }
            else { CYSkeleton(variant: .detail).accessibilityIdentifier("cooperation.settlement.loading") }
        }
        .cyGroupedSurface()
        .cyMiniListScreen()
        .cyHeroScreen()
        .themeDomain(.merchant)
        .cyHideTabBar(true)
        .task(id: ReadTask(reader: ObjectIdentifier(reader), account: reader.session?.accountID, epoch: reader.session?.epoch, source: source.rawValue, recordID: id, refresh: refresh)) { await load() }
        .refreshable { await load() }
        .onDisappear { model.invalidate() }
        .onChange(of: reader.session) { _, _ in model.invalidate(); refresh = UUID() }
        .onChange(of: scenePhase) { _, phase in
            model.invalidate()
            if phase == .active { refresh = UUID() }
        }
        .accessibilityIdentifier("cooperation.settlement.\(source.rawValue).\(id)")
    }

    @ViewBuilder private func content(_ detail: CoopSettlementDetailModel) -> some View {
        Section {
            // Mini `.sd__hero`: perspective + title with the status badge on the right, then label + big tabular amount.
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(LocalizedStringKey("cooperation.settlement.perspective." + detail.perspective.rawValue)).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        Text(verbatim: title(detail)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    }
                    Spacer(minLength: CYSpacing.sm)
                    CoopSettlementToneBadge(status: detail.status, tone: detail.tone)
                }
                Text("cooperation.settlement.line.income").cyText(.label).foregroundStyle(CYColor.textSecondary).padding(.top, CYSpacing.md)
                Text(verbatim: detail.amount.map { LocaleDisplay.money($0, negative: false, locale: locale) } ?? "—").cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                    .cyWrapText()
                    .accessibilityLabel(detail.amount.map { Text(verbatim: LocaleDisplay.money($0, negative: false, locale: locale)) } ?? Text("coopflow.amount.unknown"))
                    .accessibilityIdentifier("cooperation.settlement.amount")
            }.padding(.vertical, CYSpacing.xs)
        }
        Section("cooperation.settlement.breakdown") {
            ForEach(Array(detail.lines.enumerated()), id: \.offset) { _, line in
                LabeledContent { Text(verbatim: valueText(line.value)).monospacedDigit().cyText(line.strong ? .bodyMedium : .label).foregroundStyle(CYColor.textPrimary) } label: {
                    Text(LocalizedStringKey("cooperation.settlement.line." + line.key)).cyText(.label).foregroundStyle(CYColor.textSecondary)
                }.accessibilityIdentifier("cooperation.settlement.line.\(line.key)")
            }
        }
        Section("cooperation.settlement.progress") {
            ForEach(Array(detail.timeline.enumerated()), id: \.offset) { _, step in
                LabeledContent { Text(verbatim: valueText(step.value)).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary) } label: {
                    // Mini `.sd__timeline`: dot + label (600) with the time beneath on the trailing side.
                    HStack(spacing: CYSpacing.sm) {
                        Circle()
                            .fill(CYColor.textPrimary)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(LocalizedStringKey("cooperation.settlement.step." + step.key))
                            .cyText(.label, weight: .semibold)
                            .foregroundStyle(CYColor.textPrimary)
                    }
                }.accessibilityIdentifier("cooperation.settlement.step.\(step.key)")
            }
        }
        Section { CoopFlowSafetyNotice() }
    }

    private var missingParameter: some View {
        Section {
            notice("cooperation.settlement.missingParam", "cooperation.settlement.missingParam.detail", id: "missingParam")
            CYPillButton("cooperation.settlement.back", style: .secondary) { dismiss() }
        }
    }
    @ViewBuilder private func failure(_ issue: Issue) -> some View {
        Section {
            switch issue {
            case .missingRecord:
                notice("cooperation.settlement.missingRecord", "cooperation.settlement.missingRecord.detail", id: "missingRecord")
                CYPillButton("cooperation.settlement.backToList", style: .secondary) { dismiss() }.accessibilityIdentifier("cooperation.settlement.backToList")
            case .permission(let message):
                notice("cooperation.settlement.failed", message == nil ? "cooperation.settlement.reload" : nil, verbatim: message, id: "permission")
            case .failed(let message):
                notice("cooperation.settlement.failed", message == nil ? "cooperation.settlement.failed.detail" : nil, verbatim: message, id: "failed")
                CYPillButton("cooperation.refresh", style: .secondary) { refresh = UUID() }.accessibilityIdentifier("cooperation.settlement.retry")
            }
        }
    }
    private func notice(_ title: String, _ detail: String?, verbatim: String? = nil, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            if let verbatim { Text(verbatim: verbatim).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            else if let detail { Text(LocalizedStringKey(detail)).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("cooperation.settlement.state.\(id)")
    }
    private func title(_ detail: CoopSettlementDetailModel) -> String {
        if let name = detail.topicName { return name }
        if let topic = detail.topicID, topic != 0 { return appLocalized("cooperation.finance.topicFallback \(topic)", locale: locale) }
        return appLocalized("cooperation.unnamedTopic", locale: locale)
    }
    private func valueText(_ value: CoopSettlementDetailModel.Value) -> String {
        switch value {
        case .money(let amount): return LocaleDisplay.money(amount, negative: false, locale: locale)
        case .heads(let count): return appLocalized("cooperation.settlement.value.heads \(count)", locale: locale)
        case .key(let key): return appLocalized(String.LocalizationValue(stringLiteral: "cooperation.settlement.value." + key), locale: locale)
        case .shareRate(let rate): return appLocalized("cooperation.settlement.value.shareRate \(NSDecimalNumber(decimal: rate).stringValue)", locale: locale)
        case .fixedFee(let fee): return appLocalized("cooperation.settlement.value.fixedFee \(CoopFinanceProfit.plainText(fee))", locale: locale)
        case .date(let text): return text
        case .unavailable: return "—"
        }
    }
    private func load() async {
        guard scenePhase == .active else { return }
        await model.load(reader: reader, source: source, id: id)
    }
}

/// `pages/coop/settlement-detail`. Club reads `POST api/club/settlement/summary` with `{clubId}`.
/// `personal: true` is sent only when the link asked for it. Finance and ledger keep their existing reads.
@MainActor struct CoopSettlementDetailRoute: View {
    let reader: any CoopFlowReading
    let query: [String: String]

    var body: some View {
        if let link = MerchantSettlementDetailLink.resolve(query) {
            switch link.source {
            case .finance: existing(.finance, link.recordID)
            case .ledger: existing(.mybiz, link.recordID)
            case .club:
                if let clubID = link.clubID {
                    CoopClubSettlementScreen(reader: reader, clubID: clubID, recordID: link.recordID, personal: link.personal,
                                             recordKey: link.recordKey)
                } else { missing }
            }
        } else { missing }
    }

    @ViewBuilder private func existing(_ source: CoopFlowSettlement.Source, _ recordID: String) -> some View {
        if let id = Self.positive(recordID) {
            CoopSettlementDetailView(reader: reader, source: source, id: id)
        } else { missing }
    }

    private var missing: some View {
        MerchantMissingParamState(title: LocalizedStringKey(MerchantSettlementDetailLink.missing))
    }

    private static func positive(_ raw: String) -> Int? {
        guard let id = Int(raw), id > 0, String(id) == raw else { return nil }
        return id
    }
}

/// One club settlement row (MC7-35-1 / MP `pages/coop/settlement-detail?source=club`): `POST api/club/settlement/summary`
/// (`CoopFlowRead.clubSettlementSummary`), rendered as the MP `buildClubSettlementDetail`. Amounts stay the server
/// strings from `CoopClubSettlementDetail`; nothing is computed here, and this read does not withdraw.
/// Round 3: the F-agent states (missing + 返回, failed + 重试, pull to refresh) and localized labels live here now;
/// the separate `CoopClubSettlementDetailView` is gone.
@MainActor struct CoopClubSettlementScreen: View {
    let reader: any CoopFlowReading
    let clubID: Int
    let recordID: String
    /// True only when the screen query is `personal=1`.
    let personal: Bool
    /// `MerchantSettlementDetailLink.recordKey`: `id` when the link named a club row id, else `topicId` (MP onLoad).
    var recordKey: String = "topicId"
    private enum Phase: Equatable { case loading, ready(CoopClubSettlementDetail), missing, failed(String?) }
    @State private var phase: Phase = .loading
    @State private var attempt = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .navigationTitle(Text("merchantCoop.settlement.title")).navigationBarTitleDisplayMode(.inline)
            .cyDomainScreen(.merchant)
            .task(id: "\(clubID)|\(recordID)|\(personal)|\(attempt)") { await load() }
            .refreshable { await load() }
            .accessibilityIdentifier("cooperation.settlement.club.\(clubID)")
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYSkeleton(variant: .detail).padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("cooperation.settlement.club.loading")
        case .missing:
            // MP settlement-detail wxml:31: cy-empty kind="empty" 结算记录不可见 + 返回结算列表.
            MerchantCoopActionState(systemImage: "doc.text.magnifyingglass", title: "merchantCoop.settlement.missing",
                                    actionTitle: "merchantCoop.settlement.backToList", action: { dismiss() },
                                    identifier: "cooperation.settlement.club.missing", emptyArt: true)
        case .failed(let message):
            MerchantCoopActionState(systemImage: "exclamationmark.triangle", title: "merchantCoop.settlement.failed",
                                    message: message.map { LocalizedStringKey(stringLiteral: $0) },
                                    actionTitle: "action.retry", action: { attempt += 1 },
                                    identifier: "cooperation.settlement.club.failed")
        case .ready(let detail):
            List {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: detail.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("merchantCoop.settlement.clubPerspective").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Text(verbatim: detail.amountLabel).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Text(verbatim: LocaleDisplay.yuanAmounts(in: detail.amountText, locale: locale)).cyText(.display, monospacedDigit: true).foregroundStyle(CYColor.textPrimary)
                        Text(verbatim: detail.statusText).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cooperation.settlement.club.hero")
                }
                Section {
                    line("merchantCoop.settlement.lineType", detail.lineTypeText)
                    line("merchantCoop.settlement.original", detail.originalAmountText)
                    line("merchantCoop.settlement.adjustment", detail.executedAdjustmentText)
                    line("merchantCoop.settlement.net", detail.netAmountText).fontWeight(.semibold)
                }
                Section {
                    line("merchantCoop.settlement.arrived", detail.arrivedText)
                    line("merchantCoop.settlement.paid", detail.paidText)
                }
            }
            .cyGroupedSurface()
            .accessibilityIdentifier("cooperation.settlement.club.detail")
        }
    }

    @ViewBuilder private func line(_ label: LocalizedStringKey, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent { Text(verbatim: LocaleDisplay.yuanAmounts(in: value, locale: locale)).monospacedDigit() } label: { Text(label) }
        }
    }

    private func load() async {
        if case .ready = phase {} else { phase = .loading }
        do {
            let value = try await reader.read(.clubSettlementSummary(clubID: clubID, personal: personal))
            let match = (value["topics"].rows ?? []).first { row in
                let raw = row[recordKey]
                return (raw.integer.map(String.init) ?? raw.text) == recordID
            }
            guard let match else { phase = .missing; return }
            guard let detail = CoopClubSettlementDetail.resolve(match) else { phase = .failed(nil); return }
            phase = .ready(detail)
        } catch CoopFlowFailure.server(_, let message) {
            phase = .failed(message)
        } catch {
            phase = .failed(nil)
        }
    }
}

struct CoopSettlementToneBadge: View {
    let status: CoopSettlementDetailModel.Status
    let tone: CoopSettlementDetailModel.Tone
    var body: some View {
        let mapped: CYMiniBadgeTone = tone == .success ? .accepted : tone == .warning ? .pending : tone == .danger ? .rejected : .muted
        CYMiniBadge(Text(LocalizedStringKey("cooperation.settlement.status." + status.rawValue)), tone: mapped)
            .accessibilityIdentifier("cooperation.settlement.status")
    }
}
