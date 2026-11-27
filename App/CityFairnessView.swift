import SwiftUI

/// Read-only CITY fairness. The host supplies the reader; this screen does not grant a write.
struct CityFairnessView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @State var reader: CityFairnessReader
    @State private var visible = false
    @State private var readRequest = UUID()
    private let table = "CityFairness"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader("fairness.title", tableName: table)
                screenBody
                if let failure = reader.refreshFailure { cloud06FairnessFailure(failure) }
                if reader.isConfigured {
                    NavigationLink(value: CityFairnessOutingRoute()) {
                        CYListRow(verbatim: cloud06Phrase("fairness.evidence", table: table, locale: locale), trailing: .chevron) {
                            CYRowIcon(systemImage: "list.bullet.rectangle")
                        }
                    }
                    .questifyHidesLinkIndicator()
                    .accessibilityIdentifier("fairness.outing.own")
                    .accessibilityLabel(Text("fairness.evidence", tableName: table))
                    CYPillButton("fairness.refresh", style: .primary, systemImage: "arrow.clockwise", tableName: table) { readRequest = UUID() }
                        .disabled(!visible || scenePhase != .active)
                        .accessibilityLabel(Text("fairness.refresh", tableName: table))
                    if case .mature(let page) = reader.screen, page.nextCursor != nil {
                        CYPillButton("fairness.next", style: .secondary, tableName: table) { Task { await reader.nextPage() } }
                            .disabled(reader.refreshing || !visible || scenePhase != .active)
                            .accessibilityLabel(Text("fairness.next", tableName: table))
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
        .roleTheme(.player)
        .accessibilityIdentifier("fairness.screen")
        .navigationDestination(for: CityFairnessOutingRoute.self) { _ in
            CityFairnessEvidenceView(reader: reader)
        }
        .task(id: readRequest) {
            guard visible, scenePhase == .active, !Task.isCancelled else { return }
            await reader.restoreSameQuery()
        }
        .onAppear { visible = true; reader.setForeground(scenePhase == .active); readRequest = UUID() }
        .onChange(of: scenePhase) { _, phase in
            reader.setForeground(phase == .active)
            if phase == .active { readRequest = UUID() }
        }
        .onDisappear { visible = false; reader.setForeground(false) }
    }

    @ViewBuilder private var screenBody: some View {
        switch reader.screen {
        case .blocked:
            CYEmptyState(systemImage: "lock.shield", "fairness.blocked", tableName: table, kind: .failure)
        case .loading:
            loadingBlock
        case .notComputable(let missing, let gaps):
            CYEmptyState(systemImage: "chart.bar.xaxis", "fairness.notComputable", tableName: table)
            if !missing.isEmpty { reasonLine(missing.joined(separator: "\n")) }
            CityFairnessFactsBlock(gaps: gaps, facts: [])
        case .noMatureSample(let gap):
            CYEmptyState(systemImage: "chart.bar.xaxis", "fairness.noMatureSample", tableName: table)
            stamp(gap.asOf, metricVersion: gap.metricVersion, formulaId: gap.formulaId, factRevision: gap.factRevision)
            if !gap.missing.isEmpty { reasonLine(gap.missing.joined(separator: "\n")) }
            CityFairnessFactsBlock(gaps: gap.coverageGaps, facts: gap.facts)
        case .unknown(let reason, let gaps):
            CYEmptyState(systemImage: "questionmark.circle", "fairness.unknown", tableName: table)
            if let reason { reasonLine(reason) }
            CityFairnessFactsBlock(gaps: gaps, facts: [])
        case .failed(let failure):
            cloud06FairnessFailure(failure)
        case .mature(let page):
            ratioBlock(page)
            stamp(page.asOf, metricVersion: page.metricVersion, formulaId: page.formulaId, factRevision: page.factRevision)
            if !page.missing.isEmpty { reasonLine(page.missing.joined(separator: "\n")) }
            CityFairnessFactsBlock(gaps: page.coverageGaps, facts: page.facts)
            CYNoteBanner(text: Text("fairness.readOnly", tableName: table), symbol: "eye")
            if page.members.isEmpty {
                CYEmptyState(systemImage: "figure.walk", "fairness.emptyEvidence", tableName: table)
            }
            ForEach(page.members) { member in
                CYListRow(verbatim: cloud06Shown(member.outingId), meta: cloud06Phrase("fairness.t0", table: table, locale: locale), trailing: .value(member.t0.map { String($0) } ?? "—"), card: true) {
                    CYRowIcon(systemImage: "figure.walk")
                }
            }
        }
    }

    private var loadingBlock: some View {
        ProgressView { Text("fairness.loading", tableName: table) }
            .frame(maxWidth: .infinity)
    }

    private func ratioBlock(_ page: CityFairnessPage) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(page.showsRatio ? "fairness.ratio" : "fairness.unknown", tableName: table)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: page.showsRatio ? page.ratioText : "—")
                .cyText(.dataXL)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func reasonLine(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("fairness.missingReason", tableName: table)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
            Text(verbatim: cloud06Shown(reason))
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func stamp(_ asOf: Int64, metricVersion: String?, formulaId: String, factRevision: Int64?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYFactRow(label: Text("fairness.asOf", tableName: table), value: String(asOf))
            CYFactRow(label: Text("fairness.metricVersion", tableName: table), value: metricVersion.map(cloud06Shown) ?? "—")
            CYFactRow(label: Text("fairness.formulaId", tableName: table), value: cloud06Shown(formulaId))
            CYFactRow(label: Text("fairness.factRevision", tableName: table), value: factRevision.map { String($0) } ?? "—")
        }
    }
}

struct CityFairnessOutingRoute: Hashable {}

