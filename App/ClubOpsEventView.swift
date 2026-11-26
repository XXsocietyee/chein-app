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
    private var key: Key { .init(identity: identity, authorization: access.authorizationGeneration, reader: ObjectIdentifier(access), scope: scope) }
    private var accessScope: ClubGovernanceScope { .init(clubID: scope.clubID, activityID: scope.activityID) }
    private var eventScope: ClubGovernanceScope { .init(clubID: scope.clubID, topicID: scope.topicID, activityID: scope.activityID) }
    private var phaseToken: String {
        if loading { return "loading" }
        if failure == .forbidden || (loadedKey == key && model?.permitted == false) { return "denied" }
        if failure != nil { return "failure" }
        if loadedKey == key, model != nil { return "ready" }
        return "idle"
    }
    var body: some View {
        List {
            // CLB-event-ops-04 (parity r2): a utility page; inline bar title, no hero or decorative art.
            if loading {
                CYSkeleton()
                    .accessibilityIdentifier("clubOpsEvent.loading")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .e1HeroRow()
            } else if failure == .forbidden || (loadedKey == key && model?.permitted == false) {
                denied
            } else if let failure {
                VStack(spacing: CYSpacing.md) {
                    Text(verbatim: ClubOpsNetworkFailureClassifier.eventOpsHubTitle(failure))
                        .cyText(.cardTitle)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("clubOpsEvent.error")
                    CYPillButton("action.retry", style: .primary) { Task { await load() } }
                        .accessibilityIdentifier("clubOpsEvent.retry")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if loadedKey == key, let model {
                ForEach(model.sections, id: \.self) { section in self.section(section, model: model) }
            }
        }
        .cyGroupedSurface()
        .navigationTitle(Text("clubOpsEvent.title", tableName: "ClubOpsEvent"))
        .navigationBarTitleDisplayMode(.inline)
        .cyAnimation(value: phaseToken)
        .accessibilityIdentifier("clubOpsEvent.root")
        .task(id: key) { await load() }
        .refreshable { await load() }
        // CLB-event-ops-04 / X8: inherit the workspace's domain (MP event-ops is merchant-light), not a forced dark page.
        .scrollContentBackground(.hidden).cyDomainPageBackground()
    }
    private var denied: some View {
        VStack(spacing: CYSpacing.sm) {
            CYEmptyState(systemImage: "lock", "clubOpsEvent.denied.title", tableName: "ClubOpsEvent", kind: .generic)
            Text("clubOpsEvent.denied.body", tableName: "ClubOpsEvent")
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("clubOpsEvent.denied")
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("clubOpsEvent.roster.hidden")
                }
                if let occurrenceStatus, ClubOpsEventCancellation.state(occurrenceStatus, activityID: scope.activityID) != nil {
                    ClubOpsEventOccurrenceStatusRows(value: occurrenceStatus, activityID: scope.activityID)
                }
                push(.occurrenceStatus, eventScope) {
                    // CLB-event-ops-07: the consequence lives in the confirm only (MP 1121), not on the row.
                    CYListRow("club.gov.action.cancelOccurrence", trailing: .none) { CYRowIcon(systemImage: "calendar.badge.minus") }
                }
            } header: { ClubOpsTableHeading("clubOpsEvent.section.occurrence") }
            // CLB-G15 (MP event-ops wxml:39-43): 主持小费 · 暂不可开通 under 本场管理 (collection channel not enabled, so no
            // switch or ratio). paymentNotice / windowWarning stay nil until Core feeds them (fix-r8-club "for Cursor").
            ClubGapEventOpsExtrasSection(onTapPublishTopic: {})
        case .roster:
            Section {
                push(.roster, eventScope) {
                    // CLB-event-ops-02 (MP wxml:72): 本场名册 · N 人 once the roster read is in (registered + arrived + noShow).
                    CYListRow(verbatim: rosterTotal.map { String(localized: LocalizedStringResource("clubOpsEvent.roster.title \($0)", table: "ClubOpsEvent", locale: locale)) }
                              ?? String(localized: LocalizedStringResource("clubOpsEvent.section.roster", table: "ClubOpsEvent", locale: locale)), trailing: .none) {
                        CYRowIcon(systemImage: "person.crop.rectangle.stack")
                    }
                }
            }
            // CLB-event-ops-02 (r9, MP wxml:79-113): bucket tabs + member cards inline under the row.
            if let inlineRoster {
                ClubOpsEventInlineRoster(roster: inlineRoster, selected: $rosterTab) {
                    ClubGovernanceReadView(operation: .roster, scope: eventScope, identity: identity, access: access, coordinator: coordinator)
                }
            }
        case .series:
            // Mini-program 日期清单 card: title row + its one-line rule 「仅可修改无报名的未来场次」.
            Section {
                push(.series, .init(clubID: scope.clubID)) {
                    CYListRow(verbatim: String(localized: LocalizedStringResource("clubOpsEvent.section.series", table: "ClubOpsEvent", locale: locale)), trailing: .none) {
                        CYRowIcon(systemImage: "calendar")
                    }
                }
            } footer: { ClubOpsTableNote("clubOpsEvent.series.note") }
        case .recurrence:
            Section {
                push(.eventTopics, .init(clubID: scope.clubID, topicID: scope.topicID)) {
                    CYListRow(
                        verbatim: String(localized: LocalizedStringResource("clubOpsEvent.recurrence.add", table: "ClubOpsEvent", locale: locale)),
                        meta: String(localized: LocalizedStringResource("clubOpsEvent.recurrence.addHint", table: "ClubOpsEvent", locale: locale)),
                        trailing: .none
                    ) { CYRowIcon(systemImage: "plus.circle") }
                }
            } header: { ClubOpsTableHeading("clubOpsEvent.section.recurrence") } footer: { ClubOpsTableNote("clubOpsEvent.recurrence.note") }
        case .capacity:
            // Capacity and waitlist are set inside the series form (ClubOpsEventSeriesFields);
            // the hub section held only explanations with no control, so it is not shown.
            EmptyView()
        }
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
            occurrenceStatus = nil; rosterTotal = nil; rosterSnapshot = nil
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
    @Environment(\.locale) private var locale
    let row: ClubOpsEventSeriesRow
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: "calendar")
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                title
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let enabled = row.waitlistEnabled {
                    if enabled {
                        CYStatusChip(verbatim: String(localized: LocalizedStringResource("clubOpsEvent.series.waitlistOn", table: "ClubOpsEvent", locale: locale)), tone: .success, systemImage: "person.2")
                    } else {
                        CYStatusChip(verbatim: String(localized: LocalizedStringResource("clubOpsEvent.series.waitlistOff", table: "ClubOpsEvent", locale: locale)), tone: .neutral, systemImage: "person.2.slash")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
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
            ClubOpsTableNote("clubOpsEvent.series.note")
                .task(id: namesKey) { if let namesKey, let loadNames { await loadNames(namesKey) } }
            if empty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYEmptyState(systemImage: "calendar", "clubOpsEvent.series.empty", tableName: "ClubOpsEvent")
                    Text("clubOpsEvent.series.emptyHint", tableName: "ClubOpsEvent")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("clubOpsEvent.series.empty")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
}

struct ClubOpsEventOccurrenceBadgeText: View {
    @Environment(\.locale) private var locale
    let badge: ClubOpsEventOccurrenceBadge
    var body: some View {
        switch badge {
        case .cancelled:
            ClubOpsEventStatusLine(key: "clubOpsEvent.occurrences.cancelled", symbol: "xmark.circle", tone: CYColor.dangerText)
        case .editable:
            CYStatusChip(verbatim: String(localized: LocalizedStringResource("clubOpsEvent.occurrences.editable", table: "ClubOpsEvent", locale: locale)), tone: .success, systemImage: "pencil.circle")
        case .lockReason(let reason):
            ClubOpsEventStatusLine(verbatim: reason, symbol: "lock", tone: CYColor.warningText)
        case .locked:
            CYStatusChip(verbatim: String(localized: LocalizedStringResource("clubOpsEvent.occurrences.locked", table: "ClubOpsEvent", locale: locale)), tone: .neutral, systemImage: "lock")
        }
    }
}

struct ClubOpsEventOccurrenceMetaText: View {
    let meta: ClubOpsEventOccurrenceMeta
    var body: some View {
        metaText
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
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
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                ClubOpsEventStatusLine(key: "clubOpsEvent.occurrences.cancelled", symbol: "xmark.circle", tone: CYColor.dangerText)
                if let reason {
                    Text("clubOpsEvent.cancel.reason \(reason)", tableName: "ClubOpsEvent")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.accessibilityIdentifier("clubOpsEvent.cancel.cancelled")
        case .active?:
            Text("clubOpsEvent.cancel.subtitle", tableName: "ClubOpsEvent")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clubOpsEvent.cancel.active")
        case nil:
            Text("clubOpsEvent.cancel.incomplete", tableName: "ClubOpsEvent")
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
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
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clubOpsEvent.cancel.incomplete")
            CYPillButton("clubOpsEvent.cancel.reread", style: .secondary, systemImage: "arrow.clockwise", tableName: "ClubOpsEvent", action: reread)
                .accessibilityIdentifier("clubOpsEvent.cancel.reread")
                .e1ActionRow()
        }
        ClubOpsEventStatusLine(
            key: "clubOpsEvent.refund." + ClubOpsEventCancellation.refund(receipt).rawValue,
            symbol: "arrow.uturn.backward.circle",
            tone: CYColor.textPrimary
        )
        .accessibilityIdentifier("clubOpsEvent.cancel.refund")
        ClubOpsEventStatusLine(
            key: "clubOpsEvent.notify." + ClubOpsEventCancellation.notifications(receipt).rawValue,
            symbol: "bell",
            tone: CYColor.textPrimary
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
            .cyText(.body)
            .foregroundStyle(CYColor.warningText)
            .accessibilityIdentifier("clubOpsEvent.series.conflict")
        }
    }
}

private struct ClubOpsTableHeading: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View {
        Text(LocalizedStringKey(key), tableName: "ClubOpsEvent")
            .cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ClubOpsTableNote: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View {
        Text(LocalizedStringKey(key), tableName: "ClubOpsEvent")
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

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
        .cyText(.body)
        .foregroundStyle(tone)
        .accessibilityElement(children: .combine)
    }
}
