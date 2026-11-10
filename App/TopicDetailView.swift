import SwiftUI

@MainActor
struct TopicDetailView: View {
    let id: Int
    let reader: any TopicReading
    var activityDestination: ((Int) -> AnyView)? = nil
    var publicMerchant: PublicMerchantHomeContext? = nil
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var publisherDestination: ((TopicDetail) -> AnyView)? = nil
    var reviewOwner: ContextualReviewCoordinator? = nil
    @State private var showsReview = false
    var selfPlayDestination: ((TopicDetail) -> AnyView)? = nil
    @State private var showingSelfPlay = false
    @State private var showingSessionSelection = false
    @State private var detail: TopicDetail?
    @State private var loadedKey: Key?
    @State private var issue: TopicScreenIssue?
    @State private var loading = false
    @State private var generation = 0
    @State private var loads = SignedInContentDetailLoadOwner()
    @Environment(\.topicPricingDestination) private var pricingDestination
    @State private var showsPricing = false
    private struct Key: Hashable { let id: Int; let scope: UUID; let configured: Bool }
    private var key: Key { Key(id: id, scope: reader.scope, configured: reader.isConfigured) }
    var body: some View {
        Group {
            if !reader.isConfigured { TopicIssueView(issue: .notConfigured) }
            else if loading || loadedKey != key { ScrollView { CYLoadingStateView(rows: 3).padding(.top, CYSpacing.lg) }.accessibilityLabel(Text("topic.loading")) }
            else if let issue { TopicIssueView(issue: issue) { loads.start { await load() } } }
            else if let detail { content(detail) }
        }
        .cyHeroScreen()
        .task(id: key) { await loads.run { await load() } }
        .onDisappear { loads.cancel(); generation += 1; loading = false }
        .sheet(isPresented: $showsReview) {
            NavigationStack { ContextualReviewComposer(target: .topic(id), owner: reviewOwner) { loads.start { await load() } } }
        }
        .onChange(of: key) { _, _ in showingSelfPlay = false; showingSessionSelection = false }
        .sheet(isPresented: $showingSelfPlay) {
            if let detail {
                if let selfPlayDestination { selfPlayDestination(detail) }
                else { TopicSelfPlayUnavailableSheet(topic: detail) }
            }
        }
    }
    private func content(_ value: TopicDetail) -> some View {
        ScrollViewReader { proxy in
        List {
            // Mini-program `det1` hero: cover, type and title, then the stat bar and the 详情 / 故事 / 路线 tabs.
            Section {
                let covers = value.images.isEmpty ? (value.imageURL.map { [$0] } ?? []) : Array(value.images.prefix(9))
                if covers.isEmpty {
                    // Mini-program `cover-brief` (no cover): type, title and one-line hint on an opaque card.
                    CYCard(variant: .elevated, radius: CYRadius.lg, padding: CYSpacing.xl) {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text(value.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering")
                                .font(CYTypography.label).foregroundStyle(CYColor.accentText)
                            Text(verbatim: value.name).font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary)
                            if let subtitle = value.subtitle { Text(verbatim: subtitle).font(CYTypography.body).foregroundStyle(CYColor.textSecondary) }
                            else { Text("topicXcx.coverHint").font(CYTypography.body).foregroundStyle(CYColor.textSecondary) }
                        }
                    }.accessibilityElement(children: .combine)
                } else {
                    NativeMediaGalleryEntry(sources: covers, scope: key.scope, titleKey: "media.destination.squareImages", compact: true)
                    Text(verbatim: value.name).font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary)
                }
                TopicXcxHero(topic: value)
                if value.betaFlag == 1 {
                    // Source topic-beta block: badge plus feedback note.
                    HStack(spacing: 8) {
                        Text("topic.source.betaBadge").font(CYTypography.label)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .foregroundStyle(CYColor.accentText)
                            .background(Capsule().fill(CYColor.accentSoft))
                        Text("topic.source.betaNote").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                    }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                }
                TopicXcxStatBar(cells: TopicXcxFacts.statBar(value))
                TopicXcxTabs(proxy: proxy)
            }
            // 详情 tab (mini-program `det3`): title, one-line subtitle, venue card, then the audio guide.
            Section {
                TopicTotalStops(count: value.locationCount, identifier: "topic.totalStops")
                if let subtitle = value.subtitle { Text(verbatim: subtitle).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                if let venue = TopicXcxFacts.venue(value.addressName) {
                    Label { VStack(alignment: .leading, spacing: CYSpacing.xxs) { Text(verbatim: venue.name).font(CYTypography.bodyMedium); if let address = venue.address { Text(verbatim: address).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) } } } icon: { Image(systemName: "mappin.circle.fill").foregroundStyle(CYColor.accentText) }
                }
                if let audio = value.audioURL, !audio.isEmpty { PlatformAudioHost(rawURL: audio, scope: reader.scope, makeModel: makeAudio) }
            }.id(TopicXcxTab.details.anchor)
            if value.templateCount != 0 { TopicXcxTemplatesSection(templates: TopicXcxFacts.nodeTemplates(value)) }
            // 主题介绍 + 活动内容 (mini-program `det3` second block): long introduction, then what the activity includes.
            let includes = TopicXcxFacts.includes(value)
            if value.introduction != nil || !includes.isEmpty {
                Section {
                    if let introduction = value.introduction {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text("topicXcx.section.intro").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                            Text(verbatim: introduction).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
                        }
                    }
                    if !includes.isEmpty {
                        Text("topicXcx.section.contents").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                        TopicXcxIncludes(rows: includes)
                    }
                }
            }
            if value.startDate != nil || value.endDate != nil || value.merchantCount != nil || value.totalTimeSeconds != nil {
                Section {
                    if let start = value.startDate { LabeledContent("topic.start", value: start) }
                    if let end = value.endDate { LabeledContent("topic.end", value: end) }
                    if let count = value.merchantCount { LabeledContent("topic.merchants", value: String(count)) }
                    if let seconds = value.totalTimeSeconds { LabeledContent("topic.durationSeconds") { TopicXcxDurationText(seconds: seconds) } }
                }
            }
            if let records = reader as? any TopicThemeRecordsReading {
                // Source 我的游玩记录 row; always shown, the sheet handles empty/sign-in states.
                Section {
                    NavigationLink { TopicThemeRecordsView(topicID: value.id, topicName: value.name, reader: records) } label: {
                        Label("topicXcx.records.title", systemImage: "clock")
                    }.accessibilityIdentifier("topic.records.entry")
                }
            }
            Section("topic.source.sessions") {
                if value.tickets.isEmpty { Text("topic.noTickets") }
                ForEach(Array(value.tickets.enumerated()), id: \.offset) { _, ticket in
                    // Mini-program `sess`: name / time / meeting point / refund on the left, price and seats left on the right.
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: ticket.name).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                            if let session = TopicXcxFacts.sessionTime(start: ticket.startTime, end: ticket.endTime) { Text(verbatim: session).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                            else {
                                if let start = ticket.startTime { LabeledContent("topic.start", value: start) }
                                if let end = ticket.endTime { LabeledContent("topic.end", value: end) }
                            }
                            if let meeting = ticket.meetingPoint { Text("topic.source.meetingPoint \(meeting)").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                            if let refund = ticket.refundRule { Text("topic.source.refundRule \(refund)").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        }
                        Spacer(minLength: CYSpacing.sm)
                        VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                            TopicPrice(value: ticket.price, label: "topic.price").font(CYTypography.numericBody).monospacedDigit()
                            if let remaining = ticket.remaining { Text("topic.source.seatsLeft \(remaining)").font(CYTypography.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary) }
                            else { Text("topic.source.seatsUnknown").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        }
                    }.accessibilityElement(children: .combine)
                }
                if !value.tickets.isEmpty { Text("topic.source.sessionNote").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
            }.id("topicXcx.anchor.sessions")
            if let activities = value.activities {
                Section("topic.activities") {
                    if activities.isEmpty { Text("topic.noActivities").accessibilityIdentifier("topic.activities.empty") }
                    ForEach(activities) { activity in
                        if let activityDestination {
                            NavigationLink { activityDestination(activity.id) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TopicXcxSessionChip(startDate: activity.startDate)
                                    Text(verbatim: activity.name).font(CYTypography.cardTitle)
                                    if let address = activity.addressName { Text(verbatim: address).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                                    if let start = activity.startDate { LabeledContent("topic.start", value: start) }
                                    if let end = activity.endDate { LabeledContent("topic.end", value: end) }
                                }
                            }.accessibilityIdentifier("topic.activity.\(activity.id)")
                        } else { Text(verbatim: activity.name) }
                    }
                }
            }
            if let publisherDestination { publisherDestination(value) }
            let lineup = TopicXcxFacts.lineup(value)
            if !lineup.isEmpty { Section("topicXcx.section.lineup") { TopicXcxLineup(members: lineup) } }
            Section("topic.availability") {
                Text(LocalizedStringKey("topic.availability." + String(value.availability.rawValue)))
                if value.merchantClosed { Label("topic.closedNotice", systemImage: "storefront") }
                if value.selfPlay == 1 {
                    TopicPrice(value: value.selfPlayPrice, label: "topic.selfPlayPrice")
                    if value.canOfferPurchase {
                        CYPillButton("contextSelfPlay.title", systemImage: "play.fill") { showingSelfPlay = true }
                            .accessibilityIdentifier("contextSelfPlay.open").e1ActionRow()
                    }
                }
            }
            Section("topic.comments") {
                if (value.commentCount ?? value.comments.count) == 0 {
                    // Source ratings empty state.
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text("topicXcx.reviews.emptyTitle").font(CYTypography.cardTitle)
                        Text("topicXcx.reviews.emptyDetail").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    }.accessibilityIdentifier("topic.reviews.emptyPrompt")
                }
                CYPillButton("context.review.title", style: .secondary, systemImage: "square.and.pencil") { showsReview = true }.accessibilityIdentifier("topic.openReview").e1ActionRow()
                TopicReviewsContent(reviews: value.reviews)
            }
            Section("topic.chapters") {
                if value.chapters.isEmpty {
                    Text("topic.noChapters").foregroundStyle(.secondary)
                }
                // Index identity preserves source order even when backend IDs are absent/duplicated.
                ForEach(Array(value.chapters.enumerated()), id: \.offset) { _, chapter in
                    NavigationLink {
                        TopicChapterView(chapter: chapter, reader: reader, scope: key.scope, publicMerchant: publicMerchant, makeExternalMaps: makeExternalMaps)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(verbatim: chapter.title)
                            if let minutes = chapter.totalTimeMinutes {
                                LabeledContent("topic.durationMinutes", value: String(minutes)).font(.caption)
                            }
                            LabeledContent("topic.visibleChapterStops", value: String(chapter.nodes.count)).font(.caption)
                        }
                    }.accessibilityIdentifier("topic.chapter.\(chapter.id)")
                }
            }.id(TopicXcxTab.nodes.anchor)
            if value.showStoryPaywall {
                Section("topic.lockedStory") {
                    Label("topic.lockedNotice", systemImage: "lock")
                    LabeledContent("topic.lockedChapters", value: String(value.lockedChapterCount)).accessibilityIdentifier("topic.lockedChapters")
                    Text("topicXcx.paywall.detail").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    if value.selfPlay == 1 && value.canOfferPurchase {
                        CYPillButton("topicXcx.paywall.unlock", systemImage: "lock.open") { showingSelfPlay = true }.accessibilityIdentifier("topic.paywall.unlock").e1ActionRow()
                    }
                }
            }
            TopicStoryParticipationLink(topicID: id, chapters: value.chapters)
            TopicXcxRouteSection(topic: value).id(TopicXcxTab.route.anchor)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .refreshable { await loads.run { await load() } }
        .safeAreaInset(edge: .bottom) {
            TopicXcxActionBar(topic: value, openSessions: { if !showingSessionSelection { showingSessionSelection = true } },
                              openSelfPlay: { showingSelfPlay = true },
                              openPricing: pricingDestination == nil ? nil : { showsPricing = true })
        }
        .sheet(isPresented: $showingSessionSelection, onDismiss: { loads.start { await load() } }) {
            TopicSessionSelectionView(detail: value, scope: key.scope, activityDestination: activityDestination)
        }
        .sheet(isPresented: $showsPricing) { if let pricingDestination { NavigationStack { pricingDestination(value.id) } } }
        .accessibilityIdentifier("topic.detail.content")
        }
    }
    private func load() async {
        generation += 1
        let operation = generation, captured = key
        detail = nil; issue = nil; loadedKey = nil
        guard reader.isConfigured else { loading = false; return }
        loading = true
        defer { if operation == generation { loading = false } }
        do {
            let result = try await reader.topicDetail(id: id)
            try Task.checkCancellation()
            guard operation == generation, captured == key, !Task.isCancelled else { return }
            detail = result; loadedKey = captured
        } catch is CancellationError { }
        catch {
            guard operation == generation, captured == key, !Task.isCancelled else { return }
            issue = TopicScreenIssue(error); loadedKey = captured
        }
    }
}

