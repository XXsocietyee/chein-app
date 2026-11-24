import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// U08-04 "复报 · 分析适配入口": the B8 post-game outcome report scoped to the creator's own topics.
/// Owner rules: `mature=false` reads "not mature" (never 0%), a null count reads "—", watermarks, basis version and
/// computedAt are always shown, the report is marked as computed now, test data is never claimed excluded, and the
/// metrics the scoped report leaves out are listed as "not available", never as 0.
@MainActor struct CreatorPostGameOutcomeView: View {
    let service: CreatorStudioService
    let loadTopics: () async -> [CreatorStudioTopic]
    @State private var cohortDay = Date()
    @State private var windowDays = 30
    @State private var topicID: Int?
    @State private var topics: [CreatorStudioTopic] = []
    @State private var outcome: CreatorPostGameOutcome?
    @State private var failure: CreatorStudioFailure?
    @State private var loading = false
    @Environment(\.locale) private var locale

    private static let windows = [7, 14, 30, 60, 90]
    private var query: String { "\(CreatorOutcomePresentation.cohortDate(cohortDay))|\(windowDays)|\(topicID ?? 0)" }

    var body: some View {
        List {
            Section {
                DatePicker("creatorStudio.outcome.cohortDate", selection: $cohortDay, in: ...Date(), displayedComponents: .date)
                    .environment(\.timeZone, Calendar.shanghai.timeZone)
                    .accessibilityIdentifier("creatorStudio.outcome.cohortDate")
                Picker("creatorStudio.outcome.window", selection: $windowDays) {
                    ForEach(Self.windows, id: \.self) { Text("creatorStudio.outcome.days \($0)").tag($0) }
                }.accessibilityIdentifier("creatorStudio.outcome.window")
                Picker("creatorStudio.outcome.topic", selection: $topicID) {
                    Text("creatorStudio.outcome.allTopics").tag(Int?.none)
                    ForEach(scopeTopics) { topic in Text(verbatim: topic.title ?? "#\(topic.id)").tag(Optional(topic.id)) }
                }.accessibilityIdentifier("creatorStudio.outcome.topic")
            } footer: { Text("creatorStudio.outcome.definition") }
            if loading && outcome == nil { Section { CYLoadingStateView(rows: 4) } }
            else if let outcome { report(outcome) }
            else { Section { CreatorStudioIssueView(failure: failure) { Task { await load() } } } }
        }
        .appNavigationTitle("creatorStudio.outcome.title").navigationBarTitleDisplayMode(.inline)
        .task { topics = await loadTopics() }
        .task(id: query) { await load() }
        .refreshable { await load() }
        .cyDomainScreen(.topicEditor)
    }

    /// The creator's topics named where known; ids the report scoped but the content list did not return stay selectable.
    private var scopeTopics: [CreatorStudioTopic] {
        guard let ids = outcome?.scope.topicIds, !ids.isEmpty else { return topics }
        return ids.map { id in topics.first { $0.id == id } ?? CreatorStudioTopic(id: id, title: nil) }
    }

    private func load() async {
        loading = true; defer { loading = false }
        let captured = query
        do {
            let value = try await service.postGameOutcome(cohortDate: CreatorOutcomePresentation.cohortDate(cohortDay),
                                                          windowDays: windowDays, topicID: topicID)
            guard captured == query else { return }
            outcome = value; failure = nil
        } catch {
            guard captured == query else { return }
            // A failed read never keeps an older report on screen as if it were this one.
            outcome = nil; failure = error as? CreatorStudioFailure
        }
    }

