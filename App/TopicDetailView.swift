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
    var ticketWalletDestination: ((Int) -> AnyView)? = nil
    @State private var showingSelfPlay = false
    @State private var showingTickets = false
    @State private var showingSessionSelection = false
    /// Load lifecycle (docs/release/state-machines/views.md). `loadedKey` guards a phase that belongs to a stale key.
    @State private var phase: CYPhase<TopicDetail, TopicScreenIssue> = .idle
    @State private var loadedKey: Key?
    @State private var generation = 0
    @State private var loads = SignedInContentDetailLoadOwner()
    @Environment(\.topicPricingDestination) private var pricingDestination
    @State private var showsPricing = false
    private struct Key: Hashable { let id: Int; let scope: UUID; let configured: Bool }
    private var key: Key { Key(id: id, scope: reader.scope, configured: reader.isConfigured) }
    var body: some View {
        Group {
            if !reader.isConfigured { TopicIssueView(issue: .notConfigured) }
            else if phase.isLoading || loadedKey != key { CYLoadingStateView(rows: 1).accessibilityLabel(Text("topic.loading")) }
            else {
                switch phase {
                case .failed(let issue, _): TopicDetailIssueState(issue: issue) { loads.start { await load() } }
                case .loaded(let detail): content(detail)
                case .idle, .loading, .empty: EmptyView()
                }
            }
        }
        .appNavigationTitle("topic.detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let value = detail {
                ToolbarItem(placement: .topBarTrailing) {
                    UGCSafetyMenuButton(
                        presentation: UGCReportPresentationTarget(
                            target: .topic(id: value.id),
                            subjectTitle: value.name,
                            authorName: value.clubName
                        )
                    )
                    .accessibilityIdentifier("topic.safety.menu")
                }
            }
        }
        .environment(\.ugcSafetySubjectID, detail?.id ?? id)
        .cyPushedChrome(domain: .player)
        .task(id: key) { await loads.run { await load() } }
        .onDisappear { loads.cancel(); generation += 1; settleLoading() }
        .sheet(isPresented: $showsReview) {
            NavigationStack { ContextualReviewComposer(target: .topic(id), owner: reviewOwner) { loads.start { await load() } } }
                .cyPlayerSheetGlass()
        }
        .onChange(of: key) { _, _ in showingSelfPlay = false; showingSessionSelection = false; showingTickets = false }
        .sheet(isPresented: $showingTickets) {
            if let ticketWalletDestination { ticketWalletDestination(id) }
        }
        .sheet(isPresented: $showingSelfPlay) {
            Group {
                if let detail {
                    if let selfPlayDestination { selfPlayDestination(detail) }
                    else { TopicSelfPlayUnavailableSheet(topic: detail) }
                }
            }
            .cyPlayerSheetGlass()
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
                    // Source D3 (hengyin d31517215): no-cover header is the look gradient plus a small route mark.
                    CYCard(variant: .elevated, radius: CYRadius.lg, padding: CYSpacing.xl) {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.title2.weight(.semibold)).foregroundStyle(CYColor.brand)
                                .accessibilityHidden(true)
                            Text(value.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering")
                                .font(CYTypography.label).foregroundStyle(CYColor.brand)
                            Text(verbatim: value.name).font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary)
                            if let subtitle = TopicXcxFacts.heroIntro(value.subtitle) { Text(verbatim: subtitle).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).lineLimit(1) }
                            else { Text("topicXcx.coverHint").font(CYTypography.body).foregroundStyle(CYColor.textSecondary) }
                        }
                    }.accessibilityElement(children: .combine)
                } else {
                    NativeMediaGalleryEntry(sources: covers, scope: key.scope, titleKey: "media.destination.squareImages", compact: true)
                    Text(verbatim: value.name).font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary)
                }
                TopicXcxHero(topic: value)
                // P0-14 生成式 AI 内容显式标识 (`utils/aigc-label.js`): only for `publishMode == ai_simple`.
                if AIGCDisclosure.isAIGenerated(publishMode: value.publishMode) { AIGCLabel() }
                if value.betaFlag == 1 {
                    // Source topic-beta block: badge plus feedback note.
                    HStack(spacing: 8) {
                        Text("topic.source.betaBadge").font(CYTypography.label)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .foregroundStyle(CYColor.brand)
                            .background(Capsule().fill(CYColor.brandSoft))
                        Text("topic.source.betaNote").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                    }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                }
                // Source cover `cv-btn`: 查看详情与报名 moves from the cover to the details part of the page.
                CYPillButton("u9cde.topic.coverDetails", style: .secondary) {
                    withAnimation { proxy.scrollTo(TopicXcxTab.details.anchor, anchor: .top) }
                }.accessibilityIdentifier("topic.cover.details")
                TopicXcxStatBar(cells: TopicXcxFacts.statBar(value))
                TopicXcxTabs(proxy: proxy, productType: value.productType)
            }
            // 详情 tab (mini-program `det3`): title, one-line subtitle, venue card, then the audio guide.
            Section {
                TopicTotalStops(count: value.locationCount, identifier: "topic.totalStops")
                if let subtitle = value.subtitle { Text(verbatim: subtitle).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                if let venue = TopicXcxFacts.venue(value.addressName) {
                    Label { VStack(alignment: .leading, spacing: CYSpacing.xxs) { Text(verbatim: venue.name).font(CYTypography.bodyMedium); if let address = venue.address { Text(verbatim: address).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) } } } icon: { Image(systemName: "mappin.circle.fill").foregroundStyle(CYColor.brand) }
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
                            Text("topicXcx.section.contents").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                            Text(verbatim: introduction).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
                        }
                    } else if !includes.isEmpty {
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
            if value.productType == 2 {
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
            }
            if let activities = value.activities {
                Section("topic.activities") {
                    if activities.isEmpty { Text("topic.noActivities").accessibilityIdentifier("topic.activities.empty") }
                    ForEach(activities) { activity in
                        if let activityDestination {
                            NavigationLink { activityDestination(activity.id) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TopicXcxSessionChip(startDate: activity.startDate)
                                    Text(verbatim: activity.name).font(.headline)
                                    if let address = activity.addressName { Text(verbatim: address) }
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
            // 开局前准备 (`GET api/play/setup`): hidden when neither prep items nor a play window are set.
            PlayTopicPrepSection(topicID: id)
            G6TopicCharactersSection(chapters: value.chapters)
            Section("topic.availability") {
                // Source x-fix2 P-1 (hengyin c878fbb7d): a topic past its sale end only says 已截止, with no sign-up or unlock entry.
                if saleClosed(value) {
                    Label { Text("mpfresh.topic.closed", tableName: "MpFresh") } icon: { Image(systemName: "calendar.badge.exclamationmark") }
                        .accessibilityIdentifier("topic.saleClosed")
                } else {
                    Text(LocalizedStringKey("topic.availability." + String(value.availability.rawValue)))
                }
                if value.merchantClosed { Label("topic.closedNotice", systemImage: "storefront") }
                if value.selfPlay == 1 {
                    TopicPrice(value: value.selfPlayPrice, label: "topic.selfPlayPrice")
                    if value.canOfferPurchase && !saleClosed(value) {
                        CYPillButton("contextSelfPlay.title", style: .secondary) { showingSelfPlay = true }
                            .accessibilityIdentifier("contextSelfPlay.open")
                    }
                }
            }
            Section("topic.comments") {
                if (value.commentCount ?? value.comments.count) == 0 {
                    Text("topicXcx.reviews.emptyTitle").font(.headline).accessibilityIdentifier("topic.reviews.emptyPrompt")
                }
                CYPillButton("context.review.title", style: .secondary) { showsReview = true }.accessibilityIdentifier("topic.openReview")
                TopicReviewsContent(reviews: value.reviews)
                Text("activity.reviewPointsNote").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
            }
            .environment(\.ugcSafetySubjectID, value.id)
            Section {
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
            } header: {
                Text(value.productType == 2 ? "tabBar.passport" : "topic.chapters")
            }.id(TopicXcxTab.nodes.anchor)
            if value.showStoryPaywall {
                Section("topic.lockedStory") {
                    Label("topic.lockedNotice", systemImage: "lock")
                    LabeledContent("topic.lockedChapters", value: String(value.lockedChapterCount)).accessibilityIdentifier("topic.lockedChapters")
                    Text(TopicXcxFacts.showsInStorePerks(value) ? "topicXcx.paywall.detail" : "topicXcx.paywall.detailNoPerks").font(.footnote)
                    if value.selfPlay == 1 && value.canOfferPurchase && !saleClosed(value) {
                        CYPillButton("topicXcx.paywall.unlock", style: .primary) { showingSelfPlay = true }.accessibilityIdentifier("topic.paywall.unlock")
                    }
                }
            }
            TopicStoryParticipationLink(topicID: id, chapters: value.chapters)
            TopicXcxRouteSection(topic: value).id(TopicXcxTab.route.anchor)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .modifier(G6TopicCharactersLoader(chapters: value.chapters))
        .refreshable { await loads.run { await load() } }
        .safeAreaInset(edge: .bottom) {
            TopicXcxActionBar(topic: value, openSessions: { if !showingSessionSelection { showingSessionSelection = true } },
                              openSelfPlay: { showingSelfPlay = true },
                              openPricing: pricingDestination == nil ? nil : { showsPricing = true },
                              openTickets: ticketWalletDestination == nil ? nil : { showingTickets = true },
                              shareURL: PublicContentShareLink.topic(id: value.id),
                              shareTitle: value.name)
        }
        .sheet(isPresented: $showingSessionSelection, onDismiss: { loads.start { await load() } }) {
            TopicSessionSelectionView(detail: value, scope: key.scope, activityDestination: activityDestination)
                .cyPlayerSheetGlass()
        }
        .sheet(isPresented: $showsPricing) {
            if let pricingDestination {
                NavigationStack { pricingDestination(value.id) }
                    .cyPlayerSheetGlass()
            }
        }
        .accessibilityIdentifier("topic.detail.content")
        }
    }
    private var detail: TopicDetail? { phase.value }
    /// Source `topicSaleClosed`: the sale end (endDate) has passed. Mainland wall-clock source, as in the mini-program.
    /// A purchased topic keeps its 去票夹 path; an unparsable end never closes the topic.
    private func saleClosed(_ value: TopicDetail) -> Bool {
        guard !value.isSignUp, let end = HomeFeedDate.parse(value.endDate, sourceTimeZone: TimeZone(identifier: "Asia/Shanghai")) else { return false }
        return Date() >= end
    }
    /// Guard: only an in-flight load falls back to idle; loaded/failed results are kept.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    private func load() async {
        generation += 1
        let operation = generation, captured = key
        phase = .idle; loadedKey = nil
        guard reader.isConfigured else { return }
        phase = .loading
        defer { if operation == generation { settleLoading() } }
        do {
            let result = try await reader.topicDetail(id: id)
            try Task.checkCancellation()
            guard operation == generation, captured == key, !Task.isCancelled else { return }
            phase = .loaded(result); loadedKey = captured
        } catch is CancellationError { }
        catch {
            guard operation == generation, captured == key, !Task.isCancelled else { return }
            phase = .failed(TopicScreenIssue(error), retry: nil); loadedKey = captured
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
                        Text(verbatim: chapter.title).font(.title2)
                        if let description = chapter.description { Text(verbatim: description).textSelection(.enabled) }
                        if itinerary.hasWalkingEstimates {
                            Text("topic.itinerary.estimateNotice").font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("topic.itinerary.notice")
                        }
                    }
                    ForEach(itinerary.stops) { stop in
                        let node = stop.node
                        Section {
                            if let minutes = stop.estimatedWalkingMinutes {
                                TopicWalkingEstimate(minutes: minutes, position: stop.id)
                            }
                            LabeledContent("topic.itinerary.stopNumber", value: String(stop.id + 1)).font(.caption)
                            Text(verbatim: node.name).font(.headline)
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
        }.appNavigationTitle("topic.chapter").navigationBarTitleDisplayMode(.inline).cyHideTabBar()
    }
}

/// Source j5 H1 / 5ea8403f1: a server refusal (审核中 / 已下架 / 未通过, invisible to others) is final: say why and offer 返回,
/// never a retry loop and never the raw backend text. Ordinary failures keep 重试.
@MainActor private struct TopicDetailIssueState: View {
    let issue: TopicScreenIssue
    var retry: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        switch issue {
        case .unavailable:
            CYEmptyState(systemImage: "eye.slash", "mpfresh.topic.refused.title", tableName: "MpFresh", messageIdentifier: "topic.error")
                .safeAreaInset(edge: .bottom) {
                    CYPillButton("mpfresh.topic.back", style: .secondary, tableName: "MpFresh") { dismiss() }
                        .padding(CYSpacing.pageHorizontal)
                        .accessibilityIdentifier("topic.error.back")
                }
        case .failed:
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text("mpfresh.topic.failed.title", tableName: "MpFresh").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary)
                TopicIssueView(issue: issue, retry: retry)
            }
            .padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .notConfigured, .unauthorized:
            TopicIssueView(issue: issue, retry: retry)
        }
    }
}
