import SwiftUI

@MainActor struct OfficialInboxView: View {
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator? = nil
    var publisher = false
    var onLogin: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    /// Source official-inbox load failure: "邀约没有加载出来" above the retryable issue.
    nonisolated static func issueCopy(_ error: Error) -> OfficialIssueCopy? {
        guard case .failed = OfficialScreenIssue(error) else { return nil }
        return OfficialIssueCopy(title: "official.w206.inbox.failed.title", detail: "official.w206.inbox.failed.detail",
                                 identifier: "official.inbox" + ".failed")
    }
    var body: some View {
        OfficialReadScreen(reader: reader, isPrivate: true, requestID: "inbox", onLogin: onLogin,
                           issueCopy: OfficialInboxView.issueCopy, load: { try await reader.partyInbox() }) { rows in
            // pages/activity/official-inbox/index: a path this repo does not mark live stays hidden.
            if let page = OfficialInboxPageModel.state(loading: false, failed: false, rows: rows) {
            List {
                // PC-C-5-3: the current MP inbox has only the page title (drawn by the bar); the stale oi-hero preamble is gone.
                if page == .empty {
                    CYEmptyState(systemImage: "envelope.open", "official.inbox.empty", detail: "official.inbox.emptyDetail")
                        .accessibilityIdentifier("official.inbox" + ".empty")
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    // R7-PC-C5-3 (MP official-inbox/index.wxml:14-32): one card per invite, its buttons inside it;
                    // the invite title is plain text, not a tappable-looking row.
                    Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYStatusChip(LocalizedStringKey(row.sourceStatusKey), tone: row.isPaused ? .warning : .neutral, systemImage: "envelope")
                        Group {
                            if row.title.isEmpty { Text("official.inviteUntitled") } else { Text(verbatim: row.title) }
                        }
                        .cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        if let title = row.eventTitle, !title.isEmpty { Text(verbatim: title) }
                        // Source meta line: "(city ‖ 全国) · role".
                        (cityText(row) + Text(verbatim: " · ") + roleText(row)).cyText(.meta).foregroundStyle(palette.textSecondary)
                        Text(LocalizedStringKey(row.scopeKey)).cyText(.caption).foregroundStyle(palette.textSecondary)
                        if let note = row.roleNoteTuple {
                            Text(verbatim: c.t(note.zh, note.en)).cyText(.caption).foregroundStyle(palette.textSecondary)
                        }
                        // capacityFact keeps a literal 0; a missing or non-integer capacity is an em dash.
                        Group {
                            switch row.capacityFact {
                            case .known(let cap): Text(verbatim: appLocalized("official.inbox.capacity \(cap)", locale: locale))
                            case .unknown: Text("official.inbox.capacityUnknown")
                            }
                        }.cyText(.caption).foregroundStyle(palette.textSecondary)
                        if let facts = row.windowFacts { OfficialPrivateFactsText.window(facts.window).cyText(.caption) }
                        if let summary = row.responsibilitySummary, !summary.isEmpty, summary != row.title {
                            Text(verbatim: summary).cyText(.meta)
                        }
                        if row.isPaused {
                            Text(verbatim: c.t("本场活动已暂停，恢复前以主办通知为准。",
                                              "This event is paused. Updates will be shared by the organizer before resuming."))
                                .cyText(.caption).foregroundStyle(palette.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let status = row.status, row.statusKey == "official.status.unknown" { Text(verbatim: status.isEmpty ? "—" : status).cyText(.caption) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("official.invite.\(row.id)")
                    if let actions { OfficialInviteResponseActions(coordinator: actions, invite: row, publisher: publisher, embedded: true) }
                    }
                }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(palette.bgPage)
            .themeDomain(.player)
            .accessibilityIdentifier("official.inbox.content")
            }
        }.appNavigationTitle("official.inbox.title").navigationBarTitleDisplayMode(.inline)
    }
    private func cityText(_ row: OfficialPartyInvite) -> Text {
        // A null city is a nationwide event in the source, not a missing value.
        if let city = row.city, !city.isEmpty { return Text(verbatim: city) }
        return Text("official.inbox.nationwide")
    }
    private func roleText(_ row: OfficialPartyInvite) -> Text {
        if let key = row.roleKey { return Text(LocalizedStringKey(key)) }
        if let role = row.role, !role.isEmpty { return Text(verbatim: role) }
        return Text("official.inbox.role.unknown")
    }
}
@MainActor struct OfficialPublishedView: View {
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator? = nil
    var onLogin: (() -> Void)? = nil
    @Environment(\.cyPalette) private var palette
    var body: some View {
        OfficialReadScreen(reader: reader, isPrivate: true, requestID: "published", onLogin: onLogin, load: { try await reader.myPublished() }) { value in
            List {
                // R7-PC-C6-1 MP-first: the MP has no 发起 / 官方通知 editor here (pages/activity/list/index.wxml:77-80,
                // ruling 2026-09-03: official events are uploaded from the Web admin), so 我发布的 is read-only.
                // Source official-mine always shows both sections with counts and per-section empty copy.
                let events = OfficialEventFilter.visible(value.events, bucket: .mine)
                let broadcasts = value.broadcasts.filter { $0.id > 0 }
                Section {
                    if events.isEmpty { emptyRow("official.published.eventsEmpty") }
                    ForEach(events) { event in
                        // Source official-mine row: title + publisher-view status badge, then city.
                        NavigationLink { OfficialEventDetailView(id: event.id, reader: reader, actions: actions, onLogin: onLogin) } label: { publishedEventRow(event) }
                            .accessibilityIdentifier("official.published.event.\(event.id)")
                        OfficialOrganizerEntryRow(eventID: event.id, access: actions?.organizer)
                    }
                } header: { Text("official.published.eventsHeader \(events.count)") }
                Section {
                    if broadcasts.isEmpty { emptyRow("official.published.broadcastsEmpty", "official.published.broadcastsEmptyDetail") }
                        ForEach(Array(broadcasts.enumerated()), id: \.offset) { _, broadcast in
                            if broadcast.id > 0 {
                                // R7-PC-C6-3 (MP official-mine/index.wxml:25-29): tapping the card reads its 复盘 in place.
                                OfficialBroadcastInlineStatsRow(id: broadcast.id, reader: reader) {
                                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                        if let facts = broadcast.facts {
                                            CYStatusChip(OfficialPrivateFactsText.broadcastStatusKey(facts.status), tone: .neutral, systemImage: "megaphone")
                                        }
                                        if broadcast.title.isEmpty { Text("official.untitled").cyText(.cardTitle).fixedSize(horizontal: false, vertical: true) }
                                        else { Text(verbatim: broadcast.title).cyText(.cardTitle).fixedSize(horizontal: false, vertical: true) }
                                        if let facts = broadcast.facts {
                                            OfficialPrivateFactsText.broadcastLine(facts).cyText(.meta).foregroundStyle(palette.textSecondary)
                                        }
                                        if let content = broadcast.content { Text(verbatim: content).cyText(.meta).lineLimit(3).fixedSize(horizontal: false, vertical: true) }
                                        if let reach = broadcast.reach { Text("official.published.reach \(reach)").cyText(.caption).foregroundStyle(palette.textSecondary).monospacedDigit() }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }.accessibilityIdentifier("official.broadcast.\(broadcast.id)")
                            }
                        }
                } header: { Text("official.published.broadcastsHeader \(broadcasts.count)") }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(CYColor.bgPage)
            .accessibilityIdentifier("official.published.content")
        }.appNavigationTitle("official.published.title").navigationBarTitleDisplayMode(.inline)
    }
    private func publishedEventRow(_ event: OfficialEvent) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(LocalizedStringKey(OfficialPublishedPresentation.ownerStatusKey(event.status)),
                         tone: OfficialEventStatusStyle.tone(event.status), systemImage: OfficialEventStatusStyle.symbol(event.status))
                .accessibilityIdentifier("official.published.eventStatus.\(event.id)")
            if let title = OfficialPublishedPresentation.nonBlank(event.title) {
                Text(verbatim: title).cyText(.cardTitle).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("official.privateParity.published.untitledEvent").cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
            }
            // Source sub line: city, then " · category" only when the server sent one.
            let city = OfficialPublishedPresentation.nonBlank(event.city).map { Text(verbatim: $0) } ?? Text(verbatim: "—")
            Group {
                if OfficialPublishedPresentation.nonBlank(event.category) != nil { city + Text(verbatim: " · ") + Text(LocalizedStringKey(event.categoryKey)) }
                else { city }
            }.cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    /// Mini-program `cy-empty` with a title only.
    private func emptyRow(_ title: LocalizedStringKey, _ detail: LocalizedStringKey? = nil) -> some View {
        // Mini-program `cy-empty` (title, optional sub): quiet centred empty row.
        VStack(spacing: CYSpacing.xs) {
            Text(title).cyText(.cardTitle).foregroundStyle(CYColor.textSecondary)
            if let detail { Text(detail).cyText(.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center) }
        }.frame(maxWidth: .infinity).padding(.vertical, CYSpacing.md).accessibilityElement(children: .combine)
    }
}
@MainActor struct OfficialBroadcastStatsView: View {
    let id: Int
    let reader: any OfficialEventReading
    var onLogin: (() -> Void)? = nil
    @State private var reload = 0
    @State private var confirmingRecover = false
    @State private var recoverNote: String?
    var body: some View {
        OfficialReadScreen(reader: reader, isPrivate: true, requestID: "stats.\(id).\(reload)", onLogin: onLogin, load: { try await reader.broadcastStats(id: id) }) { stats in
            List {
                if let line = stats.summaryLine {
                    Text(verbatim: line).accessibilityIdentifier("official.broadcast.summary")
                }
                // R7-PC-C6-3: only the stats the page can name; an unknown key is never printed raw.
                let known = stats.rows.filter { OfficialBroadcastStatsText.knownIDs.contains($0.id) }
                if known.isEmpty && stats.summaryLine == nil { Text("official.emptyStats") }
                ForEach(known) { row in
                    LabeledContent {
                        switch row.value {
                        case .text(let value): Text(verbatim: value)
                        case .number(let value): Text(verbatim: NSDecimalNumber(decimal: value).stringValue)
                        case .flag(let value): Text(value ? "official.yes" : "official.no")
                        case .unsupported: EmptyView()
                        }
                    } label: {
                        switch row.id {
                        case "reach", "reached": Text("official.reach")
                        case "read", "reads": Text("official.reads")
                        case "click", "clicks", "clicked": Text("official.clicks")
                        default: EmptyView()
                        }
                    }
                }
                if stats.canRecoverInapp {
                    Section {
                        Button("official.broadcast.recover") { confirmingRecover = true }
                            .accessibilityIdentifier("official.broadcast.recover")
                        if let recoverNote { Text(verbatim: recoverNote).foregroundStyle(CYColor.dangerText) }
                    }
                }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.accessibilityIdentifier("official.stats.content")
        }
        .confirmationDialog("official.broadcast.recover", isPresented: $confirmingRecover, titleVisibility: .visible) {
            Button("official.broadcast.recover") { Task { await recover() } }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("official.broadcast.recover.body")
        }
        .appNavigationTitle("official.stats").navigationBarTitleDisplayMode(.inline)
    }
    private func recover() async {
        do {
            try await reader.recoverBroadcast(id: String(id))
            recoverNote = nil
            reload += 1
        } catch is CancellationError {
        } catch {
            recoverNote = OfficialBroadcastStats.failureLine(serverMessage: nil)
        }
    }
}

/// MP official-mine `broadcastStatsText`: 站内触达 N 人 · 点击 M 人, from `reached` / `clicked`.
enum OfficialBroadcastStatsText {
    static let knownIDs: Set<String> = ["reach", "reached", "read", "reads", "click", "clicks", "clicked"]
    static func counts(_ stats: OfficialBroadcastStats) -> (reached: String, clicked: String)? {
        func count(_ key: String) -> String? {
            guard let row = stats.rows.first(where: { $0.id == key }), case .number(let value) = row.value,
                  value >= 0, value == value.officialWholeRounded() else { return nil }
            return NSDecimalNumber(decimal: value).stringValue
        }
        guard let reached = count("reached"), let clicked = count("clicked") else { return nil }
        return (reached, clicked)
    }
}
private extension Decimal {
    func officialWholeRounded() -> Decimal {
        var source = self, result = Decimal()
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }
}

/// R7-PC-C6-3: one 我发的通知 card. A tap reads `GET /api/official/broadcast/{id}/stats` and shows the line
/// inside the card (MP `_statsText`); a failure says so with 点一下重试 and the next tap reads again.
@MainActor struct OfficialBroadcastInlineStatsRow<Content: View>: View {
    let id: Int
    let reader: any OfficialEventReading
    @ViewBuilder let label: () -> Content
    private enum Phase: Equatable { case idle, loading, loaded(OfficialBroadcastStats), failed(String?) }
    @State private var phase: Phase = .idle
    @State private var confirmingRecover = false
    @State private var recovering = false
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Button { load() } label: {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    label()
                    switch phase {
                    case .idle: EmptyView()
                    case .loading:
                        Text("official.published.statsLoading").cyText(.caption).foregroundStyle(palette.textSecondary)
                    case .loaded(let stats):
                        if let line = stats.summaryLine {
                            Text(verbatim: line).cyText(.caption).foregroundStyle(palette.textSecondary)
                                .accessibilityIdentifier("official.broadcast.summary")
                        } else if let counts = OfficialBroadcastStatsText.counts(stats) {
                            Text("official.published.statsLine \(counts.reached) \(counts.clicked)").cyText(.caption).monospacedDigit()
                                .foregroundStyle(palette.textSecondary)
                        }
                    case .failed(let line):
                        if let line { Text(verbatim: line).cyText(.caption).foregroundStyle(CYColor.dangerText) }
                        else { Text("official.published.statsFailed").cyText(.caption).foregroundStyle(CYColor.dangerText) }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(phase == .loading || recovering)
            .accessibilityHint(Text("official.published.statsHint"))
            if case .loaded(let stats) = phase, stats.canRecoverInapp {
                Button("official.broadcast.recover") { confirmingRecover = true }
                    .disabled(recovering)
                    .accessibilityIdentifier("official.broadcast.recover.\(id)")
            }
        }
        .confirmationDialog("official.broadcast.recover", isPresented: $confirmingRecover, titleVisibility: .visible) {
            Button("official.broadcast.recover") { Task { await recover() } }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("official.broadcast.recover.body")
        }
    }
    private func load() {
        guard phase != .loading, !recovering else { return }
        phase = .loading
        let scope = reader.scope
        Task {
            do {
                let stats = try await reader.broadcastStats(id: id)
                // R8-PC-C6-1: a scope change mid-read drops the result but never leaves the row stuck on 正在读取复盘….
                guard reader.scope == scope else { phase = .idle; return }
                if stats.summaryLine != nil || OfficialBroadcastStatsText.counts(stats) != nil || stats.canRecoverInapp {
                    phase = .loaded(stats)
                } else { phase = .failed(nil) }
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = reader.scope == scope ? .failed(nil) : .idle
            }
        }
    }
    /// Confirm, then `recoverBroadcast(id:token:)` through the reader, then re-read stats.
    private func recover() async {
        recovering = true
        defer { recovering = false }
        let scope = reader.scope
        do {
            try await reader.recoverBroadcast(id: String(id))
            guard reader.scope == scope else { phase = .idle; return }
            let stats = try await reader.broadcastStats(id: id)
            guard reader.scope == scope else { phase = .idle; return }
            phase = .loaded(stats)
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = reader.scope == scope ? .failed(OfficialBroadcastStats.failureLine(serverMessage: nil)) : .idle
        }
    }
}
