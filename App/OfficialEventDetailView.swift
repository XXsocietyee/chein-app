import SwiftUI

/// A readback ticket grants no write authority and survives only its detail visit.
struct OfficialDetailReturnLease {
    let eventID: Int
    let scope: UUID
    let visit: UUID
    func permits(eventID currentEventID: Int, scope currentScope: UUID, visit currentVisit: UUID,
                 visible: Bool, active: Bool) -> Bool {
        eventID == currentEventID && scope == currentScope && visit == currentVisit && visible && active
    }
}

/// `official.detail.*` leaf identifiers. Composed from the catalog-backed prefix so the
/// static localization scan never mistakes an identifier for user-facing copy.
enum OfficialDetailID {
    static let organizer = leaf("organizer"), facts = leaf("facts"), overview = leaf("overview")
    static let story = leaf("story"), cards = leaf("cards"), tasks = leaf("tasks"), rewards = leaf("rewards")
    static let collective = leaf("collective"), rewardFootnote = leaf("rewardFootnote"), cta = leaf("cta"), share = leaf("share")
    static let unavailable = leaf("unavailable"), backToList = leaf("backToList"), network = leaf("network")
    static let service = leaf("service"), topicNameError = leaf("topicNameError"), ctaTopic = leaf("ctaTopic")
    static let empty = leaf("empty"), unknown = leaf("unknown")
    private static func leaf(_ name: String) -> String { "official.detail" + "." + name }
}