    @ViewBuilder private func report(_ outcome: CreatorPostGameOutcome) -> some View {
        let report = outcome.report
        Section {
            HStack {
                if report.mature { CYStatusChip("creatorStudio.outcome.mature", tone: .success, systemImage: "checkmark.seal") }
                else { CYStatusChip("creatorStudio.outcome.notMature", tone: .warning, systemImage: "hourglass") }
                Spacer()
            }.accessibilityIdentifier("creatorStudio.outcome.maturity")
            if !report.mature { Text("creatorStudio.outcome.notMatureBody").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            row("creatorStudio.outcome.windowStart", text: report.windowStart)
            row("creatorStudio.outcome.windowEnd", text: report.windowEnd)
            row("creatorStudio.outcome.scopeTopics", value: .value(String(outcome.scope.topicIds.count)))
        } header: { Text("creatorStudio.outcome.window") }

        if let cohort = report.cohort {
            Section {
                row("creatorStudio.outcome.retentionRate", value: CreatorOutcomePresentation.rate(cohort.retentionRate, mature: report.mature, locale: locale))
                row("creatorStudio.outcome.eligible", value: CreatorOutcomePresentation.count(cohort.eligibleMembers))
                row("creatorStudio.outcome.retained", value: CreatorOutcomePresentation.retained(cohort.retainedMembers, mature: report.mature))
                row("creatorStudio.outcome.notMatureMembers", value: CreatorOutcomePresentation.count(cohort.notMatureMembers))
                row("creatorStudio.outcome.freeMembers", value: CreatorOutcomePresentation.count(cohort.freeMembers))
                row("creatorStudio.outcome.freeRetentionRate", value: CreatorOutcomePresentation.rate(cohort.freeRetentionRate, mature: report.mature, locale: locale))
                row("creatorStudio.outcome.fullRefundExcluded", value: CreatorOutcomePresentation.count(cohort.fullRefundExcluded))
                row("creatorStudio.outcome.cancelledExcluded", value: CreatorOutcomePresentation.count(cohort.cancelledOrExpiredExcluded))
                row("creatorStudio.outcome.partialRefund", value: CreatorOutcomePresentation.count(cohort.partialRefundMembers))
                row("creatorStudio.outcome.pendingRefund", value: CreatorOutcomePresentation.count(cohort.pendingRefundMembers))
                row("creatorStudio.outcome.duplicateOrders", value: CreatorOutcomePresentation.count(cohort.duplicateOrdersCollapsed))
                row("creatorStudio.outcome.multiSeat", value: CreatorOutcomePresentation.count(cohort.multiSeatCollapsed))
                row("creatorStudio.outcome.lateFacts", value: CreatorOutcomePresentation.count(cohort.lateFactCount))
            } header: { Text("creatorStudio.outcome.cohort") } footer: { Text("creatorStudio.outcome.cohortFooter") }
        }

        if let signup = report.repeatSignupV1 {
            Section {
                if signup.available == false {
                    row("creatorStudio.outcome.repeatSignup", value: .dash)
                    if let reason = signup.unknownReason { Text(verbatim: reason).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                } else {
                    segment("creatorStudio.outcome.paid", signup.paid)
                    segment("creatorStudio.outcome.all", signup.all)
                }
            } header: { Text("creatorStudio.outcome.repeatSignup") }
        }

        Section {
            ForEach(CreatorOutcomePresentation.shownMetrics(outcome), id: \.metricCode) { metric in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    HStack {
                        Text(Self.metricName(metric.metricCode)).cyText(.cardTitle)
                        Spacer()
                        valueText(CreatorOutcomePresentation.count(metric.members))
                    }
                    HStack(spacing: CYSpacing.md) {
                        Text("creatorStudio.outcome.memberDays") + Text(verbatim: " ") + valueString(CreatorOutcomePresentation.count(metric.memberDays))
                        Text("creatorStudio.outcome.facts") + Text(verbatim: " ") + valueString(CreatorOutcomePresentation.count(metric.facts))
                    }.cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    HStack(spacing: CYSpacing.xs) {
                        Text("creatorStudio.outcome.watermark")
                        valueString(metric.watermarkAt.map { .value($0) } ?? .dash)
                    }.cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("creatorStudio.outcome.metric.\(metric.metricCode)")
            }
        } header: { Text("creatorStudio.outcome.metrics") } footer: { Text("creatorStudio.outcome.metricsFooter") }

        Section {
            ForEach(CreatorOutcomePresentation.omittedMetrics(outcome), id: \.self) { code in
                LabeledContent { Text("creatorStudio.outcome.notAvailable").foregroundStyle(CYColor.textTertiary) } label: { Text(Self.metricName(code)) }
                    .accessibilityIdentifier("creatorStudio.outcome.omitted.\(code)")
            }
            ForEach((report.unavailableSources ?? [:]).sorted(by: { $0.key < $1.key }), id: \.key) { source in
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    LabeledContent { Text("creatorStudio.outcome.notAvailable").foregroundStyle(CYColor.textTertiary) } label: { Text(verbatim: source.key) }
                    Text(verbatim: source.value).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            }
        } header: { Text("creatorStudio.outcome.omitted") } footer: { Text("creatorStudio.outcome.omittedFooter") }

        Section {
            row("creatorStudio.outcome.basisVersion", text: report.basisVersion)
            row("creatorStudio.outcome.computedAt", text: report.computedAt)
            ForEach(CreatorOutcomePresentation.watermarks(report), id: \.source) { mark in
                LabeledContent { valueText(mark.value).cyText(.meta) } label: { Text(verbatim: mark.source).cyText(.meta) }
            }
            if report.historicalReplayable != true { Text("creatorStudio.outcome.computedNow").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if report.testExclusionBasis == "NO_SERVER_MARKER" { Text("creatorStudio.outcome.testNotExcluded").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
        } header: { Text("creatorStudio.outcome.basis") }
    }

    @ViewBuilder private func segment(_ title: LocalizedStringKey, _ segment: CreatorPostGameOutcomeReport.RepeatSignup.Segment?) -> some View {
        if let segment {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack {
                    Text(title).cyText(.cardTitle)
                    Spacer()
                    // A segment rate is only shown for mature members; with none mature it is "not mature", not 0%.
                    valueText((segment.matureMembers ?? 0) > 0 ? CreatorOutcomePresentation.rate(segment.retentionRate, mature: true, locale: locale) : .notMature)
                }
                HStack(spacing: CYSpacing.md) {
                    Text("creatorStudio.outcome.eligible") + Text(verbatim: " ") + valueString(CreatorOutcomePresentation.count(segment.eligibleMembers))
                    Text("creatorStudio.outcome.matureMembers") + Text(verbatim: " ") + valueString(CreatorOutcomePresentation.count(segment.matureMembers))
                    Text("creatorStudio.outcome.retained") + Text(verbatim: " ") + valueString(CreatorOutcomePresentation.retained(segment.retainedMembers, mature: (segment.matureMembers ?? 0) > 0))
                }.cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, value: CreatorOutcomeValue) -> some View {
        LabeledContent { valueText(value) } label: { Text(title) }
    }

    private func row(_ title: LocalizedStringKey, text: String?) -> some View {
        row(title, value: text.map { .value($0) } ?? .dash)
    }

    private func valueText(_ value: CreatorOutcomeValue) -> some View {
        valueString(value).cyText(.numericBody).monospacedDigit()
    }

    private func valueString(_ value: CreatorOutcomeValue) -> Text {
        switch value {
        case .notMature: return Text("creatorStudio.outcome.notMatureValue")
        case .dash: return Text(verbatim: "—")
        case .value(let text): return Text(verbatim: text)
        }
    }

    static func metricName(_ code: String) -> LocalizedStringKey {
        switch code {
        case "OFFICIAL_COMPLETION": return "creatorStudio.metric.officialCompletion"
        case "SECOND_VALID_REGISTRATION": return "creatorStudio.metric.secondRegistration"
        case "REWARD_ISSUANCE": return "creatorStudio.metric.reward"
        case "PRIVATE_PHOTO": return "creatorStudio.metric.privatePhoto"
        case "PUBLIC_SHARE": return "creatorStudio.metric.publicShare"
        case "RECOMMENDATION_CLICK": return "creatorStudio.metric.recommendationClick"
        case "CLIENT_OBSERVED_EVENT": return "creatorStudio.metric.clientObserved"
        case CreatorOutcomePresentation.roamRevisit: return "creatorStudio.metric.roamRevisit"
        default: return LocalizedStringKey(stringLiteral: code)
        }
    }
}