struct CityFairnessEvidenceView: View {
    var reader: CityFairnessReader
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private let table = "CityFairness"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("fairness.evidence", tableName: table)
                evidenceBody
                if reader.outingPage != nil {
                    if reader.outingPage?.nextCursor != nil {
                        CYPillButton("fairness.next", style: .secondary, tableName: table) { Task { await reader.nextOutings() } }
                            .disabled(reader.outingRefreshing)
                            .accessibilityLabel(Text("fairness.next", tableName: table))
                    }
                    CYPillButton("fairness.refresh", style: reader.outingRefreshing ? .secondary : .primary, systemImage: "arrow.clockwise", tableName: table) { Task { await reader.loadOutings() } }
                        .disabled(reader.outingRefreshing)
                        .accessibilityLabel(Text("fairness.refresh", tableName: table))
                    CYPillButton("fairness.back", style: reader.outingRefreshing ? .primary : .secondary, tableName: table) { dismiss() }
                        .accessibilityIdentifier("fairness.back")
                        .accessibilityLabel(Text("fairness.back", tableName: table))
                } else {
                    CYPillButton("fairness.back", style: .primary, tableName: table) { dismiss() }
                        .accessibilityIdentifier("fairness.back")
                        .accessibilityLabel(Text("fairness.back", tableName: table))
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainPageBackground()
        .cyHeroScreen()
        .roleTheme(.player)
        .accessibilityIdentifier("fairness.evidence.screen")
        .task { await reader.loadOutings() }
    }

    @ViewBuilder private var evidenceBody: some View {
        if let page = reader.outingPage {
            CYNoteBanner(text: Text("fairness.readOnly", tableName: table), symbol: "eye")
            if page.maturity == "UNKNOWN" {
                CYNoteBanner(text: Text("fairness.unknown", tableName: table), symbol: "questionmark", tone: .warning)
            }
            if !page.missing.isEmpty { reasonLine(page.missing.joined(separator: "\n")) }
            CityFairnessFactsBlock(gaps: page.coverageGaps, facts: page.facts)
            if page.outings.isEmpty {
                CYEmptyState(systemImage: "figure.walk", "fairness.emptyEvidence", tableName: table)
            }
            ForEach(page.outings) { outing in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYListRow(verbatim: cloud06Shown(outing.outingId), trailing: .none) { CYRowIcon(systemImage: "figure.walk") }
                    CYFactRow(label: Text("fairness.maturity", tableName: table), value: maturityText(outing.maturity))
                    CYFactRow(label: Text("fairness.reason", tableName: table), value: cloud06FairnessReason(outing.reason, locale: locale))
                    CYFactRow(label: Text("fairness.t0", tableName: table), value: outing.t0.map { String($0) } ?? "—")
                }
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                .accessibilityIdentifier("fairness.outing.\(outing.outingId)")
            }
            if let failure = reader.outingFailure { cloud06FairnessFailure(failure) }
        } else if reader.outingBlocked {
            CYEmptyState(systemImage: "lock.shield", "fairness.blocked", tableName: table, kind: .failure)
        } else if let failure = reader.outingFailure {
            cloud06FairnessFailure(failure)
        } else {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("fairness.loading", tableName: table)
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYSkeleton().accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func maturityText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "UNKNOWN" { return cloud06Phrase("fairness.unknown", table: table, locale: locale) }
        return trimmed
    }

    private func reasonLine(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("fairness.missingReason", tableName: table)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
            Text(verbatim: cloud06Shown(reason))
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CityFairnessFactsBlock: View {
    let gaps: [String]
    let facts: [CityFairnessFact]
    @Environment(\.locale) private var locale
    private let table = "CityFairness"
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("fairness.coverage", tableName: table)
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(gaps.enumerated()), id: \.offset) { _, gap in
                CYListRow(verbatim: cloud06Shown(gap), meta: cloud06Phrase("fairness.unknown", table: table, locale: locale), trailing: .none) {
                    CYRowIcon(systemImage: "questionmark")
                }
            }
            ForEach(facts) { fact in
                CYFactRow(label: Text(verbatim: cloud06Shown(fact.name)), value: factValue(fact))
            }
        }
    }
    private func factValue(_ fact: CityFairnessFact) -> String {
        if let count = fact.count { return String(count) }
        if let text = fact.text { return cloud06Shown(text) }
        return "—"
    }
}

@ViewBuilder private func cloud06FairnessFailure(_ failure: CityFairnessFailure) -> some View {
    CYNoteBanner(text: Text(cloud06FairnessFailureKey(failure), tableName: "CityFairness"), symbol: "exclamationmark.triangle", tone: .danger)
}

private func cloud06FairnessFailureKey(_ failure: CityFairnessFailure) -> LocalizedStringKey {
    switch failure {
    case .unauthorized: "fairness.unauthorized"
    case .forbidden: "fairness.forbidden"
    case .notComputable: "fairness.notComputable"
    case .unavailable: "fairness.unavailable"
    case .malformed: "fairness.malformed"
    case .unknown: "fairness.unknown"
    }
}

private func cloud06FairnessReason(_ reason: CityFairnessOutingReason, locale: Locale) -> String {
    switch reason {
    case .firstOuting: return ChannelCopy.text("首次外出", "First outing", locale: locale)
    case .secondOuting: return ChannelCopy.text("第二次外出", "Second outing", locale: locale)
    case .insideDelta: return ChannelCopy.text("窗口内", "Inside the window", locale: locale)
    case .afterHorizon: return ChannelCopy.text("超过期限", "After the horizon", locale: locale)
    case .beforeT0: return ChannelCopy.text("起点之前", "Before the start", locale: locale)
    case .notEffective: return ChannelCopy.text("尚未生效", "Not effective", locale: locale)
    case .unknown: return cloud06Phrase("fairness.unknown", table: "CityFairness", locale: locale)
    }
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