@MainActor struct OfficialEventDetailView: View {
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    let id: Int
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator? = nil
    var onLogin: (() -> Void)? = nil
    /// Optional bound-topic names and route; without it THEME missions stay plain rows.
    var topicLinks: OfficialTopicLinks? = nil
    /// Optional Roam jump callback (`goRoam(missionCode)`); falls back to `rootTabSwitch(.roam)`.
    var onOpenRoam: ((Int, String?) -> Void)? = nil
    @StateObject private var sourceObservation = OfficialReadInvalidationObserver()
    @State private var topicNames: [Int: String] = [:]
    @State private var topicNameFailed = false
    @State private var topicNamesScope: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var visit = UUID()
    @State private var readback = UUID()
    @State private var visible = false
    /// PC-C-4-3: MP share button in the CTA bar opens the share card for the loaded event.
    @State private var shareEvent: OfficialEvent?
    @Environment(\.locale) private var locale
    /// Source official-detail: a missing event exits to the list; a network failure keeps retry.
    nonisolated static func issueCopy(_ error: Error) -> OfficialIssueCopy? {
        switch OfficialDetailLoadFailure(error) {
        case .unavailable:
            return OfficialIssueCopy(title: "official.detailParity.unavailable.title", detail: "official.detailParity.unavailable.detail",
                                     identifier: OfficialDetailID.unavailable, backTitle: "official.detailParity.unavailable.back",
                                     backIdentifier: OfficialDetailID.backToList)
        case .network:
            return OfficialIssueCopy(title: "official.detailParity.network.title", detail: "official.detailParity.network.detail",
                                     identifier: OfficialDetailID.network)
        case .other:
            guard OfficialDetailServiceFailure.matches(error) else { return nil }
            return OfficialIssueCopy(title: "official.w206.detail.service.title", detail: "official.w206.detail.service.detail",
                                     identifier: OfficialDetailID.service)
        }
    }
    /// PC-C-4-3: share card for an official event. Unknown facts stay out (em dash on the card, never a guess).
    private func shareContent(_ event: OfficialEvent) -> CYShareCardContent {
        CYShareCardContent(
            kind: .activity,
            eyebrow: appLocalized("official.title", locale: locale),
            title: event.title.isEmpty ? "—" : event.title,
            subtitle: event.subtitle,
            place: event.city,
            artSeed: event.title,
            artSymbol: "flag.checkered",
            brand: appLocalized("share.card.brand", locale: locale))
    }
    var body: some View {
        OfficialReadScreen(reader: reader, requestID: "event.\(id).\(readback)", onLogin: onLogin,
                           issueCopy: OfficialEventDetailView.issueCopy, onBack: { dismiss() },
                           load: { try await reader.detail(id: id) }) { event in
            let presentation = OfficialEventDetailPresentation(event: event, now: Date())
            let namesKey = OfficialTopicNamesKey(eventID: event.id, ids: OfficialDetailTopicLinks.topicIDs(event),
                                                scope: reader.scope, topicScope: topicLinks?.reader.scope)
            let namesVisit = visit
            // pages/activity/official-detail/index phase: an incomplete record is the source empty
            // shell (back to list), an unclassified record keeps em dashes and says so.
            let page = OfficialEventDetailPageState.project(loading: false, event: event)
            if page.phase == .empty {
                CYEmptyState(systemImage: "calendar.badge.exclamationmark", "official.detailParity.unavailable.title",
                             detail: "official.detailParity.unavailable.detail",
                             actionTitle: "official.detailParity.unavailable.back", actionIdentifier: OfficialDetailID.backToList,
                             action: { dismiss() })
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cyDomainPageBackground()
                .accessibilityIdentifier(OfficialDetailID.empty)
            } else {
            List {
                if page.phase == .unknown {
                    Label("official.detailPage.unknown", systemImage: "questionmark.circle")
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier(OfficialDetailID.unknown)
                }
                OfficialEventCard(event: event).questifyCardListRow()
                OfficialOrganizerEntryRow(eventID: event.id, access: actions?.organizer)
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip(LocalizedStringKey(presentation.categoryKey), tone: .neutral)
                    // MP official-detail/index.wxml:31: the 城瘾官方 organizer logo.
                    MPAsset.BrandLogo.cyLogoMark.resizable().scaledToFill()
                        .frame(width: 24, height: 24).clipShape(Circle()).accessibilityHidden(true)
                    Text("official.detailParity.organizer").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier(OfficialDetailID.organizer)
                Section("official.facts") {
                    OfficialDetailFactsStrip(facts: presentation.facts).accessibilityIdentifier(OfficialDetailID.facts)
                    LabeledContent("official.price") { Text("official.priceNotProvided") }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("official.price"))
                        .accessibilityValue(Text("official.priceNotProvided"))
                        .accessibilityIdentifier("official.price")
                }
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYHeroHeader(verbatim: event.title)
                        if let intro = presentation.intro { Text(verbatim: intro).cyText(.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled) }
                    }.fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(OfficialDetailID.overview)
                }
                if !presentation.cards.isEmpty {
                    Section("official.detailParity.cardsHeading") {
                        ForEach(presentation.cards, id: \.index) { card in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                OfficialDetailTextView(value: card.title).cyText(.cardTitle)
                                OfficialDetailTextView(value: card.description).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                            .accessibilityElement(children: .combine)
                        }
                    }.accessibilityIdentifier(OfficialDetailID.cards)
                }
                if let story = presentation.storyDetail {
                    Section("official.detailParity.storyHeading") {
                        Text(verbatim: story).textSelection(.enabled).accessibilityIdentifier(OfficialDetailID.story)
                    }
                }
                if event.isV2 {
                    Section {
                        if event.signed != true {
                            Text("official.detailParity.tasks.signupNote").cyText(.bodyCompact).foregroundStyle(.secondary)
                        }
                        if event.paused {
                            if let reason = presentation.pausedReason { Text("official.detailParity.tasks.paused \(reason)").foregroundStyle(CYColor.dangerText) }
                            else { Text("official.detailParity.tasks.pausedDefault").foregroundStyle(CYColor.dangerText) }
                        }
                        if presentation.missions.isEmpty { CYEmptyState(systemImage: "checklist", "official.detailParity.tasks.empty") }
                        if topicNameFailed {
                            Text("official.w206.detail.topicName.failed").font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier(OfficialDetailID.topicNameError)
                        }
                        ForEach(presentation.missions, id: \.index) { mission in
                            let topicID = mission.binding?.themeTopicID
                            let linked = event.missions.indices.contains(mission.index)
                                ? OfficialDetailTopicLinks.linkedTopic(event.missions[mission.index], signed: event.signed == true) : nil
                            if let topicLinks, let linked {
                                NavigationLink { topicLinks.destination(linked) } label: {
                                    OfficialDetailMissionRow(mission: mission, topicName: topicID.flatMap { topicNames[$0] })
                                }.accessibilityIdentifier("official.mission.\(mission.index)")
                            } else {
                                OfficialDetailMissionRow(mission: mission, topicName: topicID.flatMap { topicNames[$0] })
                                    .accessibilityIdentifier("official.mission.\(mission.index)")
                                OfficialMissionRoamJumpButton(event: event, missionIndex: mission.index, action: mission.action, onOpenRoam: onOpenRoam)
                            }
                        }
                    } header: {
                        HStack {
                            Text("official.detailParity.tasks.heading")
                            Spacer()
                            if let key = presentation.eligibilityKey { Text(LocalizedStringKey(key)) }
                        }.accessibilityIdentifier(OfficialDetailID.tasks)
                    }
                }
                // R7-PC-C4-3 (MP official-detail/index.wxml:155-156): no configured reward, no section.
                if !event.rewards.isEmpty {
                Section("official.detailParity.rewards.heading") {
                    ForEach(Array(event.rewards.enumerated()), id: \.offset) { _, reward in
                        switch reward {
                        case .badge: Label("official.reward.badge", systemImage: "seal")
                        case .coupon: Label("official.reward.coupon", systemImage: "ticket")
                        case .experience(let amount): LabeledContent("official.reward.experience", value: amount)
                        case .collectiveCoupon: Label("official.reward.collective", systemImage: "person.3")
                        }
                    }
                }.accessibilityIdentifier(OfficialDetailID.rewards)
                }
                if let collective = event.collective, collective.enabled {
                    Section("official.collective") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: collective.percent.map { "\($0)%" } ?? "—").cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                                    Text("official.detailParity.collective.lit").cyText(.meta).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(verbatim: "\(collective.current.map(String.init) ?? "—") / \(collective.threshold.map(String.init) ?? "—")").monospacedDigit()
                            }
                            if let fraction = collective.displayFraction {
                                ProgressView(value: fraction).tint(CYColor.brand).accessibilityHidden(true)
                            }
                            Text(LocalizedStringKey(presentation.collectiveTipKey)).cyText(.bodyCompact).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine).accessibilityIdentifier(OfficialDetailID.collective)
                    }
                }
                if !event.rewards.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("official.detailParity.rewardFootnote.issue")
                            Text("official.detailParity.rewardFootnote.settlement")
                        }.cyText(.bodyCompact).foregroundStyle(.secondary)
                            .accessibilityElement(children: .combine).accessibilityIdentifier(OfficialDetailID.rewardFootnote)
                    }
                }
                Section("official.participation") {
                    Text(LocalizedStringKey(reader.isAuthenticated ? event.participationKey : event.statusKey)).accessibilityIdentifier("official.participationState")
                    if event.paused, let reason = event.pausedReason, !reason.isEmpty { Text(verbatim: reason) }
                    if reader.isAuthenticated {
                        if event.signed == true {
                            if event.isV2 { LabeledContent("official.completedTasks", value: "\(event.completedMissionCount)/\(event.missions.count)") }
                            // Missing progress is an em dash (page state), a literal 0 stays "0".
                            else { LabeledContent("official.progress", value: page.progressText) }
                        }
                        if let eligible = event.eligible { Text(eligible ? "official.eligible" : "official.notEligible") }
                    } else {
                        Text("official.signInForProgress")
                        if let onLogin { CYPillButton("official.signIn", style: .secondary, action: onLogin) }
                    }
                }
                if reader.isAuthenticated, let actions {
                    let lease = OfficialDetailReturnLease(eventID: id, scope: reader.scope, visit: visit)
                    OfficialParticipationActions(coordinator: actions, event: event, onReturn: {
                        guard lease.permits(eventID: id, scope: reader.scope, visit: visit,
                                            visible: visible, active: scenePhase == .active) else { return }
                        // Reuse the existing detail GET. Never repeat the action or
                        // infer settlement from its acknowledgement/unknown result.
                        readback = UUID()
                    })
                    OfficialAttendanceSectionView(
                        eventID: id,
                        activityID: OfficialDetailTopicLinks.ctaTopic(event, cta: presentation.cta) ?? id,
                        organizer: false
                    )
                }
                if reader.isOfflineExample { Section { OfficialReadOnlyNotice(offline: true) } }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).cyDomainPageBackground().themeDomain(.player).tint(CYDomainPalette(.player).brand)
            .accessibilityIdentifier("official.detail.content")
            // R7-PC-C4-2 (MP official-detail/index.wxml:199-207 `od-cta-bar`): the source CTA is pinned to the bottom.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if hasCTABar(event: event, presentation: presentation) {
                    ctaBar(event: event, presentation: presentation)
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                        .padding(.vertical, CYSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shareEvent = event } label: { Label("activity.share", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier(OfficialDetailID.share)
                }
            }
            .task(id: namesKey) {
                await loadTopicNames(namesKey, detailVisit: namesVisit)
            }
            }
        }
        .appNavigationTitle("official.detail").navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome(domain: .player)
        .sheet(item: $shareEvent) { event in
            CatalogShareCardView(content: shareContent(event), tint: .sunset)
                .themeDomain(.player)
                .cySheet()
        }
        .onAppear { visible = true }
        .onDisappear { visible = false; visit = UUID() }
        .onChange(of: id) { _, _ in visit = UUID() }
        .onChange(of: reader.scope) { _, _ in visit = UUID() }
        .onChange(of: scenePhase) { _, _ in visit = UUID() }
        .onAppear { sourceObservation.bind(reader) }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in sourceObservation.bind(reader) }
        .onChange(of: sourceObservation.revision) { _, _ in
            guard sourceObservation.isBound(to: reader) else { return }
            if topicNamesScope != reader.scope {
                topicNames = [:]; topicNameFailed = false; topicNamesScope = nil
            }
        }
        .onDisappear { sourceObservation.stop() }
    }
}
extension OfficialEventDetailView {
    /// Source _loadBoundTopicNames: signed-in viewers only; a stale or failed read never blocks the row.
    func loadTopicNames(_ key: OfficialTopicNamesKey, detailVisit: UUID) async {
        // Capture the rendered event/source before enqueueing; an old view task
        // must not resolve its topic IDs under a newly selected official source.
        guard !Task.isCancelled, key.eventID == id, key.scope == reader.scope, visit == detailVisit else { return }
        topicNames = [:]; topicNameFailed = false; topicNamesScope = nil
        guard let topicLinks, reader.isAuthenticated, !key.ids.isEmpty,
              key.topicScope == topicLinks.reader.scope else { return }
        let scope = topicLinks.reader.scope, officialScope = key.scope
        let ids = key.ids
        var names: [Int: String] = [:], failed = false
        for id in ids {
            do {
                let name = try await topicLinks.reader.topicDetail(id: id).name.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty { failed = true } else { names[id] = name }
            } catch { if error is CancellationError { return }; failed = true }
            guard !Task.isCancelled, topicLinks.reader.scope == scope,
                  reader.scope == officialScope, visit == detailVisit else { return }
        }
        guard !Task.isCancelled, reader.scope == officialScope, visit == detailVisit else { return }
        topicNames = names; topicNameFailed = failed; topicNamesScope = officialScope
    }
}
struct OfficialTopicNamesKey: Hashable {
    let eventID: Int
    let ids: [Int]
    let scope: UUID
    let topicScope: UUID?
}
/// Session-provided topic read and destination for missions bound to a topic.
struct OfficialTopicLinks {
    let reader: any TopicReading
    let destination: (Int) -> AnyView
}
/// Source facts strip: label, value and sub line per fact, scrolled horizontally.
struct OfficialDetailFactsStrip: View {
    let facts: [OfficialDetailFact]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CYSpacing.xl) {
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(fact.labelKey)).cyText(.micro).foregroundStyle(CYColor.textSecondary)
                        value(fact.value).cyText(.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                        sub(fact.sub).cyText(.micro).foregroundStyle(CYColor.textSecondary)
                    }.accessibilityElement(children: .combine)
                }
            }.padding(.vertical, 4)
        }
    }
    @ViewBuilder private func value(_ value: OfficialDetailFactValue) -> some View {
        switch value {
        case .verbatim(let text): Text(verbatim: text)
        case .key(let key): Text(LocalizedStringKey(key))
        case .days(let count): Text("official.detailParity.duration.days \(count)")
        case .hours(let count): Text("official.detailParity.duration.hours \(count)")
        }
    }
    @ViewBuilder private func sub(_ sub: OfficialDetailFactSub) -> some View {
        switch sub {
        case .key(let key): Text(LocalizedStringKey(key))
        case .countdown(let countdown): OfficialCountdownText(value: countdown)
        }
    }
}
struct OfficialDetailTextView: View {
    let value: OfficialDetailText
    var body: some View {
        switch value {
        case .verbatim(let text): Text(verbatim: text)
        case .key(let key): Text(LocalizedStringKey(key))
        case .numberedTask(let number): Text("official.detailParity.card.numbered \(number)")
        }
    }
}
struct OfficialDetailMissionRow: View {
    let mission: OfficialDetailMission
    var topicName: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            OfficialDetailTextView(value: mission.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            if let topicName { Text("official.w206.detail.boundTopic \(topicName)").font(.subheadline) }
            OfficialDetailTextView(value: mission.description).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
            CYStatusChip(LocalizedStringKey(mission.action.key), tone: mission.action == .verified ? .success : .neutral, systemImage: symbol)
        }.accessibilityElement(children: .combine)
    }
    private var symbol: String {
        switch mission.action {
        case .verified: return "checkmark.circle"
        case .verify: return "location"
        case .automatic: return "arrow.triangle.2.circlepath"
        case .unsupported: return "nosign"
        }
    }
}

