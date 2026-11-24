import SwiftUI

@MainActor
struct TopicDetailView: View {
    @Environment(\.cyPalette) private var palette
    let id: Int
    let reader: any TopicReading
    var preferSession = false
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
    /// Continuity r1 (6): which bar button opened the self-play / tickets / pricing sheet now up; nil for every other opener.
    /// Cleared on dismiss. The session sheet has no other opener, so it always zooms from the bar.
    @State private var barSheetOrigin: TopicBarSheet?
    @Namespace private var barHero
    /// Load lifecycle (docs/release/state-machines/views.md). `loadedKey` guards a phase that belongs to a stale key.
    @State private var phase: CYPhase<TopicDetail, TopicScreenIssue> = .idle
    @State private var loadedKey: Key?
    @State private var generation = 0
    @State private var loads = SignedInContentDetailLoadOwner()
    @Environment(\.topicPricingDestination) private var pricingDestination
    @Environment(\.topicEditorDestination) private var editorDestination
    @Environment(\.locale) private var locale
    @Environment(\.popupCloseActions) private var popupCloseActions
    @State private var showsPricing = false
    @State private var showsEditor = false
    @State private var showingGraduateBetaConfirm = false
    @State private var showingClubTransferPicker = false
    @State private var transferClubs: [ClubRecord] = []
    @State private var selectedTransferClub: ClubRecord?
    @State private var showingTransferConfirm = false
    @State private var showingTransferredResult = false
    @State private var transferredTopicID: Int?
    @State private var showingContactPromptModal = false
    @State private var showingContactSheet = false
    @State private var contactRealName = ""
    @State private var contactPhone = ""
    @State private var popupBusy = false
    @State private var resultSheetTitle: String?
    @State private var resultSheetMessage: String?
    @State private var topicToastMessage: String?
    @State private var heroScrolledAway = false
    @State private var tab: TopicXcxTab = .details
    @State private var tabsPinned = false
    /// The top of the list in the window: tabs that scroll above it pin.
    @State private var pinLine: CGFloat = 0
    /// The topic list is on screen (not covered by a pushed page); see the inline tabs' `onDisappear`.
    @State private var topicPageVisible = false
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
        // verify-r1 3.1 / 1.3: no 路线详情 over the hero; the topic's name appears inline once the hero has scrolled away.
        .navigationTitle(heroScrolledAway ? (detail?.name ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let value = detail {
                ToolbarItem(placement: .topBarTrailing) {
                    TopicXcxToolbarActions(shareURL: PublicContentShareLink.topic(id: value.id), shareTitle: value.name)
                }
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
        // PC-B-1-8 / PC-C-1-9 (type-and-chrome §3): the hero is an inset list row, not a full-bleed image, so the page keeps
        // the system back and its edge swipe; share / 举报 stay in the bar beside it.
        .cyPushedChrome(domain: .player)
        .task(id: key) { await loads.run { await load() } }
        .onDisappear { loads.cancel(); generation += 1; settleLoading() }
        .sheet(isPresented: $showsReview) {
            NavigationStack { ContextualReviewComposer(target: .topic(id), owner: reviewOwner) { loads.start { await load() } } }
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
        }
        .onChange(of: key) { _, _ in showingSelfPlay = false; showingSessionSelection = false; showingTickets = false }
        .sheet(isPresented: $showingTickets, onDismiss: { barSheetOrigin = nil }) {
            if let ticketWalletDestination {
                ticketWalletDestination(id)
                    .modifier(TopicBarHeroDestination(sheet: .tickets, origin: barSheetOrigin, namespace: barHero))
                    .cyDomainSheet(detents: [.half, .full])
            }
        }
        .sheet(isPresented: $showingSelfPlay, onDismiss: { barSheetOrigin = nil }) {
            Group {
                if let detail {
                    if let selfPlayDestination { selfPlayDestination(detail) }
                    else { TopicSelfPlayUnavailableSheet(topic: detail) }
                }
            }
            .modifier(TopicBarHeroDestination(sheet: .selfPlay, origin: barSheetOrigin, namespace: barHero))
            .cyPlayerSheetGlass()
            .cyDomainSheet(detents: [.half, .full])
        }
        .sheet(isPresented: $showingClubTransferPicker) {
            CYOptionSheet(
                title: PlayCloseCopy.text("选择承接俱乐部", "Choose host club", locale),
                items: transferClubs.map { club in
                    CYOptionSheetItem(id: club.id, title: club.name, subtitle: club.city, systemImage: "person.3")
                },
                selectedID: selectedTransferClub?.id,
                closeIdentifier: cyAccessibilityID(id: "topic.transfer.clubSheet.close"),
                onSelect: { clubID in
                    showingClubTransferPicker = false
                    selectedTransferClub = transferClubs.first(where: { $0.id == clubID })
                    showingTransferConfirm = selectedTransferClub != nil
                },
                onClose: { showingClubTransferPicker = false }
            )
            .cyDomainSheet(detents: [.half, .full])
        }
        .sheet(isPresented: $showingContactSheet) {
            PlayCloseSheetHost(
                title: PlayCloseCopy.text("补全姓名和手机号", "Complete Name & Phone", locale),
                detents: [.half],
                onClose: { showingContactSheet = false }
            ) {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    CYField(
                        label: PlayCloseCopy.text("真实姓名", "Real name", locale),
                        placeholder: PlayCloseCopy.text("请输入姓名", "Enter name", locale),
                        text: $contactRealName,
                        isRequired: true
                    )
                    CYField(
                        label: PlayCloseCopy.text("手机号", "Phone number", locale),
                        placeholder: PlayCloseCopy.text("请输入手机号", "Enter phone", locale),
                        text: $contactPhone,
                        isRequired: true
                    )
                    Button {
                        saveContactBeforeSelfPlay()
                    } label: {
                        Text(verbatim: PlayCloseCopy.text("保存并继续", "Save and continue", locale))
                    }
                    .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, isLoading: popupBusy))
                    .disabled(popupBusy || contactRealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(CYSpacing.pageHorizontal)
                .padding(.bottom, CYSpacing.lg)
            }
        }
        .sheet(isPresented: Binding(get: { resultSheetTitle != nil }, set: { if !$0 { resultSheetTitle = nil; resultSheetMessage = nil } })) {
            if let title = resultSheetTitle, let message = resultSheetMessage {
                PlayCloseResultSheet(
                    title: title,
                    message: message,
                    onPrimary: nil,
                    onClose: { resultSheetTitle = nil; resultSheetMessage = nil }
                )
            }
        }
        .cyModalOverlay(isPresented: showingGraduateBetaConfirm) {
            CYModal(
                title: PlayCloseCopy.text("转为正式主题", "Graduate to Official Topic", locale),
                message: PlayCloseCopy.text("转正后不再显示 Beta 标记。主题内容、已售出的票和进行中的行程都不受影响。", "The Beta tag will be removed. Topic content, sold tickets, and active runs stay unaffected.", locale),
                cancelTitle: PlayCloseCopy.cancel(locale),
                confirmTitle: PlayCloseCopy.text("确认转正", "Confirm", locale),
                isConfirmLoading: popupBusy,
                confirmIdentifier: "topic.graduateBeta.confirm",
                onCancel: { showingGraduateBetaConfirm = false },
                onConfirm: { graduateCurrentBetaTopic() }
            )
        }
        .cyModalOverlay(isPresented: showingTransferConfirm) {
            if let club = selectedTransferClub {
                CYModal(
                    title: PlayCloseCopy.text("移交给俱乐部承接", "Transfer to Club", locale),
                    message: PlayCloseCopy.text("将复制一份新的城市定向主题(有人带),挂到「\(club.name)」名下。原草稿与历史记录会保留。", "Creates an instructor-led City Orienteering copy under \"\(club.name)\".", locale),
                    cancelTitle: PlayCloseCopy.cancel(locale),
                    confirmTitle: PlayCloseCopy.text("确认移交", "Confirm transfer", locale),
                    isConfirmLoading: popupBusy,
                    confirmIdentifier: "topic.transferClub.confirm",
                    onCancel: { showingTransferConfirm = false },
                    onConfirm: { performTopicClubTransfer(club) }
                )
            }
        }
        .cyModalOverlay(isPresented: showingTransferredResult) {
            CYModal(
                title: PlayCloseCopy.text("已移交", "Transferred", locale),
                message: PlayCloseCopy.text("已生成新的城市定向草稿，去配置票种并邀请该俱乐部承接?", "Created a new City Orienteering draft. Configure tickets and invite the club to host?", locale),
                cancelTitle: PlayCloseCopy.text("留在本页", "Stay here", locale),
                confirmTitle: PlayCloseCopy.text("去配置票种", "Configure tickets", locale),
                confirmIdentifier: "topic.transferred.configure",
                onCancel: { showingTransferredResult = false },
                onConfirm: {
                    showingTransferredResult = false
                    if pricingDestination != nil {
                        showsPricing = true
                    } else if let transferredTopicID {
                        topicToastMessage = PlayCloseCopy.text("已生成新草稿 #\(transferredTopicID)", "Created draft #\(transferredTopicID)", locale)
                    }
                }
            )
        }
        .cyModalOverlay(isPresented: showingContactPromptModal) {
            CYModal(
                title: PlayCloseCopy.text("还差姓名和手机号", "Name and phone needed", locale),
                message: PlayCloseCopy.text("建单要用你的真实姓名和手机号，补一次就好，之后不用再填。", "Your real name and phone are needed to place this order. Save them once for future orders.", locale),
                cancelTitle: PlayCloseCopy.cancel(locale),
                confirmTitle: PlayCloseCopy.text("去填写", "Fill in", locale),
                confirmIdentifier: "topic.contactPrompt.fill",
                onCancel: { showingContactPromptModal = false },
                onConfirm: {
                    showingContactPromptModal = false
                    showingContactSheet = true
                }
            )
        }
        .cyToast(verbatimMessage: $topicToastMessage)
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
                            // verify-r1 PL-14: the type is a fact, not a link or a status, so it is ink, not blue.
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.title2.weight(.semibold)).foregroundStyle(CYColor.textSecondary)
                                .accessibilityHidden(true)
                            Text(value.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering")
                                .cyText(.label, weight: .semibold).foregroundStyle(CYColor.textSecondary)
                            Text(verbatim: value.name).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                            if let subtitle = TopicXcxFacts.heroIntro(value.subtitle) { Text(verbatim: subtitle).cyText(.body).foregroundStyle(CYColor.textSecondary).lineLimit(1) }
                            else { Text("topicXcx.coverHint").cyText(.body).foregroundStyle(CYColor.textSecondary) }
                        }
                    }.accessibilityElement(children: .combine)
                } else {
                    // verify-r1 3.1 / PL-23 (`169:6954`): the photo is the hero and carries no text, so a cover that
                    // fails to load can never sit under the title. The title and its facts follow below.
                    Group {
                        if RetainedPublicImageReader().enabled {
                            NativeMediaGalleryEntry(sources: covers, scope: key.scope, titleKey: "media.destination.squareImages", compact: true)
                                .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
                        } else {
                            // Coordinator review: photos cannot load here (no image storage), so the hero is the designed
                            // cover, never a 图片暂不可用 line.
                            CYDesignedCover(title: value.name)
                                .aspectRatio(16 / 9, contentMode: .fit)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: CYSpacing.md, trailing: 0))
                    .listRowBackground(Color.clear)
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(value.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering")
                            .cyText(.meta, weight: .semibold)
                            .foregroundStyle(palette.textSecondary)
                        Text(verbatim: value.name)
                            .cyText(.pageTitle)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("topic.detail.title")
                    }
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Color.clear)
                }
                TopicXcxHero(topic: value).listRowBackground(Color.clear)
                // P0-14 生成式 AI 内容显式标识 (`utils/aigc-label.js`): only for `publishMode == ai_simple`.
                if AIGCDisclosure.isAIGenerated(publishMode: value.publishMode) { AIGCLabel() }
                if value.betaFlag == 1 {
                    // Source topic-beta block: badge plus feedback note.
                    HStack(spacing: 8) {
                        Text("topic.source.betaBadge").cyText(.label)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .foregroundStyle(CYColor.brand)
                            .background(Capsule().fill(CYColor.brandSoft))
                        Text("topic.source.betaNote").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                    }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                }
                // Design hand-off r1 PL-23: one hero, then the title and stats. The cover's 查看详情与报名 scroll button is
                // gone: the pinned 详情 / 故事 / 路线 tabs and the sticky bar (price left, primary right) carry those paths.
                TopicXcxStatBar(cells: TopicXcxFacts.statBar(value), stops: value.locationCount)
                    .listRowBackground(Color.clear)
                // One container for 详情 / 故事 / 路线: inline here, and pinned under the bar once it scrolls away.
                TopicXcxTabs(proxy: proxy, productType: value.productType).selection($tab)
                    .opacity(tabsPinned ? 0 : 1)
                    .onGeometryChange(for: Bool.self) { $0.frame(in: .global).minY < pinLine } action: { pinned in
                        if tabsPinned != pinned { tabsPinned = pinned }
                    }
                    // A tab tap scrolls with `scrollTo`, which jumps: the row leaves the list without ever reporting a
                    // position above the pin line (integ-r3). It sits near the top of the list, so a row that leaves
                    // while the page is still on screen has left over the top: pin. Checked a run loop later, so a
                    // page pushed over the topic (which also ends the row's appearance) does not count.
                    .onDisappear {
                        Task { @MainActor in if topicPageVisible { tabsPinned = true } }
                    }
                    .listRowBackground(Color.clear)
            }
            // verify-r1 3.1 (`169:6954`): the hero block reads as one page header, not as list rows with dividers.
            .listRowSeparator(.hidden)
            // 详情 tab (mini-program `det3`): title, one-line subtitle, venue card, then the audio guide.
            Section {
                // Coordinator review: an unknown or zero stop count is not a fact worth a row.
                if (value.locationCount ?? 0) > 0 {
                    TopicTotalStops(count: value.locationCount, identifier: "topic.totalStops")
                }
                if let subtitle = value.subtitle { Text(verbatim: subtitle).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                if let venue = TopicXcxFacts.venue(value.addressName) {
                    Label { VStack(alignment: .leading, spacing: CYSpacing.xxs) { Text(verbatim: venue.name).cyText(.bodyMedium); if let address = venue.address { Text(verbatim: address).cyText(.meta).foregroundStyle(CYColor.textTertiary) } } } icon: { Image(systemName: "mappin.circle.fill").foregroundStyle(CYColor.brand) }
                }
                if let audio = value.audioURL, !audio.isEmpty { PlatformAudioHost(rawURL: audio, scope: reader.scope, makeModel: makeAudio) }
            }.id(TopicXcxTab.details.anchor)
            if let cast = value.castConfig, !cast.cast.isEmpty {
                Section("topic.cast") { TopicCastRow(config: cast) }
            }
            // 节点介绍 (MP `det4`, owner 2026-11-19): one card per chapter, endings excluded (port plan r1 C9).
            TopicChapterCardsSection(cards: TopicChapterCards.cards(chapters: value.chapters, routeCover: value.imageURL))
            // 活动内容 (MP `det3`, 2026-11-21): the story only. Practical lines from the same text, prices, what is
            // included, pause/resume and finishing rewards move to 出发前 below (port plan r1 C13).
            let story = TopicDepartNotes.split(value.introduction).story
            if !story.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("topicXcx.section.contents").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                        Text(verbatim: story).cyText(.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
                            .accessibilityIdentifier("topic.story")
                    }
                }
            }
            TopicDepartSection(items: TopicDepartNotes.items(for: value))
            // R7-PC-B1-14 (r1 PC-B-1-10): MP has one stat bar; the duplicate start / end / merchants / duration rows are gone.
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
                        // Grouped session card: one element. The visible rows stay in source order.
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: ticket.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            if let session = TopicXcxFacts.sessionTime(start: ticket.startTime, end: ticket.endTime) { Text(verbatim: session).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                            else {
                                if let start = ticket.startTime { LabeledContent("topic.start", value: start) }
                                if let end = ticket.endTime { LabeledContent("topic.end", value: end) }
                            }
                            if let meeting = ticket.meetingPoint { Text("topic.source.meetingPoint \(meeting)").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                            if let refund = ticket.refundRule { Text("topic.source.refundRule \(refund)").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                        }
                        Spacer(minLength: CYSpacing.sm)
                        VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                            TopicPrice(value: ticket.price, label: "topic.price").cyText(.numericBody).monospacedDigit()
                            if let remaining = ticket.remaining { Text("topic.source.seatsLeft \(remaining)").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary) }
                            else { Text("topic.source.seatsUnknown").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                        }
                    }.accessibilityElement(children: .combine)
                }
                if !value.tickets.isEmpty { Text("topic.source.sessionNote.mp").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
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
                                    Text(verbatim: activity.name).cyText(.cardTitle)
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
            // PC-B-1-1: MP index.wxml:126,138 shows these rows only when `info.isOwner == 1` (graduate also needs Beta).
            let ownerGraduates = value.isOwner && value.betaFlag == 1 && popupCloseActions.graduateBetaTopic != nil
            let ownerTransfers = value.isOwner && popupCloseActions.loadTransferClubs != nil && popupCloseActions.transferTopicToClub != nil
            // R7-PC-B1-3 (r1 PC-B-1-1): MP asks for name / phone inside the checkout layer only, never as a standing row.
            if ownerGraduates || ownerTransfers {
                Section(PlayCloseCopy.text("主题运维与快捷资料", "Topic Actions & Profile", locale)) {
                    if ownerGraduates {
                        Button {
                            showingGraduateBetaConfirm = true
                        } label: {
                            Text(verbatim: PlayCloseCopy.text("转为正式主题", "Graduate from Beta", locale))
                        }
                        .accessibilityIdentifier("topic.graduateBeta.open")
                    }
                    if ownerTransfers {
                        Button {
                            loadClubsForTransfer()
                        } label: {
                            Text(verbatim: PlayCloseCopy.text("移交给俱乐部承接", "Transfer to club", locale))
                        }
                        .accessibilityIdentifier("topic.transferClub.open")
                    }
                }
            }
            let lineup = TopicXcxFacts.lineup(value)
            if !lineup.isEmpty { Section("topicXcx.section.lineup") { TopicXcxLineup(members: lineup, publicMerchant: publicMerchant) } }
            // 开局前准备 (`GET api/play/setup`): hidden when neither prep items nor a play window are set.
            // R7-PC-B1-20: MP shows 开局前准备 only to a viewer who has joined (`is_join == 1 && prep.show`).
            if value.isSignUp {
                // 开始游玩 hands over to the ticket wallet, where the joined pass starts play (server checks run there).
                PlayTopicPrepSection(topicID: id, onStart: ticketWalletDestination != nil ? { showingTickets = true } : nil)
            }
            G6TopicCharactersSection(chapters: value.chapters)
            Section("topic.availability") {
                // Source x-fix2 P-1 (hengyin c878fbb7d): a topic past its sale end only says 已截止, with no sign-up or unlock entry.
                if saleClosed(value) {
                    Label { Text("mpfresh.topic.closed", tableName: "MpFresh") } icon: { Image(systemName: "calendar.badge.exclamationmark") }
                        .accessibilityIdentifier("topic.saleClosed")
                } else {
                    Text(LocalizedStringKey("topic.availability." + String(value.availability.rawValue)))
                }
                // R7-PC-B1-14: 商家暂停营业 is said once, in the bar.
                if value.selfPlay == 1 {
                    TopicPrice(value: value.selfPlayPrice, label: "topic.selfPlayPrice")
                    if value.canOfferPurchase && !saleClosed(value) {
                        CYPillButton("contextSelfPlay.title", style: .secondary) { showingSelfPlay = true }
                            .accessibilityIdentifier("contextSelfPlay.open")
                    }
                }
            }
            // C13: the empty state is said once (TopicReviewsContent), with no 0 total and no small print under the
            // reviews (MP `det6`: 还没有评价 card, else rating + 基于 N 条评论 + list).
            Section("topic.comments") {
                CYPillButton("context.review.title", style: .secondary) { showsReview = true }.accessibilityIdentifier("topic.openReview")
                TopicReviewsContent(reviews: value.reviews)
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
                            // REV-B B-08: MP `metaTime` = formatTimeToChinese(totalTime) (X小时Y分钟) from seconds; else the
                            // games' minutes (C9), else hidden. Then 节点 and 玩法 counts.
                            if let seconds = chapter.totalTimeSeconds, seconds > 0 {
                                LabeledContent("topic.durationSeconds") { TopicXcxDurationText(seconds: seconds) }.cyText(.meta)
                            } else if let minutes = TopicChapterCards.minutes(chapter) {
                                LabeledContent("topic.durationMinutes") { Text(minutes, format: .number).monospacedDigit() }.cyText(.meta)
                            }
                            if !chapter.nodes.isEmpty {
                                LabeledContent("topic.visibleChapterStops", value: String(chapter.nodes.count)).cyText(.meta)
                            }
                            if let plays = chapter.templateCount, plays > 0 {
                                LabeledContent("discovery.templateDetail.stat.games", value: String(plays)).cyText(.meta)
                            }
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
                    Text(TopicXcxFacts.showsInStorePerks(value) ? "topicXcx.paywall.detail" : "topicXcx.paywall.detailNoPerks").cyText(.bodyCompact)
                    // PC-B-1-15: the price of what unlocks (MP paywall price row); unknown price → row hidden.
                    if value.selfPlay == 1, let price = value.selfPlayPrice {
                        Text(price, format: .currency(code: "CNY").precision(.fractionLength(0...2)))
                            .cyText(.numericBody).foregroundStyle(CYColor.textPrimary)
                            .accessibilityIdentifier("topic.paywall.price")
                    }
                    if value.selfPlay == 1 && value.canOfferPurchase && !saleClosed(value) {
                        CYPillButton("topicXcx.paywall.unlock", style: .primary) { showingSelfPlay = true }.accessibilityIdentifier("topic.paywall.unlock")
                    }
                    // PC-B-1-15: a buyer whose purchase has not synced yet has a way out (MP 已购？去票夹).
                    if ticketWalletDestination != nil {
                        Button { showingTickets = true } label: { Text("topicXcx.paywall.purchased").cyText(.meta) }
                            .buttonStyle(.plain).foregroundStyle(CYColor.brand)
                            .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            .accessibilityIdentifier("topic.paywall.tickets")
                    }
                }
            }
            TopicStoryParticipationLink(topicID: id, chapters: value.chapters)
            TopicXcxRouteSection(topic: value).id(TopicXcxTab.route.anchor)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        // One divider style on the page: a hairline in border-subtle, inset to the text (coordinator review).
        .listRowSeparatorTint(palette.borderSubtle)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        // An overlay, not a safe-area inset: an inset would shift the list and flip the pin back and forth.
        .overlay(alignment: .top) {
            if tabsPinned {
                TopicXcxTabs(proxy: proxy, productType: value.productType).selection($tab)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .background(palette.bgPage)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY + $0.safeAreaInsets.top } action: { pinLine = $0 }
        .onAppear { topicPageVisible = true }
        .onDisappear { topicPageVisible = false }
        .cyTracksHeroScroll($heroScrolledAway, threshold: 280)
        .modifier(G6TopicCharactersLoader(chapters: value.chapters))
        .refreshable { await loads.run { await load() } }
        .modifier(TopicBarRecede(active: showingSessionSelection || (barSheetOrigin != nil && (showingSelfPlay || showingTickets || showsPricing))))
        .safeAreaInset(edge: .bottom) {
            TopicXcxActionBar(topic: value, openSessions: { if !showingSessionSelection { showingSessionSelection = true } },
                              openSelfPlay: { barSheetOrigin = .selfPlay; showingSelfPlay = true },
                              openPricing: pricingDestination == nil ? nil : { barSheetOrigin = .pricing; showsPricing = true },
                              openEditor: editorDestination == nil ? nil : { showsEditor = true },
                              preferSession: preferSession,
                              openTickets: ticketWalletDestination == nil ? nil : { barSheetOrigin = .tickets; showingTickets = true },
                              heroNamespace: barHero)
        }
        .sheet(isPresented: $showingSessionSelection, onDismiss: { loads.start { await load() } }) {
            TopicSessionSelectionView(detail: value, scope: key.scope, activityDestination: activityDestination)
                .modifier(TopicBarHeroDestination(sheet: .sessions, origin: .sessions, namespace: barHero)) // only the bar opens it
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
        }
        .sheet(isPresented: $showsEditor) {
            if let editorDestination, case .editor(let scope) = TopicXcxFacts.ownerSaleRoute(value) {
                NavigationStack { editorDestination(value.id, scope) }
                    .cyPlayerSheetGlass()
                    .cyDomainSheet(detents: [.full])
            }
        }
        .sheet(isPresented: $showsPricing, onDismiss: { barSheetOrigin = nil }) {
            if let pricingDestination {
                NavigationStack { pricingDestination(value.id) }
                    .modifier(TopicBarHeroDestination(sheet: .pricing, origin: barSheetOrigin, namespace: barHero))
                    .cyPlayerSheetGlass()
                    .cyDomainSheet(detents: [.half, .full])
            }
        }
        .accessibilityIdentifier("topic.detail.content")
        }
    }
    private var detail: TopicDetail? { phase.value }
    /// Source `topicSaleClosed`: the sale end (endDate) has passed. Mainland wall-clock source, as in the mini-program.
    /// A purchased topic keeps its 去票夹 path; an unparsable end never closes the topic.
    private func saleClosed(_ value: TopicDetail) -> Bool {
        // PC-B-1-3: one rule with the bottom bar (MP `topicSaleClosed`: `saleEndAt`, else `endDate`).
        !value.isSignUp && TopicXcxFacts.saleClosed(value)
    }
    /// Guard: only an in-flight load falls back to idle; loaded/failed results are kept.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    private func load() async {
        generation += 1
        let operation = generation, captured = key
        // combined-r4 verify: a refresh of the topic already on screen (session sheet dismissed, review sent) keeps the
        // page until the new read lands. Blanking it to the skeleton removed the bar mid zoom-back, so the sheet shrank
        // into the middle of an empty page and the scroll position was lost.
        let refreshing = loadedKey == captured && detail != nil
        if !refreshing { phase = .idle; loadedKey = nil }
        guard reader.isConfigured else { return }
        if !refreshing { phase = .loading }
        defer { if operation == generation { settleLoading() } }
        do {
            let result = try await reader.topicDetail(id: id)
            try Task.checkCancellation()
            guard operation == generation, captured == key, !Task.isCancelled else { return }
            phase = .loaded(result); loadedKey = captured
        } catch is CancellationError { }
        catch {
            guard operation == generation, captured == key, !Task.isCancelled else { return }
            // A failed refresh keeps the topic the user is reading; only a first read shows the issue state.
            guard !refreshing else { return }
            phase = .failed(TopicScreenIssue(error), retry: nil); loadedKey = captured
        }
    }

    private func graduateCurrentBetaTopic() {
        guard let graduate = popupCloseActions.graduateBetaTopic else {
            showingGraduateBetaConfirm = false
            return
        }
        popupBusy = true
        Task {
            defer { popupBusy = false; showingGraduateBetaConfirm = false }
            switch await graduate(id) {
            case .success(let message):
                resultSheetTitle = PlayCloseCopy.text("已转为正式主题", "Graduated to Official Topic", locale)
                resultSheetMessage = message.isEmpty
                    ? PlayCloseCopy.text("主题已去除 Beta 标记，可继续正常售票与运营。", "The Beta tag has been removed.", locale)
                    : message
                loads.start { await load() }
            case .failure:
                topicToastMessage = PlayCloseCopy.text("转正操作未成功", "Could not graduate topic", locale)
            }
        }
    }

    private func loadClubsForTransfer() {
        guard let loadClubs = popupCloseActions.loadTransferClubs else { return }
        popupBusy = true
        Task {
            defer { popupBusy = false }
            let clubs = await loadClubs()
            if clubs.isEmpty {
                topicToastMessage = PlayCloseCopy.text("暂无可移交的俱乐部", "No eligible clubs found", locale)
            } else {
                transferClubs = clubs
                showingClubTransferPicker = true
            }
        }
    }

    private func performTopicClubTransfer(_ club: ClubRecord) {
        guard let transfer = popupCloseActions.transferTopicToClub else {
            showingTransferConfirm = false
            return
        }
        popupBusy = true
        Task {
            defer { popupBusy = false; showingTransferConfirm = false }
            switch await transfer(id, club.id) {
            case .success(let newTopicID):
                transferredTopicID = newTopicID
                showingTransferredResult = true
                loads.start { await load() }
            case .failure:
                topicToastMessage = PlayCloseCopy.text("移交俱乐部未成功", "Transfer failed", locale)
            }
        }
    }

    private func saveContactBeforeSelfPlay() {
        guard let save = popupCloseActions.saveUserPhoneAndName else {
            showingContactSheet = false
            return
        }
        popupBusy = true
        Task {
            defer { popupBusy = false }
            switch await save(contactRealName, contactPhone) {
            case .success:
                showingContactSheet = false
                topicToastMessage = PlayCloseCopy.text("资料已保存，请继续建单", "Contact saved. Continue placing your order", locale)
                showingSelfPlay = true
            case .failure:
                topicToastMessage = PlayCloseCopy.text("保存失败，请检查姓名与手机号", "Save failed. Check name and phone", locale)
            }
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
                        Text(verbatim: chapter.title).cyText(.sheetTitle)
                        if let description = chapter.description { Text(verbatim: description).textSelection(.enabled) }
                        if itinerary.hasWalkingEstimates {
                            Text("topic.itinerary.estimateNotice").cyText(.bodyCompact).foregroundStyle(.secondary)
                                .accessibilityIdentifier("topic.itinerary.notice")
                        }
                    }
                    ForEach(itinerary.stops) { stop in
                        let node = stop.node
                        Section {
                            if let minutes = stop.estimatedWalkingMinutes {
                                TopicWalkingEstimate(minutes: minutes, position: stop.id)
                            }
                            LabeledContent("topic.itinerary.stopNumber", value: String(stop.id + 1)).cyText(.meta)
                            Text(verbatim: node.name).cyText(.cardTitle)
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
                                if let hours = merchant.businessTime { Text(verbatim: hours).cyText(.meta) }
                            }
                        }
                    }
                }
            }
        }.appNavigationTitle("topic.chapter").navigationBarTitleDisplayMode(.inline).cyHideTabBar()
        .cyDomainScreen(.player)
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
                Text("mpfresh.topic.failed.title", tableName: "MpFresh").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                TopicIssueView(issue: issue, retry: retry)
            }
            .padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .notConfigured, .unauthorized:
            TopicIssueView(issue: issue, retry: retry)
        }
    }
}
