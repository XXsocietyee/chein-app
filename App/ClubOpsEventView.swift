import SwiftUI

/// Mini pages/club/event-ops hub. It only orders existing governance reads; each pushed
/// read re-checks access/me and owns its own writes, review/confirm and return reads.
@MainActor struct ClubOpsEventView: View {
    @Environment(\.locale) private var locale
    let scope: ClubGovernanceScope
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    struct Key: Equatable {
        let identity: ClubReadIdentity?
        let authorization: UUID?
        let reader: ObjectIdentifier
        let scope: ClubGovernanceScope
    }
    @State private var model: ClubOpsEventAccess?
    @State private var loadedKey: Key?
    @State private var failure: ClubGovernanceFailure?
    @State private var loading = false
    @State private var generation: UInt64 = 0
    /// CLB-event-ops-02 (MP event-ops wxml:26-113): 本场 cancel status and the roster total, read inline on the hub.
    /// Best effort: a failed read leaves the plain rows, which still open the full pages.
    @State private var occurrenceStatus: ClubGovernanceValue?
    @State private var rosterTotal: Int?
    @State private var rosterSnapshot: ClubGovernanceSnapshot?
    @State private var rosterTab: ClubRosterBucket = .registered
    /// CLB-G15 (MP event-ops wxml:119-120): no topic to open a session for and no series yet.
    @State private var publishEmpty = false
    /// CLB-G15 (MP event-ops js:499-503 `goPublishTopic` → pages/publish/fabu/index?clubId): the extras section's 发布主题.
    @State private var publishTopicOpen = false
    /// CLB-r9-event-ops-01 (MP event-ops topic dropdown): the hub's eventTopics read feeds an inline topic menu;
    /// 添加日期 opens the picked topic first (ClubOpsEventAccess.focusFirst on the pushed list).
    @State private var topicFacts: [ClubOpsEventTopicFact] = []
    @State private var pickedTopicID: Int?
    private var key: Key { .init(identity: identity, authorization: access.authorizationGeneration, reader: ObjectIdentifier(access), scope: scope) }
    private var accessScope: ClubGovernanceScope { .init(clubID: scope.clubID, activityID: scope.activityID) }
    private var eventScope: ClubGovernanceScope { .init(clubID: scope.clubID, topicID: scope.topicID, activityID: scope.activityID) }
    private var isDenied: Bool { failure == .forbidden || (loadedKey == key && model?.permitted == false) }
    var body: some View {
        List {
            // CLB-event-ops-04 (parity r2): a utility page; inline bar title, no hero or decorative art.
            if !loading, !isDenied, failure == nil, (scope.clubID ?? 0) > 0, loadedKey == key, let model {
                ForEach(model.sections, id: \.self) { section in self.section(section, model: model) }
            }
        }
        .overlay {
            if loading {
                ProgressView()
                    .accessibilityIdentifier("clubOpsEvent.loading")
            } else if isDenied {
                denied
            } else if (scope.clubID ?? 0) <= 0 {
                // CLB-event-ops-05 (MP event-ops wxml:12, js:479): no clubId is `missing-param` → 链接已失效 + 返回.
                MemberMissingLinkState(identifier: "clubOpsEvent.missingParam")
            } else if let failed = failure {
                // CLB-event-ops-05 (MP wxml:17-18): the failure title, then 重新加载.
                ContentUnavailableView {
                    Label {
                        Text(verbatim: ClubOpsNetworkFailureClassifier.eventOpsHubTitle(failed))
                            .accessibilityIdentifier("clubOpsEvent.error")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } actions: {
                    Button("action.reload") { Task { await load() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("clubOpsEvent.retry")
                }
            }
        }
        .navigationTitle(Text("clubOpsEvent.title", tableName: "ClubOpsEvent"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("clubOpsEvent.root")
        .task(id: key) { await load() }
        .refreshable { await load() }
        .navigationDestination(isPresented: $publishTopicOpen) { publishTopicPage }
    }
    /// CLB-G15 (MP event-ops js:499-503): `wx.navigateTo('/pages/publish/fabu/index?clubId=' + clubId)`.
    @ViewBuilder private var publishTopicPage: some View {
        if let clubID = scope.clubID {
            MPReviewedPageScreen(page: "pages/publish/fabu/index", query: ["clubId": String(clubID)])
        }
    }
    private var denied: some View {
        ContentUnavailableView {
            Label {
                Text("clubOpsEvent.denied.title", tableName: "ClubOpsEvent")
            } icon: {
                Image(systemName: "lock")
            }
        } description: {
            Text("clubOpsEvent.denied.body", tableName: "ClubOpsEvent")
        }
        .accessibilityIdentifier("clubOpsEvent.denied")
    }
    @ViewBuilder private func section(_ section: ClubOpsEventSection, model: ClubOpsEventAccess) -> some View {
        switch section {
        case .occurrence:
            Section {
                if model.rosterHiddenForManager {
                    Label {
                        Text("clubOpsEvent.roster.hidden", tableName: "ClubOpsEvent")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "eye.slash").accessibilityHidden(true)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("clubOpsEvent.roster.hidden")
                }
                if let occurrenceStatus, ClubOpsEventCancellation.state(occurrenceStatus, activityID: scope.activityID) != nil {
                    ClubOpsEventOccurrenceStatusRows(value: occurrenceStatus, activityID: scope.activityID)
                }
                push(.occurrenceStatus, eventScope) {
                    // CLB-event-ops-07: the consequence lives in the confirm only (MP 1121), not on the row.
                    Label("club.gov.action.cancelOccurrence", systemImage: "calendar.badge.minus")
                }
            } header: { Text("clubOpsEvent.section.occurrence", tableName: "ClubOpsEvent") }
            // CLB-G15 (MP event-ops wxml:39-43): 主持小费 · 暂不可开通 under 本场管理 (collection channel not enabled, so no
            // switch or ratio). paymentNotice sits in the series form and windowWarning on its receipt (r9, as in the MP).
            // The extras CTA stays off here (`showsEmptyPublishCTA: false`) because the MP shows it in the 日期清单 slot;
            // its tap is still wired to the same fabu push so the hook is never a no-op.
            ClubGapEventOpsExtrasSection(showsEmptyPublishCTA: false, onTapPublishTopic: { publishTopicOpen = true })
            // The empty 发布主题 state sits in the 日期清单 slot (`case .series where publishEmpty`).
        case .roster:
            Section {
                push(.roster, eventScope) {
                    // CLB-event-ops-02 (MP wxml:72): 本场名册 · N 人 once the roster read is in (registered + arrived + noShow).
                    Label {
                        Text(verbatim: rosterTotal.map { String(localized: LocalizedStringResource("clubOpsEvent.roster.title \($0)", table: "ClubOpsEvent", locale: locale)) }
                             ?? String(localized: LocalizedStringResource("clubOpsEvent.section.roster", table: "ClubOpsEvent", locale: locale)))
                    } icon: {
                        Image(systemName: "person.crop.rectangle.stack")
                    }
                }
            }
            // CLB-event-ops-02 (r9, MP wxml:79-113): bucket tabs + member cards inline under the row.
            if let inlineRoster {
                ClubOpsEventInlineRoster(roster: inlineRoster, selected: $rosterTab) {
                    ClubGovernanceReadView(operation: .roster, scope: eventScope, identity: identity, access: access, coordinator: coordinator)
                }
            }
        case .series where publishEmpty:
            // CLB-G15 (MP wxml:119-120): only the empty state and 发布主题 (`goPublishTopic` → fabu?clubId, js:499-503).
            Section {
                ContentUnavailableView {
                    Label("club.eventOps.noTopics", systemImage: "calendar.badge.plus")
                } actions: {
                    if let clubID = scope.clubID {
                        NavigationLink {
                            MPReviewedPageScreen(page: "pages/publish/fabu/index", query: ["clubId": String(clubID)])
                        } label: {
                            Text("club.detail.events.publish")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("clubOpsEvent.publishTopic")
                    }
                }
            }
        case .series:
            // Mini-program 日期清单 card: title row + its one-line rule 「仅可修改无报名的未来场次」.
            Section {
                push(.series, .init(clubID: scope.clubID)) {
                    Label {
                        Text("clubOpsEvent.section.series", tableName: "ClubOpsEvent")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            } footer: { Text("clubOpsEvent.series.note", tableName: "ClubOpsEvent") }
        case .recurrence:
            Section {
                if topicFacts.count > 1 { topicPicker }
                push(.eventTopics, .init(clubID: scope.clubID, topicID: pickedTopicID ?? scope.topicID)) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("clubOpsEvent.recurrence.add", tableName: "ClubOpsEvent")
                            Text("clubOpsEvent.recurrence.addHint", tableName: "ClubOpsEvent")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "plus.circle")
                    }
                }
            } header: { Text("clubOpsEvent.section.recurrence", tableName: "ClubOpsEvent") } footer: { Text("clubOpsEvent.recurrence.note", tableName: "ClubOpsEvent") }
        case .capacity:
            // Capacity and waitlist are set inside the series form (ClubOpsEventSeriesFields);
            // the hub section held only explanations with no control, so it is not shown.
            EmptyView()
        }
    }
    private var topicPicker: some View {
        Picker(selection: $pickedTopicID) {
            ForEach(topicFacts) { fact in
                Text(verbatim: fact.name ?? "#\(fact.id)").tag(Optional(fact.id))
            }
        } label: {
            Text("clubOpsEvent.recurrence.topic", tableName: "ClubOpsEvent")
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("clubOpsEvent.recurrence.topicPicker")
    }
    /// CLB-event-ops-02: the hub's roster read as the shared presentation; nil when it is missing or malformed.
    private var inlineRoster: ClubRosterPresentation? {
        guard let rosterSnapshot else { return nil }
        let context = ClubGovernanceReadContext(operation: .roster, scope: eventScope, identity: identity, viewerRevision: 0,
                                                authorizationGeneration: access.authorizationGeneration, accessIdentity: ObjectIdentifier(access))
        return try? ClubRosterPresentation(snapshot: rosterSnapshot, context: context)
    }
    private func push<RowLabel: View>(_ read: ClubGovernanceRead, _ target: ClubGovernanceScope, @ViewBuilder label: () -> RowLabel) -> some View {
        NavigationLink {
            ClubGovernanceReadView(operation: read, scope: target, identity: identity, access: access, coordinator: coordinator)
        } label: { label() }
            .accessibilityIdentifier("clubOpsEvent.open." + read.rawValue)
    }
    private func load() async {
        generation &+= 1
        let revision = generation, expected = key
        model = nil; loadedKey = nil; failure = nil; loading = true
        guard identity?.isSignedIn == true, identity == access.identity, (scope.clubID ?? 0) > 0 else {
            loading = false; failure = identity?.isSignedIn == true ? .invalidRequest : .signedOut; return
        }
        let check: () throws -> Void = {
            guard revision == generation, expected == key, !Task.isCancelled else { throw CancellationError() }
        }
        do {
            let snapshot = try await access.read(.access, scope: accessScope, options: [:], check: check)
            guard revision == generation, expected == key, !Task.isCancelled else { return }
            guard snapshot.operation == .access, snapshot.scope == accessScope, let permissions = snapshot.permissions else {
                throw ClubGovernanceFailure.malformed
            }
            model = ClubOpsEventAccess(permissions: permissions, scope: eventScope); loadedKey = expected
            occurrenceStatus = nil; rosterTotal = nil; rosterSnapshot = nil; publishEmpty = false; topicFacts = []
            if let model, model.sections.contains(.series) || model.sections.contains(.recurrence) {
                let clubScope = ClubGovernanceScope(clubID: scope.clubID)
                let topics = try? await access.read(.eventTopics, scope: clubScope, options: [:], check: check)
                guard revision == generation, expected == key else { return }
                topicFacts = ClubOpsEventTopicNames.facts(topics, clubID: scope.clubID)
                if !topicFacts.contains(where: { $0.id == pickedTopicID }) {
                    pickedTopicID = topicFacts.first(where: { $0.id == scope.topicID })?.id ?? topicFacts.first?.id
                }
                // MP `topicsLoaded && topics.length === 0 && seriesState === 'empty'`: both reads must answer.
                if model.sections.contains(.series), let topics,
                   let series = try? await access.read(.series, scope: clubScope, options: [:], check: check) {
                    guard revision == generation, expected == key else { return }
                    let seriesRows = series.value.array ?? series.value["rows"].array ?? series.value["items"].array
                    publishEmpty = topics.value.array?.isEmpty == true && seriesRows?.isEmpty == true
                }
            }
            if (scope.activityID ?? 0) > 0, let model {
                if model.sections.contains(.occurrence),
                   let status = try? await access.read(.occurrenceStatus, scope: eventScope, options: [:], check: check) {
                    guard revision == generation, expected == key else { return }
                    occurrenceStatus = status.value
                }
                if model.canCheckin, let roster = try? await access.read(.roster, scope: eventScope, options: [:], check: check) {
                    guard revision == generation, expected == key else { return }
                    let buckets = ["registered", "arrived", "noShow"].map { roster.value[$0].array }
                    if buckets.allSatisfy({ $0 != nil }) { rosterTotal = buckets.reduce(0) { $0 + ($1?.count ?? 0) } }
                    rosterSnapshot = roster
                }
            }
        } catch {
            guard revision == generation, expected == key else { return }
            if !(error is CancellationError) { failure = error as? ClubGovernanceFailure ?? .malformed }
        }
        if revision == generation { loading = false }
    }
}

/// Mini series row: "{topic} · {单次/每周/自定义日期}" plus collision-only suffix and waitlist meta.
@MainActor struct ClubOpsEventSeriesRowView: View {
    let row: ClubOpsEventSeriesRow
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                title
                    .fixedSize(horizontal: false, vertical: true)
                if let enabled = row.waitlistEnabled {
                    if enabled {
                        Label { Text("clubOpsEvent.series.waitlistOn", tableName: "ClubOpsEvent") } icon: { Image(systemName: "person.2") }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Label { Text("clubOpsEvent.series.waitlistOff", tableName: "ClubOpsEvent") } icon: { Image(systemName: "person.2.slash") }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } icon: {
            Image(systemName: "calendar")
        }
        .accessibilityIdentifier("clubOpsEvent.series.row.\(row.id)")
    }
    private var title: Text {
        var text = row.topicName.map { Text(verbatim: $0) } ?? Text("clubOpsEvent.series.topicID \(row.topicID)", tableName: "ClubOpsEvent")
        text = text + Text(verbatim: " · ") + Text(LocalizedStringKey("club.gov.choice." + row.recurrence))
        guard !row.suffix.isEmpty else { return text }
        text = text + Text(verbatim: "（")
        for (index, part) in row.suffix.enumerated() {
            if index > 0 { text = text + Text(verbatim: " · ") }
            switch part {
            case .firstDate(let month, let day): text = text + Text("clubOpsEvent.series.firstDate \(month) \(day)", tableName: "ClubOpsEvent")
            case .topic(let id): text = text + Text("clubOpsEvent.series.topicID \(id)", tableName: "ClubOpsEvent")
            case .series(let id): text = text + Text("clubOpsEvent.series.seriesID \(id)", tableName: "ClubOpsEvent")
            }
        }
        return text + Text(verbatim: "）")
    }
}

@MainActor struct ClubOpsEventSeriesHeader: View {
    let empty: Bool
    var namesKey: ClubGovernanceReadContext? = nil
    var loadNames: (@MainActor (ClubGovernanceReadContext) async -> Void)? = nil
    var body: some View {
        Section {
            Text("clubOpsEvent.series.note", tableName: "ClubOpsEvent")
                .task(id: namesKey) { if let namesKey, let loadNames { await loadNames(namesKey) } }
            if empty {
                ContentUnavailableView {
                    Label {
                        Text("clubOpsEvent.series.empty", tableName: "ClubOpsEvent")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                } description: {
                    Text("clubOpsEvent.series.emptyHint", tableName: "ClubOpsEvent")
                }
                .accessibilityIdentifier("clubOpsEvent.series.empty")
            }
        }
    }
}

struct ClubOpsEventOccurrenceBadgeText: View {
    let badge: ClubOpsEventOccurrenceBadge
    var body: some View {
        switch badge {
        case .cancelled:
            ClubOpsEventStatusLine(key: "clubOpsEvent.occurrences.cancelled", symbol: "xmark.circle", tone: .red)
        case .editable:
            Label { Text("clubOpsEvent.occurrences.editable", tableName: "ClubOpsEvent") } icon: { Image(systemName: "pencil.circle") }
                .font(.subheadline)
                .foregroundStyle(.green)
        case .lockReason(let reason):
            ClubOpsEventStatusLine(verbatim: reason, symbol: "lock", tone: .orange)
        case .locked:
            Label { Text("clubOpsEvent.occurrences.locked", tableName: "ClubOpsEvent") } icon: { Image(systemName: "lock") }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ClubOpsEventOccurrenceMetaText: View {
    let meta: ClubOpsEventOccurrenceMeta
    var body: some View {
        metaText
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private var metaText: some View {
        switch meta {
        case .refunded(let count): Text("clubOpsEvent.occurrences.refunded \(count)", tableName: "ClubOpsEvent")
        case .cancelled: Text("clubOpsEvent.occurrences.cancelled", tableName: "ClubOpsEvent")
        case .signupsPending: Text("clubOpsEvent.occurrences.signupsPending", tableName: "ClubOpsEvent")
        case .noSignups: Text("clubOpsEvent.occurrences.noSignups", tableName: "ClubOpsEvent")
        case .signups(let count, let locked):
            if locked { Text("clubOpsEvent.occurrences.signupsLocked \(count)", tableName: "ClubOpsEvent") }
            else { Text("clubOpsEvent.occurrences.signups \(count)", tableName: "ClubOpsEvent") }
        }
    }
}

/// Mini 本场管理 card over the validated occurrence/status read. Contradictions fail closed.
@MainActor struct ClubOpsEventOccurrenceStatusRows: View {
    let value: ClubGovernanceValue
    let activityID: Int?
    var body: some View {
        switch ClubOpsEventCancellation.state(value, activityID: activityID) {
        case .cancelled(let reason)?:
            VStack(alignment: .leading, spacing: 4) {
                ClubOpsEventStatusLine(key: "clubOpsEvent.occurrences.cancelled", symbol: "xmark.circle", tone: .red)
                if let reason {
                    Text("clubOpsEvent.cancel.reason \(reason)", tableName: "ClubOpsEvent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.accessibilityIdentifier("clubOpsEvent.cancel.cancelled")
        case .active?:
            Text("clubOpsEvent.cancel.subtitle", tableName: "ClubOpsEvent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clubOpsEvent.cancel.active")
        case nil:
            Text("clubOpsEvent.cancel.incomplete", tableName: "ClubOpsEvent")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clubOpsEvent.cancel.unknownState")
        }
    }
}

/// Mini cancellationSummary for the acknowledged cancel receipt, shown with the existing readback lock.
@MainActor struct ClubOpsEventCancellationReceipt: View {
    let receipt: ClubGovernanceValue
    let confirmed: Bool
    let reread: () -> Void
    var body: some View {
        if !confirmed {
            Text("clubOpsEvent.cancel.incomplete", tableName: "ClubOpsEvent")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clubOpsEvent.cancel.incomplete")
            Button(action: reread) {
                Label { Text("clubOpsEvent.cancel.reread", tableName: "ClubOpsEvent") } icon: { Image(systemName: "arrow.clockwise") }
            }
                .accessibilityIdentifier("clubOpsEvent.cancel.reread")
        }
        ClubOpsEventStatusLine(
            key: "clubOpsEvent.refund." + ClubOpsEventCancellation.refund(receipt).rawValue,
            symbol: "arrow.uturn.backward.circle",
            tone: .primary
        )
        .accessibilityIdentifier("clubOpsEvent.cancel.refund")
        ClubOpsEventStatusLine(
            key: "clubOpsEvent.notify." + ClubOpsEventCancellation.notifications(receipt).rawValue,
            symbol: "bell",
            tone: .primary
        )
        .accessibilityIdentifier("clubOpsEvent.cancel.notify")
    }
}

/// Display-only topic names for the series list (mini loadTopics, same club, club:activity:manage).
/// A failed, denied or stale read only keeps the `主题 #id` fallback; it never hides or delays a series row.
@MainActor final class ClubOpsEventTopicNameReads: ObservableObject {
    @Published private(set) var snapshot: ClubGovernanceSnapshot?
    private var context: ClubGovernanceReadContext?
    func names(_ expected: ClubGovernanceReadContext) -> [Int: String] {
        context == expected ? ClubOpsEventTopicNames.names(snapshot, clubID: expected.scope.clubID) : [:]
    }
    func load(context expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess) async {
        guard expected.operation == .series, let clubID = expected.scope.clubID, clubID > 0,
              context != expected || snapshot == nil else { return }
        context = expected; snapshot = nil
        guard expected.identity?.isSignedIn == true, expected.identity == access.identity, access.isConfigured,
              expected.accessIdentity == ObjectIdentifier(access) else { return }
        let scope = ClubGovernanceScope(clubID: clubID)
        func check() throws {
            guard context == expected, expected.identity == access.identity,
                  expected.authorizationGeneration == access.authorizationGeneration, !Task.isCancelled else { throw CancellationError() }
        }
        guard let result = try? await access.read(.eventTopics, scope: scope, options: [:], check: check),
              (try? check()) != nil, result.operation == .eventTopics, result.scope == scope else { return }
        snapshot = result
    }
}

/// Mini handleSeriesConflict copy, shown on the re-read series detail after a definite 409.
struct ClubOpsEventSeriesConflictNotice: View {
    var body: some View {
        Section {
            Label {
                Text("clubOpsEvent.series.conflict", tableName: "ClubOpsEvent")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
            }
            .foregroundStyle(.orange)
            .accessibilityIdentifier("clubOpsEvent.series.conflict")
        }
    }
}

// CLB-r10-nat-event-ops-03: Section headers and footers are plain `Text` (system styling); the
// ClubOpsTableHeading / ClubOpsTableNote wrappers are gone.

/// Icon plus wrapping status copy. A blank server reason is an em dash, never a zero.
private struct ClubOpsEventStatusLine: View {
    private let text: Text
    private let symbol: String
    private let tone: Color
    init(key: String, symbol: String, tone: Color) {
        text = Text(LocalizedStringKey(key), tableName: "ClubOpsEvent")
        self.symbol = symbol
        self.tone = tone
    }
    init(verbatim: String, symbol: String, tone: Color) {
        let shown = verbatim.trimmingCharacters(in: .whitespacesAndNewlines)
        text = Text(verbatim: shown.isEmpty ? "—" : shown)
        self.symbol = symbol
        self.tone = tone
    }
    var body: some View {
        Label {
            text.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
        .foregroundStyle(tone)
        .accessibilityElement(children: .combine)
    }
}
