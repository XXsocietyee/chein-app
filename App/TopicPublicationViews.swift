import SwiftUI

/// U03 publish clarity strings live in `Resources/PublishClarity.xcstrings`.
enum PublishClarityText {
    static let table = "PublishClarity"
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: String.LocalizationValue(key), table: table, locale: locale)
    }
    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        String(format: string(key, locale: locale), locale: locale, arguments: arguments)
    }
    static func whereText(_ value: TopicPublishIssueWhere, locale: Locale) -> String? {
        switch value {
        case .stop(let chapter?, let stop): return format("where.stopInChapter", locale: locale, chapter, stop)
        case .stop(nil, let stop): return format("where.stop", locale: locale, stop)
        case .chapterTitle(let title): return format("where.chapter", locale: locale, title)
        case .chapterNumber(let number): return format("where.chapterNumber", locale: locale, number)
        case .tickets: return string("where.tickets", locale: locale)
        case .story: return string("where.story", locale: locale)
        case .topicSettings: return string("where.topicSettings", locale: locale)
        case .unlocated: return nil
        }
    }
    static func tone(_ headline: TopicPublicationHeadline) -> CYStatusTone {
        switch headline {
        case .rejected: return .danger
        case .inReview, .publicAwaitingReview: return .warning
        case .live: return .success
        case .listedPublic: return .info
        case .draft, .approvedHidden, .listedOffline, .ended, .unknown: return .neutral
        }
    }
    /// native r2: the tone as a system colour for the headline's SF Symbol.
    static func color(_ headline: TopicPublicationHeadline) -> Color {
        switch tone(headline) {
        case .danger: return .red
        case .warning: return .orange
        case .success: return .green
        case .info, .rare: return .accentColor
        case .neutral: return .secondary
        }
    }
    static func icon(_ headline: TopicPublicationHeadline) -> String {
        switch headline {
        case .rejected: return "xmark.octagon"
        case .inReview, .publicAwaitingReview: return "hourglass"
        case .live: return "checkmark.seal"
        case .listedPublic: return "eye"
        case .draft: return "pencil"
        case .approvedHidden, .listedOffline: return "eye.slash"
        case .ended: return "flag.checkered"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// One status chip for the result page, the status page and the project list.
@MainActor struct TopicPublicationHeadlineChip: View {
    @Environment(\.locale) private var locale
    let headline: TopicPublicationHeadline
    var body: some View {
        Label {
            Text(verbatim: PublishClarityText.string(headline.titleKey, locale: locale))
        } icon: {
            Image(systemName: PublishClarityText.icon(headline))
                .foregroundStyle(PublishClarityText.color(headline))
        }
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("publishClarity.headline." + headline.rawValue)
    }
}

// MARK: - U03-02 publish result

/// Immediate publish acknowledgment → headline and the next step in the server's words.
/// Visible-while-reviewing reads "public, review pending", never "approved".
@MainActor struct TopicPublishResultSummary: View {
    @Environment(\.locale) private var locale
    let acknowledgment: ProjectEditBundleAcknowledgment
    var body: some View {
        let headline = TopicPublicationHeadline.of(acknowledgment)
        let next = TopicPublishNextStep.of(acknowledgment)
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            TopicPublicationHeadlineChip(headline: headline)
            Text("result.nextStep", tableName: PublishClarityText.table)
                .font(.caption).foregroundStyle(.secondary)
            Group {
                if let text = next.serverText { Text(verbatim: text) }
                else if let key = next.fallbackKey { Text(LocalizedStringKey(key), tableName: PublishClarityText.table) }
            }
            .font(.body).foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("publishClarity.result.nextStep")
            if let revision = acknowledgment.contentRevisionNo {
                Text(verbatim: PublishClarityText.format("result.revision", locale: locale, revision))
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("publishClarity.result.revision")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("publishClarity.result")
    }
}

// MARK: - five-fact status (U03-02 / U03-03 / U03-04 creator side)

/// Read-only `publish-status`. Reading never publishes again; a failed read stays "not read",
/// never a guessed state. Review and sale facts are shown as the server words them.
@MainActor struct TopicPublicationStatusPanel: View {
    enum Phase: Equatable { case idle, loading, failed, loaded(TopicPublicationStatus) }
    @Environment(\.locale) private var locale
    let topicID: Int
    let load: @MainActor () async throws -> TopicPublicationStatus
    @State private var phase: Phase = .idle
    @State private var token = UUID()
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            switch phase {
            case .idle, .loading:
                Text("status.reading", tableName: PublishClarityText.table)
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("publishClarity.status.loading")
            case .failed:
                Text("status.failed", tableName: PublishClarityText.table)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("publishClarity.status.failed")
            case .loaded(let status):
                TopicPublicationHeadlineChip(headline: .of(status))
                ForEach(Array(TopicPublicationFactRow.rows(status).enumerated()), id: \.offset) { _, row in
                    TopicPublicationFactRowView(row: row)
                }
                Text("status.gate", tableName: PublishClarityText.table)
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { Task { await read() } } label: {
                Text(LocalizedStringKey(phase == .idle || phase == .loading ? "status.read" : "status.refresh"), tableName: PublishClarityText.table)
            }
            .buttonStyle(.bordered)
            .disabled(phase == .loading)
            .accessibilityIdentifier("publishClarity.status.refresh")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("publishClarity.status")
        .task(id: topicID) { await read() }
    }
    private func read() async {
        let current = UUID(); token = current; phase = .loading
        do {
            let status = try await load()
            guard token == current, !Task.isCancelled else { return }
            phase = .loaded(status)
        } catch {
            guard token == current, !Task.isCancelled else { return }
            phase = .failed
        }
    }
}

@MainActor struct TopicPublicationFactRowView: View {
    @Environment(\.locale) private var locale
    let row: TopicPublicationFactRow
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            switch row {
            case .editable(let value, let reason):
                line("fact.editable", value: value, id: "editable")
                if value == .no { reasonText(reason, fallback: "fact.noReason") }
            case .review(let state, let label, let passed, let auditTaskID, let detail):
                LabeledContent {
                    Text(verbatim: reviewText(state: state, label: label)).foregroundStyle(.primary)
                } label: { Text("fact.review", tableName: PublishClarityText.table) }
                    .accessibilityIdentifier("publishClarity.fact.review")
                line("fact.reviewPassed", value: passed, id: "reviewPassed")
                if let auditTaskID {
                    Text(verbatim: PublishClarityText.format("fact.auditTask", locale: locale, auditTaskID))
                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
                if let detail, !detail.isEmpty { reasonText(detail, fallback: nil) }
            case .visible(let value, let reason):
                line("fact.visible", value: value, id: "visible")
                if value == .no { reasonText(reason, fallback: nil) }
            case .sale(let value, let awaitingReview, let nextStep, let blockReason):
                line("fact.onSale", value: value, id: "onSale")
                if awaitingReview == .yes {
                    Text("fact.commercialReview", tableName: PublishClarityText.table)
                        .font(.subheadline).foregroundStyle(CYColor.warningText)
                }
                if value == .no { reasonText(blockReason, fallback: nil) }
                if let nextStep, !nextStep.isEmpty {
                    Text(verbatim: PublishClarityText.format("fact.nextStep", locale: locale, nextStep))
                        .font(.subheadline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("publishClarity.fact.saleNextStep")
                }
            case .playable(let value, let reason, let version, let beta):
                line("fact.playable", value: value, id: "playable")
                if value == .no { reasonText(reason, fallback: nil) }
                if let version {
                    Text(verbatim: PublishClarityText.format("fact.publishedVersion", locale: locale, version))
                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
                if beta { Text("fact.beta", tableName: PublishClarityText.table).font(.footnote).foregroundStyle(.secondary) }
            }
        }
    }
    private func line(_ key: String, value: TopicPublicationFactRow.Value, id: String) -> some View {
        LabeledContent {
            Text(LocalizedStringKey(valueKey(value)), tableName: PublishClarityText.table)
                .foregroundStyle(value == .unknown ? Color.secondary : Color.primary)
        } label: { Text(LocalizedStringKey(key), tableName: PublishClarityText.table) }
            .accessibilityIdentifier("publishClarity.fact." + id)
    }
    private func valueKey(_ value: TopicPublicationFactRow.Value) -> String {
        switch value { case .yes: return "value.yes"; case .no: return "value.no"; case .unknown: return "value.unknown" }
    }
    @ViewBuilder private func reasonText(_ text: String?, fallback: String?) -> some View {
        if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            Text(verbatim: text).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let fallback {
            Text(LocalizedStringKey(fallback), tableName: PublishClarityText.table)
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private func reviewText(state: String?, label: String?) -> String {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty { return label }
        switch state {
        case "DRAFT": return PublishClarityText.string("review.draft", locale: locale)
        case "PENDING": return PublishClarityText.string("review.pending", locale: locale)
        case "ESCALATED": return PublishClarityText.string("review.escalated", locale: locale)
        case "PASSED": return PublishClarityText.string("review.passed", locale: locale)
        case "REJECTED": return PublishClarityText.string("review.rejected", locale: locale)
        case "AWAITING": return PublishClarityText.string("review.awaiting", locale: locale)
        default: return PublishClarityText.string("value.unknown", locale: locale)
        }
    }
}

/// Editor section: current five-fact status for the loaded topic (creator side, read-only).
@MainActor struct TopicPublicationStatusSection: View {
    @ObservedObject var model: ProjectEditModel
    var body: some View {
        // Hidden, not "unavailable", when this backend does not serve publish-status (China production today).
        if let topicID = model.coordinator.publicationTopicID, model.coordinator.session != nil,
           model.coordinator.supportsPublicationStatus {
            Section {
                TopicPublicationStatusPanel(topicID: topicID) { try await model.coordinator.readPublicationStatus(topicID: topicID) }
                    .id(model.editorIncarnation)
            } header: { Text("status.title", tableName: PublishClarityText.table) }
        }
    }
}

// MARK: - U03-01 server publish check

@MainActor final class TopicPublishCheckController: ObservableObject {
    enum Phase: Equatable { case idle, loading, unavailable, failed, loaded(TopicPublishCheckReport) }
    @Published private(set) var phase: Phase = .idle
    private var token = UUID()
    private var incarnation: UUID?
    func run(_ model: ProjectEditModel) async {
        guard let topicID = model.coordinator.snapshot?.topicID, model.coordinator.supportsPublishCheck else { phase = .unavailable; return }
        let current = UUID(), owner = model.editorIncarnation
        token = current; phase = .loading
        do {
            let report = try await model.coordinator.readPublishCheck(topicID: topicID)
            guard token == current, model.editorIncarnation == owner else { return }
            incarnation = owner; phase = .loaded(report)
        } catch {
            guard token == current else { return }
            phase = .failed
        }
    }
    /// A report from another editor incarnation or topic is never shown as current.
    func report(for model: ProjectEditModel) -> TopicPublishCheckReport? {
        guard case .loaded(let report) = phase, incarnation == model.editorIncarnation,
              report.topicID == model.coordinator.snapshot?.topicID else { return nil }
        return report
    }
}

@MainActor struct TopicPublishCheckSection: View {
    @ObservedObject var model: ProjectEditModel
    @StateObject private var controller = TopicPublishCheckController()
    @Environment(\.locale) private var locale
    var body: some View {
        if model.coordinator.snapshot?.topicID != nil {
            let report = controller.report(for: model)
            Section {
                ForEach(TopicVerificationStage.allCases, id: \.self) { stage in
                    let state = TopicVerificationSummary.state(stage, report: report)
                    LabeledContent {
                        Text(LocalizedStringKey("verify.state." + state.rawValue), tableName: PublishClarityText.table)
                            .foregroundStyle(state == .blocked ? CYColor.dangerText : state == .passed ? CYColor.successText : Color.secondary)
                    } label: { Text(LocalizedStringKey("verify.stage." + stage.rawValue), tableName: PublishClarityText.table) }
                        .accessibilityIdentifier("publishClarity.verify." + stage.rawValue)
                }
                switch controller.phase {
                case .idle:
                    Text("check.hint", tableName: PublishClarityText.table).font(.footnote).foregroundStyle(.secondary)
                case .loading:
                    Text("check.loading", tableName: PublishClarityText.table).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("publishClarity.check.loading")
                case .unavailable:
                    Text("check.unavailable", tableName: PublishClarityText.table).font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("publishClarity.check.unavailable")
                case .failed:
                    Text("check.failed", tableName: PublishClarityText.table).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("publishClarity.check.failed")
                case .loaded:
                    if let report { loaded(report) }
                    else { Text("check.stale", tableName: PublishClarityText.table).font(.footnote).foregroundStyle(.secondary) }
                }
                Button { Task { await controller.run(model) } } label: {
                    Text(LocalizedStringKey(report == nil ? "check.run" : "check.rerun"), tableName: PublishClarityText.table)
                }
                .disabled(controller.phase == .loading || model.coordinator.session == nil)
                .accessibilityIdentifier("publishClarity.check.run")
            } header: { Text("check.title", tableName: PublishClarityText.table) }
        }
    }
    @ViewBuilder private func loaded(_ report: TopicPublishCheckReport) -> some View {
        let saved = model.coordinator.snapshot.flatMap { ProjectEditPendingMaterials.exactData($0.draft) }
        let matches = saved != nil && saved == ProjectEditPendingMaterials.exactData(model.draft)
        switch TopicPublishCheckAgreement.of(report, localIssueCount: model.coordinator.issues.count, draftMatchesSaved: matches) {
        case .agrees: EmptyView()
        case .savedVersionDiffers: notice("check.agreement.savedVersionDiffers")
        case .serverOnlyBlocks: notice("check.agreement.serverOnly")
        case .localOnlyBlocks: notice("check.agreement.localOnly")
        }
        if report.issues.isEmpty {
            Text("check.clean", tableName: PublishClarityText.table).font(.subheadline).foregroundStyle(.primary)
                .accessibilityIdentifier("publishClarity.check.clean")
        }
        ForEach(report.blocking + report.advisory) { issue in issueRow(issue) }
    }
    private func notice(_ key: String) -> some View {
        Label { Text(LocalizedStringKey(key), tableName: PublishClarityText.table).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: "arrow.triangle.2.circlepath") }
            .font(.subheadline).foregroundStyle(CYColor.warningText)
            .accessibilityIdentifier("publishClarity.check.agreement")
    }
    @ViewBuilder private func issueRow(_ issue: TopicPublishCheckIssue) -> some View {
        let label = issueLabel(issue)
        if model.canEdit, let location = issue.location(in: model.draft) {
            switch location {
            case .chapter(let id, let anchor):
                NavigationLink { ProjectEditChapterView(model: model, chapterID: id, initialIssueAnchor: anchor) } label: { label }
                    .accessibilityIdentifier("publishClarity.issue.\(issue.id)")
            case .node(let chapterID, let nodeID, let anchor):
                NavigationLink { ProjectEditNodeView(model: model, chapterID: chapterID, nodeID: nodeID, initialIssueAnchor: anchor) } label: { label }
                    .accessibilityIdentifier("publishClarity.issue.\(issue.id)")
            case .ticket(let id, let anchor):
                NavigationLink { ProjectEditTicketView(model: model, ticketID: id, initialIssueAnchor: anchor) } label: { label }
                    .accessibilityIdentifier("publishClarity.issue.\(issue.id)")
            case .root:
                label.accessibilityIdentifier("publishClarity.issue.\(issue.id)")
            }
        } else {
            label.accessibilityIdentifier("publishClarity.issue.\(issue.id)")
        }
    }
    private func issueLabel(_ issue: TopicPublishCheckIssue) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if let place = PublishClarityText.whereText(.of(issue), locale: locale) {
                Text(verbatim: place).font(.footnote).foregroundStyle(.secondary)
            }
            Label { Text(verbatim: issue.message).fixedSize(horizontal: false, vertical: true) }
                icon: { Image(systemName: issue.blocks ? "exclamationmark.circle" : "info.circle") }
                .foregroundStyle(issue.blocks ? CYColor.dangerText : Color.primary)
            Text(LocalizedStringKey(issue.blocks ? "check.level.error" : "check.level.warn"), tableName: PublishClarityText.table)
                .font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - U03-03 My projects topic line

@MainActor struct MyProjectTopicFactLine: View {
    let project: CreatorContentProject
    var body: some View {
        if let fact = MyProjectTopicFact.of(project) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                TopicPublicationHeadlineChip(headline: fact.headline)
                if fact.headline == .listedPublic || fact.headline == .listedOffline {
                    Text("list.reviewOnStatusPage", tableName: PublishClarityText.table)
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let key = fact.editScopeNoticeKey {
                    Text(LocalizedStringKey(key), tableName: PublishClarityText.table)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("publishClarity.list.editScope.\(project.sourceID)")
                }
            }
            .accessibilityIdentifier("publishClarity.list.\(project.sourceID)")
        }
    }
}
