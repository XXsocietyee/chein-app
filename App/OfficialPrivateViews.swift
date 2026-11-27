import SwiftUI

@MainActor struct OfficialInboxView: View {
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator? = nil
    var publisher = false
    var onLogin: (() -> Void)? = nil
    @Environment(\.locale) private var locale
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
                    ContentUnavailableView("official.inbox.empty", systemImage: "tray")
                        .accessibilityIdentifier("official.inbox" + ".empty")
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    // R7-PC-C5-3 (MP official-inbox/index.wxml:14-32): one card per invite, its buttons inside it;
                    // the invite title is plain text, not a tappable-looking row.
                    Section {
                    VStack(alignment: .leading, spacing: 6) {
                        // MP oi-head: event title + "city · role" on the left, the status word on the right.
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                inviteHead(row)
                                Spacer(minLength: 8)
                                inviteStatus(row)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                inviteHead(row)
                                inviteStatus(row)
                            }
                        }
                        // MP oi-role-note: "role：note", only for a known role.
                        if let note = row.roleNoteTuple {
                            (roleText(row) + Text(verbatim: c.t("：", ": ")) + Text(verbatim: c.t(note.zh, note.en)))
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // MP oi-scope: scope, service window, then capacity only when it is a positive number.
                        Text(LocalizedStringKey(row.scopeKey)).font(.caption).foregroundStyle(.secondary)
                        if let facts = row.windowFacts { OfficialPrivateFactsText.window(facts.window).font(.caption) }
                        if let cap = row.capacity {
                            Text(verbatim: appLocalized("official.inbox.capacity \(cap)", locale: locale))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if row.isPaused {
                            Text(verbatim: c.t("本场活动已暂停，恢复前以主办通知为准。",
                                              "This event is paused. Updates will be shared by the organizer before resuming."))
                                .font(.caption).foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let summary = row.responsibilitySummary, !summary.isEmpty {
                            Text(verbatim: summary).font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("official.invite.\(row.id)")
                    if let actions { OfficialInviteResponseActions(coordinator: actions, invite: row, publisher: publisher, embedded: true) }
                    }
                }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.listStyle(.insetGrouped)
            .themeDomain(.player)
            .accessibilityIdentifier("official.inbox.content")
            }
        }.appNavigationTitle("official.inbox.title").navigationBarTitleDisplayMode(.inline)
    }
    /// MP oi-event + oi-meta: the event title (未命名官方活动 when blank) and "(city ‖ 全国) · role".
    @ViewBuilder private func inviteHead(_ row: OfficialPartyInvite) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let title = row.eventTitle, !title.isEmpty { Text(verbatim: title) }
                else { Text("official.privateParity.published.untitledEvent") }
            }
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            // MP cityRole: the role is appended only when it is a known role.
            Group {
                if row.roleKey != nil { cityText(row) + Text(verbatim: " · ") + roleText(row) }
                else { cityText(row) }
            }.font(.footnote).foregroundStyle(.secondary)
        }
    }
    /// MP oi-status: 待你确认 / 已接受 / 履约中 / 状态待确认.
    private func inviteStatus(_ row: OfficialPartyInvite) -> some View {
        Text(LocalizedStringKey(row.sourceStatusKey))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(row.status == "INVITED" ? Color.accentColor : Color.secondary)
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
    var body: some View {
        OfficialReadScreen(reader: reader, isPrivate: true, requestID: "published", onLogin: onLogin,
                           issueLabel: { $0 == .failed ? "official.published.loadFailed" : nil },
                           load: { try await reader.myPublished() }) { value in
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
                        // MP om-organizer: every v2 row offers 主办控制台 · 发布 / 暂停 / 恢复; the console's own
                        // publish-check decides whether this account may manage it.
                        if event.isV2, let access = actions?.organizer, access.enabled {
                            NavigationLink {
                                OfficialOrganizerConsoleView(eventID: event.id, access: access)
                            } label: {
                                Label("activityR3.official.mine.organizerEntry", systemImage: "slider.horizontal.3")
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("official.published.organizer.\(event.id)")
                        }
                    }
                } header: { Text("official.published.eventsHeader \(events.count)") }
                Section {
                    // R9-PC-C6-1: MP cy-empty title only (pages/activity/official-mine/index.wxml:23).
                    if broadcasts.isEmpty { emptyRow("official.published.broadcastsEmpty") }
                        ForEach(Array(broadcasts.enumerated()), id: \.offset) { _, broadcast in
                            if broadcast.id > 0 {
                                // R7-PC-C6-3 (MP official-mine/index.wxml:25-29): tapping the card reads its 复盘 in place.
                                OfficialBroadcastInlineStatsRow(id: broadcast.id, reader: reader) {
                                    // MP om-card: title + status badge, "mode · 发给 audience · city", then the reach line.
                                    VStack(alignment: .leading, spacing: 6) {
                                        titleWithStatus {
                                            if broadcast.title.isEmpty { Text("activityR3.official.mine.untitledBroadcast") }
                                            else { Text(verbatim: broadcast.title) }
                                        } status: {
                                            Text(OfficialPrivateFactsText.broadcastStatusKey(broadcast.facts?.status ?? .unknown))
                                        }
                                        if let facts = broadcast.facts {
                                            OfficialPrivateFactsText.broadcastLine(facts).font(.footnote).foregroundStyle(.secondary)
                                        }
                                        if let reach = broadcast.reach { Text("official.published.reach \(reach)").font(.caption).foregroundStyle(.secondary).monospacedDigit() }
                                        else { Text("official.published.reachUnknown").font(.caption).foregroundStyle(.secondary) }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }.accessibilityIdentifier("official.broadcast.\(broadcast.id)")
                            }
                        }
                } header: { Text("official.published.broadcastsHeader \(broadcasts.count)") }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.listStyle(.insetGrouped)
            .accessibilityIdentifier("official.published.content")
        }.appNavigationTitle("official.published.title").navigationBarTitleDisplayMode(.inline)
    }
    private func publishedEventRow(_ event: OfficialEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // MP om-row: title with the publisher-view status badge beside it.
            titleWithStatus {
                if let title = OfficialPublishedPresentation.nonBlank(event.title) { Text(verbatim: title).foregroundStyle(.primary) }
                else { Text("official.privateParity.published.untitledEvent") }
            } status: {
                OfficialEventStatusLabel(status: event.status, key: OfficialPublishedPresentation.ownerStatusKey(event.status))
                    .accessibilityIdentifier("official.published.eventStatus.\(event.id)")
            }
            // Source sub line: city, then " · category" only when the server sent one.
            let city = OfficialPublishedPresentation.nonBlank(event.city).map { Text(verbatim: $0) } ?? Text(verbatim: "—")
            Group {
                if OfficialPublishedPresentation.nonBlank(event.category) != nil { city + Text(verbatim: " · ") + Text(LocalizedStringKey(event.categoryKey)) }
                else { city }
            }.font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    /// MP om-row: a headline title and its status badge on one row; stacked when a long title or English copy
    /// doesn't fit.
    private func titleWithStatus<Title: View, Status: View>(@ViewBuilder _ title: () -> Title,
                                                            @ViewBuilder status: () -> Status) -> some View {
        let titleView = title().font(.headline).fixedSize(horizontal: false, vertical: true)
        let statusView = status().font(.subheadline).foregroundStyle(.secondary)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                titleView
                Spacer(minLength: 8)
                statusView
            }
            VStack(alignment: .leading, spacing: 4) {
                titleView
                statusView
            }
        }
    }
    /// Mini-program `cy-empty` with a title only.
    private func emptyRow(_ title: LocalizedStringKey, _ detail: LocalizedStringKey? = nil) -> some View {
        // Mini-program `cy-empty` (title, optional sub): a plain secondary row, as Settings shows an empty list.
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(.secondary)
            if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
@MainActor struct OfficialBroadcastStatsView: View {
    let id: Int
    let reader: any OfficialEventReading
    var onLogin: (() -> Void)? = nil
    @State private var reload = 0
    @Environment(\.locale) private var locale
    var body: some View {
        OfficialReadScreen(reader: reader, isPrivate: true, requestID: "stats.\(id).\(reload)", onLogin: onLogin, load: { try await reader.broadcastStats(id: id) }) { stats in
            List {
                if let line = stats.presentedSummaryLine(locale: locale) {
                    Text(verbatim: line).font(.body).accessibilityIdentifier("official.broadcast.summary")
                } else if stats.canRecoverInapp {
                    Text(verbatim: OfficialReadCopy.recoverableDelivery(locale: locale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("official.broadcast." + "recoverable")
                }
                // R7-PC-C6-3: only the stats the page can name; an unknown key is never printed raw.
                let known = stats.rows.filter { OfficialBroadcastStatsText.knownIDs.contains($0.id) }
                if known.isEmpty && stats.presentedSummaryLine(locale: locale) == nil && !stats.canRecoverInapp { Text("official.emptyStats") }
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
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.accessibilityIdentifier("official.stats.content")
        }
        .appNavigationTitle("official.stats").navigationBarTitleDisplayMode(.inline)
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
    @State private var confirmsRecover = false
    @State private var recovering = false
    @State private var recoverError: String?
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { load() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    label()
                    switch phase {
                    case .idle: EmptyView()
                    case .loading:
                        Text("official.published.statsLoading").font(.caption).foregroundStyle(.secondary)
                    case .loaded(let stats):
                        if let line = stats.presentedSummaryLine(locale: locale) {
                            Text(verbatim: line).font(.caption).foregroundStyle(.secondary)
                                .accessibilityIdentifier("official.broadcast.summary")
                        } else if let counts = OfficialBroadcastStatsText.counts(stats) {
                            Text("official.published.statsLine \(counts.reached) \(counts.clicked)").font(.caption).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    case .failed(let note):
                        Text(verbatim: OfficialBroadcastStats.failureLine(serverMessage: note, locale: locale))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(phase == .loading)
            .accessibilityHint(Text("official.published.statsHint"))
            // R10-PC-C6-2: MP official-mine/index.wxml:30 `安全恢复原投递` when the stats say `canRecoverInapp`.
            if case .loaded(let stats) = phase, stats.canRecoverInapp {
                Button("official.broadcast.recover") { confirmsRecover = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(recovering)
                    .accessibilityIdentifier("official.broadcast.recover")
            }
            if let recoverError {
                Text(verbatim: recoverError).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("official.broadcast." + "recoverError")
            }
        }
        .confirmationDialog(Text("official.broadcast.recover"), isPresented: $confirmsRecover, titleVisibility: .visible) {
            Button("official.broadcast.recover.confirm") { recover() }
        } message: {
            Text("official.broadcast.recover.message")
        }
    }
    /// MP index.js:181-197: one request per broadcast at a time; a refusal says why, then the stats are read again.
    private func recover() {
        guard !recovering else { return }
        recovering = true; recoverError = nil
        let scope = reader.scope
        Task {
            defer { recovering = false }
            do {
                try await reader.recoverBroadcast(id: String(id))
            } catch is CancellationError {
                return
            } catch {
                guard reader.scope == scope else { return }
                recoverError = OfficialBroadcastStats.serverNote(error)
                    ?? OfficialReadCopy.text("网络连接失败", "Network connection failed", locale: locale)
            }
            guard reader.scope == scope else { return }
            phase = .idle
            load()
        }
    }
    private func load() {
        guard phase != .loading else { return }
        phase = .loading
        let scope = reader.scope
        Task {
            do {
                let stats = try await reader.broadcastStats(id: id)
                // R8-PC-C6-1 (MP official-mine/index.js:150-178 drops a stale reply): the row goes back to idle,
                // so it is not left disabled on 正在读取复盘….
                guard reader.scope == scope else { phase = .idle; return }
                if stats.summaryLine != nil || OfficialBroadcastStatsText.counts(stats) != nil || stats.canRecoverInapp {
                    phase = .loaded(stats)
                } else { phase = .failed(nil) }
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = reader.scope == scope ? .failed(OfficialBroadcastStats.serverNote(error)) : .idle
            }
        }
    }
}