@MainActor
struct TopicChapterView: View {
    let chapter: TopicChapter
    let reader: any TopicReading
    let scope: UUID
    var publicMerchant: PublicMerchantHomeContext? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    private var itinerary: TopicChapterItinerary { TopicChapterItinerary(chapter: chapter) }
    var body: some View {
        Group {
            if scope != reader.scope { TopicIssueView(issue: .unavailable) }
            else {
                List {
                    Section {
                        CYHeroHeader(verbatim: chapter.title).e1HeroRow()
                        if let description = chapter.description { Text(verbatim: description).textSelection(.enabled) }
                        if itinerary.hasWalkingEstimates {
                            Text("topic.itinerary.estimateNotice").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                                .accessibilityIdentifier("topic.itinerary.notice")
                        }
                    }
                    ForEach(itinerary.stops) { stop in
                        let node = stop.node
                        Section {
                            if let minutes = stop.estimatedWalkingMinutes {
                                TopicWalkingEstimate(minutes: minutes, position: stop.id)
                            }
                            LabeledContent("topic.itinerary.stopNumber", value: String(stop.id + 1)).font(CYTypography.meta).monospacedDigit()
                            Text(verbatim: node.name).font(CYTypography.cardTitle)
                            if let description = node.description { Text(verbatim: description).textSelection(.enabled) }
                            if let address = node.address { Text(verbatim: address) }
                            PlatformExternalMapHost(destination: .init(name: node.name, address: node.address, latitude: node.latitude, longitude: node.longitude), scope: scope, makeModel: makeExternalMaps)
                            if let hours = node.businessTime { Text(verbatim: hours) }
                            if let template = node.template {
                                Text(verbatim: template.title)
                                if let difficulty = template.difficulty { Text(verbatim: difficulty) }
                                if let players = template.players { Text(verbatim: players) }
                                if let duration = template.duration { LabeledContent("topic.durationMinutes", value: String(duration)) }
                            }
                            TopicXcxNodeFootView(node: node)
                            ForEach(Array(node.merchants.enumerated()), id: \.offset) { _, merchant in
                                if let owner = PublicMerchantOwnerID(merchant.memberID), let publicMerchant {
                                    NavigationLink { PublicMerchantHomeView(target: .ownerMemberID(owner), context: publicMerchant) } label: {
                                        Text(verbatim: merchant.name)
                                    }.accessibilityIdentifier("merchant.publicHome.topicEntry")
                                } else { Text(verbatim: merchant.name) }
                                if let hours = merchant.businessTime { Text(verbatim: hours).font(.caption) }
                            }
                        }
                    }
                }
            }
        }.cyHeroScreen()
    }
}
