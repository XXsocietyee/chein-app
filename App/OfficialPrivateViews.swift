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
            List {
                // Mini-program `oi-hero`: eyebrow, headline and one explanatory paragraph above the invitations.
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("officialInbox.hero.eyebrow").font(CYTypography.label).foregroundStyle(palette.textSecondary)
                        CYHeroHeader("officialInbox.hero.title", subtitle: "officialInbox.hero.sub")
                    }.accessibilityElement(children: .combine)
                }
                if rows.isEmpty {
                    CYEmptyState(systemImage: "envelope.open", "official.inbox.empty")
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        if row.title.isEmpty {
                            CYListRow("official.inviteUntitled", trailing: .none) { CYRowIcon(systemImage: "envelope") }
                        } else {
                            CYListRow(verbatim: row.title, trailing: .none) { CYRowIcon(systemImage: "envelope") }
                        }
                        if let title = row.eventTitle, !title.isEmpty { Text(verbatim: title) }
                        // Source meta line: "(city ‖ 全国) · role".
                        (cityText(row) + Text(verbatim: " · ") + roleText(row)).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                        Text(LocalizedStringKey(row.scopeKey)).font(CYTypography.caption).foregroundStyle(palette.textTertiary)
                        if let note = row.roleNoteTuple {
                            Text(verbatim: c.t(note.zh, note.en)).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
                        }
                        if let cap = row.capacity {
                            Text(verbatim: c.t("承接名额 \(cap)", "Capacity \(cap)")).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
                        }
                        if let facts = row.windowFacts { OfficialPrivateFactsText.window(facts.window).font(CYTypography.caption) }
                        if let summary = row.responsibilitySummary, !summary.isEmpty, summary != row.title {
                            Text(verbatim: summary).font(CYTypography.meta)
                        }
                        if row.isPaused {
                            Text(verbatim: c.t("本场活动已暂停，恢复前以主办通知为准。",
                                              "This event is paused. Updates will be shared by the organizer before resuming."))
                                .font(CYTypography.caption).foregroundStyle(palette.warning)
                        }
                        CYStatusChip(LocalizedStringKey(row.sourceStatusKey), tone: row.isPaused ? .warning : .neutral, systemImage: "envelope")
                        if let status = row.status, row.statusKey == "official.status.unknown" { Text(verbatim: status.isEmpty ? "—" : status).font(CYTypography.caption) }
                    }
                    .cyDomainCard(padding: CYSpacing.md)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("official.invite.\(row.id)")
                    if let actions { OfficialInviteResponseActions(coordinator: actions, invite: row, publisher: publisher) }
                }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(palette.bgPage)
            .themeDomain(.player)
            .accessibilityIdentifier("official.inbox.content")
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
                if let actions {
                    Section {
                        NavigationLink("officialAction.publish") { OfficialPublishEditor(coordinator: actions) }
                        NavigationLink("officialAction.broadcast") { OfficialBroadcastEditor(coordinator: actions) }
                    }
                }
                // Source official-mine always shows both sections with counts and per-section empty copy.
                let events = OfficialEventFilter.visible(value.events, bucket: .mine)
                let broadcasts = value.broadcasts.filter { $0.id > 0 }
                Section {
                    if events.isEmpty { emptyRow("official.published.eventsEmpty", "official.published.eventsEmptyDetail") }
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
                                NavigationLink { OfficialBroadcastStatsView(id: broadcast.id, reader: reader, onLogin: onLogin) } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if broadcast.title.isEmpty { Text("official.untitled") }
                                        else { Text(verbatim: broadcast.title).font(.headline) }
                                        if let facts = broadcast.facts {
                                            OfficialPrivateFactsText.broadcastLine(facts).font(.subheadline)
                                            Text(OfficialPrivateFactsText.broadcastStatusKey(facts.status)).font(.caption)
                                        }
                                        if let content = broadcast.content { Text(verbatim: content).lineLimit(3) }
                                        if let reach = broadcast.reach { Text("official.published.reach \(reach)").font(.caption).foregroundStyle(.secondary) }
                                    }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let title = OfficialPublishedPresentation.nonBlank(event.title) { Text(verbatim: title).font(CYTypography.cardTitle) }
                else { Text("official.privateParity.published.untitledEvent").font(CYTypography.cardTitle) }
                Spacer(minLength: 8)
                Text(LocalizedStringKey(OfficialPublishedPresentation.ownerStatusKey(event.status)))
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(palette.bgRaised))
                    .accessibilityIdentifier("official.published.eventStatus.\(event.id)")
            }
            // Source sub line: city, then " · category" only when the server sent one.
            let city = OfficialPublishedPresentation.nonBlank(event.city).map { Text(verbatim: $0) } ?? Text(verbatim: "—")
            Group {
                if OfficialPublishedPresentation.nonBlank(event.category) != nil { city + Text(verbatim: " · ") + Text(LocalizedStringKey(event.categoryKey)) }
                else { city }
            }.font(.subheadline).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true)
    }
    /// Mini-program `cy-empty` with a title only.
    private func emptyRow(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        // Mini-program `cy-empty` (title + sub): quiet centred empty row.
        VStack(spacing: CYSpacing.xs) {
            Text(title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textSecondary)
            Text(detail).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, CYSpacing.md).accessibilityElement(children: .combine)
    }
}
@MainActor struct OfficialBroadcastStatsView: View {
    let id: Int
    let reader: any OfficialEventReading
    var onLogin: (() -> Void)? = nil
    var body: some View {
        OfficialReadScreen(reader: reader, isPrivate: true, requestID: "stats.\(id)", onLogin: onLogin, load: { try await reader.broadcastStats(id: id) }) { stats in
            List {
                if stats.rows.isEmpty { Text("official.emptyStats") }
                ForEach(stats.rows) { row in
                    LabeledContent {
                        switch row.value {
                        case .text(let value): Text(verbatim: value)
                        case .number(let value): Text(verbatim: NSDecimalNumber(decimal: value).stringValue)
                        case .flag(let value): Text(value ? "official.yes" : "official.no")
                        case .unsupported: EmptyView()
                        }
                    } label: {
                        switch row.id {
                        case "reach": Text("official.reach")
                        case "read", "reads": Text("official.reads")
                        case "click", "clicks": Text("official.clicks")
                        default: Text(verbatim: row.id)
                        }
                    }
                }
                Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
            }.accessibilityIdentifier("official.stats.content")
        }.appNavigationTitle("official.stats").navigationBarTitleDisplayMode(.inline)
    }
}