/// R7-PC-C4-2: the pinned source CTA bar (MP `od-cta-bar`).
extension OfficialEventDetailView {
    private func hasCTABar(event: OfficialEvent, presentation: OfficialEventDetailPresentation) -> Bool {
        if topicLinks != nil, OfficialDetailTopicLinks.ctaTopic(event, cta: presentation.cta) != nil { return true }
        if !presentation.cta.isSourceAction { return true }
        return (presentation.cta == .roamArrival || presentation.cta == .roamLight) && (onOpenRoam != nil || rootTabSwitch.isAvailable)
    }
    /// Source CTA wording. Only the theme CTA navigates (to its bound topic); signup stays with
    /// OfficialParticipationActions. An action label that cannot act here is not drawn as a button:
    /// only the waiting / ended states remain, as plain status text.
    @ViewBuilder private func ctaBar(event: OfficialEvent, presentation: OfficialEventDetailPresentation) -> some View {
        if let topicLinks, let topic = OfficialDetailTopicLinks.ctaTopic(event, cta: presentation.cta) {
            NavigationLink { topicLinks.destination(topic) } label: {
                Text(LocalizedStringKey(presentation.cta.key)).frame(maxWidth: .infinity)
            }
            .buttonStyle(CYPillButtonStyle())
            .accessibilityIdentifier(OfficialDetailID.ctaTopic)
        } else if !presentation.cta.isSourceAction {
            Text(LocalizedStringKey(presentation.cta.key))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier(OfficialDetailID.cta)
        } else {
            OfficialDetailRoamJumpSection(event: event, cta: presentation.cta, onOpenRoam: onOpenRoam)
        }
    }
}
