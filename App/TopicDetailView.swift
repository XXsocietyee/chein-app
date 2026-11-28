import SwiftUI

@MainActor
struct TopicDetailView: View {
    let id: Int
    let reader: any TopicReading
    var preferSession = false
    var activityDestination: ((Int) -> AnyView)? = nil
    var publicMerchant: PublicMerchantHomeContext? = nil
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var publisherDestination: ((TopicDetail) -> AnyView)? = nil
    var reviewOwner: ContextualReviewCoordinator? = nil
    /// Guest 收藏 / buy / review. Nil for a signed-in reader.
    var guestSignIn: (() -> Void)? = nil
    @State private var showsReview = false
    var selfPlayDestination: ((TopicDetail) -> AnyView)? = nil
    var ticketWalletDestination: ((Int) -> AnyView)? = nil
    /// mp-nav r3 (MP im/chat index.js:1084-1088, P-36): opened from a signup card, a topic that is no longer
    /// readable still offers the ticket wallet, because the ticket itself stays valid.
    var unavailableWallet: AnyView? = nil
    /// R7-PC-B1-5: MP `startPrepPlay` → `/pages/play/index?topicId=` after the safety check (pages/topic/index/index.js:714-722).
    var playDestination: ((Int) -> AnyView)? = nil
    @State private var showingPlay = false
    @State private var showingSelfPlay = false
    @State private var showingTickets = false
    @State private var showingSessionSelection = false
    /// R7-PC-B1-13: MP `sessionPreferName` (pages/topic/index/index.js:1319-1321): the tapped session row's ticket name.
    @State private var sessionPreferName: String?
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
    /// R7-PC-B1-1 (MP-first): 收藏 host; nil hides the bookmark.
    @Environment(\.topicFavoriteHostFactory) private var favoriteHostFactory
    @State private var favoriteHost: TopicFavoriteHost?
    @State private var favorited: Bool?
    @State private var favoriteBusy = false
    /// mp-home r3 (continue 43): counts of sent / rolled-back 收藏 toggles; each change plays one haptic.
    @State private var favoriteSentCount = 0
    @State private var favoriteFailedCount = 0
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
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
    /// R7-PC-B1-5: the prep 开始游玩 opens the play runtime (MP); the ticket wallet stays the fallback when no runtime is mounted.
    private var prepStartAction: (() -> Void)? {
        if playDestination != nil { return { showingPlay = true } }
        if ticketWalletDestination != nil { return { showingTickets = true } }
        return nil
    }
    var body: some View {
        Group {
            if !reader.isConfigured { TopicIssueView(issue: .notConfigured) }
            else if phase.isLoading || loadedKey != key { ProgressView("topic.loading").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else {
                switch phase {
                case .failed(let issue, _): TopicDetailIssueState(issue: issue, wallet: unavailableWallet) { loads.start { await load() } }
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
                    TopicXcxToolbarActions(shareURL: PublicContentShareLink.topic(id: value.id), shareTitle: value.name,
                                           isFavorited: favorited,
                                           onToggleFavorite: guestSignIn != nil ? { guestSignIn?() } : (favoriteHost == nil ? nil : { toggleFavorite(topicID: value.id) }),
                                           posterCover: value.imageURL, posterSubtitle: value.subtitle)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    UGCSafetyMenuButton(
                        presentation: UGCReportPresentationTarget(
                            target: .topic(id: value.id),
                            subjectTitle: value.name,
                            authorMemberID: value.ownerMemberID,
                            authorName: value.clubName
                        ),
                        moreGlyph: true
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
        .task(id: key) { await seedFavorite() }
        .onDisappear { loads.cancel(); generation += 1; settleLoading() }
        .cySheet(isPresented: $showsReview) {
            NavigationStack { ContextualReviewComposer(target: .topic(id), owner: reviewOwner) { loads.start { await load() } } }
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
        }
        .onChange(of: key) { _, _ in showingSelfPlay = false; showingSessionSelection = false; showingTickets = false; showingPlay = false; showsEditor = false }
        .navigationDestination(isPresented: $showingPlay) {
            if let playDestination { playDestination(id) }
        }
        // mp-nav r3: MP 我的票 is navigateTo subpackageMember/signup/index (a page): push, standard back.
        .navigationDestination(isPresented: $showingTickets) {
            if let ticketWalletDestination {
                ticketWalletDestination(id)
                    .cyPushedChrome()
            }
        }
        .onChange(of: showingTickets) { _, shown in if !shown { barSheetOrigin = nil } }
        .cySheet(isPresented: $showingSelfPlay, onDismiss: { barSheetOrigin = nil }) {
            Group {
                if let detail {
                    // R8-PC-B1-1: a paid order with the payment switch off shows the unavailable state before the name/phone form.
                    if let selfPlayDestination, PlayerContentMPContract.selfPlayCreateOpen(price: detail.selfPlayPrice) { selfPlayDestination(detail) }
                    else { TopicSelfPlayUnavailableSheet(topic: detail) }
                }
            }
            .modifier(TopicBarHeroDestination(sheet: .selfPlay, origin: barSheetOrigin, namespace: barHero))
            .cyPlayerSheetGlass()
            .cyDomainSheet(detents: [.half, .full])
        }
        .cySheet(isPresented: $showingClubTransferPicker) {
            NavigationStack {
                List(transferClubs) { club in
                    Button {
                        showingClubTransferPicker = false
                        selectedTransferClub = club
                        showingTransferConfirm = true
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(verbatim: club.name).foregroundStyle(.primary)
                                    if let city = club.city, !city.isEmpty {
                                        Text(verbatim: city).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "person.3")
                            }
                            Spacer()
                            if selectedTransferClub?.id == club.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .navigationTitle(Text(verbatim: PlayCloseCopy.text("选择承接俱乐部", "Choose host club", locale)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { showingClubTransferPicker = false } label: { Text(verbatim: PlayCloseCopy.close(locale)) }
                            .accessibilityIdentifier("topic.transfer.clubSheet.close")
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .cySheet(isPresented: $showingContactSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField(PlayCloseCopy.text("真实姓名", "Real name", locale), text: $contactRealName,
                                  prompt: Text(verbatim: PlayCloseCopy.text("请输入姓名", "Enter name", locale)))
                            .textContentType(.name)
                            .submitLabel(.next)
                        TextField(PlayCloseCopy.text("手机号", "Phone number", locale), text: $contactPhone,
                                  prompt: Text(verbatim: PlayCloseCopy.text("请输入手机号", "Enter phone", locale)))
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }
                .navigationTitle(Text(verbatim: PlayCloseCopy.text("补全姓名和手机号", "Complete Name & Phone", locale)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { showingContactSheet = false } label: { Text(verbatim: PlayCloseCopy.cancel(locale)) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if popupBusy {
                            ProgressView()
                        } else {
                            Button {
                                saveContactBeforeSelfPlay()
                            } label: {
                                Text(verbatim: PlayCloseCopy.text("保存并继续", "Save and continue", locale))
                            }
                            .disabled(contactRealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert(
            Text(verbatim: resultSheetTitle ?? ""),
            isPresented: Binding(get: { resultSheetTitle != nil }, set: { if !$0 { resultSheetTitle = nil; resultSheetMessage = nil } })
        ) {
            Button(role: .cancel) { resultSheetTitle = nil; resultSheetMessage = nil } label: { Text(verbatim: PlayCloseCopy.close(locale)) }
        } message: {
            Text(verbatim: resultSheetMessage ?? "")
        }
        .alert(Text(verbatim: PlayCloseCopy.text("转为正式主题", "Graduate to Official Topic", locale)), isPresented: $showingGraduateBetaConfirm) {
            Button(role: .cancel) { showingGraduateBetaConfirm = false } label: { Text(verbatim: PlayCloseCopy.cancel(locale)) }
            Button { graduateCurrentBetaTopic() } label: { Text(verbatim: PlayCloseCopy.text("确认转正", "Confirm", locale)) }
                .disabled(popupBusy)
                .accessibilityIdentifier("topic.graduateBeta.confirm")
        } message: {
            Text(verbatim: PlayCloseCopy.text("转正后不再显示 Beta 标记。主题内容、已售出的票和进行中的行程都不受影响。", "The Beta tag will be removed. Topic content, sold tickets, and active runs stay unaffected.", locale))
        }
        .alert(Text(verbatim: PlayCloseCopy.text("移交给俱乐部承接", "Transfer to Club", locale)), isPresented: $showingTransferConfirm, presenting: selectedTransferClub) { club in
            Button(role: .cancel) { showingTransferConfirm = false } label: { Text(verbatim: PlayCloseCopy.cancel(locale)) }
            Button { performTopicClubTransfer(club) } label: { Text(verbatim: PlayCloseCopy.text("确认移交", "Confirm transfer", locale)) }
                .disabled(popupBusy)
                .accessibilityIdentifier("topic.transferClub.confirm")
        } message: { club in
            Text(verbatim: PlayCloseCopy.text("将复制一份新的城市定向主题(有人带),挂到「\(club.name)」名下。原草稿与历史记录会保留。", "Creates an instructor-led City Orienteering copy under \"\(club.name)\".", locale))
        }
        .alert(Text(verbatim: PlayCloseCopy.text("已移交", "Transferred", locale)), isPresented: $showingTransferredResult) {
            Button(role: .cancel) { showingTransferredResult = false } label: { Text(verbatim: PlayCloseCopy.text("留在本页", "Stay here", locale)) }
            Button {
                showingTransferredResult = false
                if pricingDestination != nil {
                    showsPricing = true
                } else if let transferredTopicID {
                    topicToastMessage = PlayCloseCopy.text("已生成新草稿 #\(transferredTopicID)", "Created draft #\(transferredTopicID)", locale)
                }
            } label: { Text(verbatim: PlayCloseCopy.text("去配置票种", "Configure tickets", locale)) }
                .accessibilityIdentifier("topic.transferred.configure")
        } message: {
            Text(verbatim: PlayCloseCopy.text("已生成新的城市定向草稿，去配置票种并邀请该俱乐部承接?", "Created a new City Orienteering draft. Configure tickets and invite the club to host?", locale))
        }
        .alert(Text(verbatim: PlayCloseCopy.text("还差姓名和手机号", "Name and phone needed", locale)), isPresented: $showingContactPromptModal) {
            Button(role: .cancel) { showingContactPromptModal = false } label: { Text(verbatim: PlayCloseCopy.cancel(locale)) }
            Button {
                showingContactPromptModal = false
                showingContactSheet = true
            } label: { Text(verbatim: PlayCloseCopy.text("去填写", "Fill in", locale)) }
                .accessibilityIdentifier("topic.contactPrompt.fill")
        } message: {
            Text(verbatim: PlayCloseCopy.text("建单要用你的真实姓名和手机号，补一次就好，之后不用再填。", "Your real name and phone are needed to place this order. Save them once for future orders.", locale))
        }
        .cyToast(verbatimMessage: $topicToastMessage)
        .modifier(TopicFavoriteHaptics(sent: favoriteSentCount, failed: favoriteFailedCount))
    }
    private func content(_ value: TopicDetail) -> some View {
        ScrollViewReader { proxy in
        List {
            // PC-B-1-1: MP index.wxml:126,138 shows the owner rows only when `info.isOwner == 1` (graduate also needs Beta).
            let ownerGraduates = value.isOwner && value.betaFlag == 1 && popupCloseActions.graduateBetaTopic != nil
            let ownerTransfers = value.isOwner && popupCloseActions.loadTransferClubs != nil && popupCloseActions.transferTopicToClub != nil
            // R7-PC-B1-3 (r1 PC-B-1-1): MP asks for name / phone inside the checkout layer only, never as a standing row.
            // Mini-program `det1` hero: cover, type and title, then the stat bar and the 详情 / 故事 / 路线 tabs.
            Section {
                let covers = value.images.isEmpty ? (value.imageURL.map { [$0] } ?? []) : Array(value.images.prefix(9))
                if covers.isEmpty {
                    // Mini-program `cover-brief` (no cover): type, title and one-line hint on an opaque card.
                    // native r2: a plain first-section header (route mark, type, title), no card chrome.
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        // verify-r1 PL-14: the type is a fact, not a link or a status, so it is ink, not blue.
                        // Round 4 image parity: the route mark is the MP `/images/cover-route.svg` (topic/index.wxml:49/78).
                        MPAsset.BannerCover.coverRoute.resizable().scaledToFit()
                            .accessibilityHidden(true)
                            .frame(width: 40, height: 40)
                        Text(value.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text(verbatim: value.name).font(.title2.bold()).foregroundStyle(.primary)
                        if let subtitle = TopicXcxFacts.heroIntro(value.subtitle) { Text(verbatim: subtitle).font(.body).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? 3 : 1) }
                        else { Text("topicXcx.coverHint").font(.body).foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, CYSpacing.sm)
                    .accessibilityElement(children: .combine)
                } else {
                    // verify-r1 3.1 / PL-23 (`169:6954`): the photo is the hero and carries no text, so a cover that
                    // fails to load can never sit under the title. The title and its facts follow below.
                    Group {
                        if RetainedPublicImageReader().enabled {
                            NativeMediaGalleryEntry(sources: covers, scope: key.scope, titleKey: "media.destination.squareImages", compact: true)
                        } else {
                            // Coordinator review: photos cannot load here (no image storage), so the hero is never a
                            // 图片暂不可用 line. R10-PC-B-N2: one plain `Image` header (the MP `/images/cover-route.svg` mark,
                            // topic/index.wxml:49/78), no designed cover or custom clip.
                            MPAsset.BannerCover.coverRoute.resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 120)
                                .padding(.vertical, CYSpacing.md)
                                .accessibilityHidden(true)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(value.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: value.name)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("topic.detail.title")
                    }
                    .accessibilityElement(children: .combine)
                }
                TopicXcxHero(topic: value)
                // P0-14 生成式 AI 内容显式标识 (`utils/aigc-label.js`): only for `publishMode == ai_simple`.
                if AIGCDisclosure.isAIGenerated(publishMode: value.publishMode) { AIGCLabel() }
                // mp-home r3: MP `topic-transfer-entry` (index.wxml:126) sits right under the hero, before the Beta block.
                if ownerTransfers {
                    Button {
                        loadClubsForTransfer()
                    } label: {
                        Text(verbatim: PlayCloseCopy.text("移交给俱乐部承接", "Transfer to club", locale))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("topic.transferClub.open")
                }
                if value.betaFlag == 1 {
                    // Source topic-beta block: badge plus feedback note; the owner's 转为正式主题 inside it (index.wxml:138).
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("topic.source.betaBadge").font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                            Text("topic.source.betaNote").font(.caption).foregroundStyle(.secondary)
                        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                        if ownerGraduates {
                            Button {
                                showingGraduateBetaConfirm = true
                            } label: {
                                Text(verbatim: PlayCloseCopy.text("转为正式主题", "Graduate from Beta", locale))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityIdentifier("topic.graduateBeta.open")
                        }
                    }
                }
                // Design hand-off r1 PL-23: one hero, then the title and stats. The cover's 查看详情与报名 scroll button is
                // gone: the pinned 详情 / 故事 / 路线 tabs and the sticky bar (price left, primary right) carry those paths.
                TopicXcxStatBar(cells: TopicXcxFacts.statBar(value), stops: value.locationCount)
                // One container for 详情 / 故事 / 路线: inline here, and pinned under the bar once it scrolls away.
                let line = pinLine
                TopicXcxTabs(proxy: proxy, productType: value.productType).selection($tab)
                    .opacity(tabsPinned ? 0 : 1)
                    .onGeometryChange(for: Bool.self) { $0.frame(in: .global).minY < line } action: { pinned in
                        if tabsPinned != pinned { tabsPinned = pinned }
                    }
                    // A tab tap scrolls with `scrollTo`, which jumps: the row leaves the list without ever reporting a
                    // position above the pin line (integ-r3). It sits near the top of the list, so a row that leaves
                    // while the page is still on screen has left over the top: pin. Checked a run loop later, so a
                    // page pushed over the topic (which also ends the row's appearance) does not count.
                    .onDisappear {
                        Task { @MainActor in if topicPageVisible { tabsPinned = true } }
                    }
            }
            // verify-r1 3.1 (`169:6954`): the hero block reads as one page header, not as list rows with dividers.
            .listRowSeparator(.hidden)
            // 详情 tab (mini-program `det3`): title and one-line subtitle (MP owner 10-29 V-22b: no venue card), then the audio guide.
            Section {
                // Coordinator review: an unknown or zero stop count is not a fact worth a row.
                if (value.locationCount ?? 0) > 0 {
                    TopicTotalStops(count: value.locationCount, identifier: "topic.totalStops")
                }
                if let subtitle = value.subtitle { Text(verbatim: subtitle).font(.headline) }
                if let audio = value.audioURL, !audio.isEmpty { PlatformAudioHost(rawURL: audio, scope: reader.scope, makeModel: makeAudio) }
                // R7-PC-B1-6: free explore lists 参与商家 · N 家 in 详情 (MP pages/topic/index/index.wxml:190-192, merchantCards).
                if value.productType == 2 {
                    let shops = TopicFreeExploreMerchantCard.cards(fromChapters: value.chapters).count
                    if shops > 0 {
                        LabeledContent {
                            Text("topicXcx.merchantsCount \(shops)").monospacedDigit()
                        } label: { Text("topicRoute.merchants.title") }
                            .accessibilityIdentifier("topic.detail.merchants")
                    }
                }
            }.id(TopicXcxTab.details.anchor)
            // mp-home r3 (MP topic/index.wxml:190-196): 参与商家, then 开局前准备, then 节点介绍.
            // 开局前准备 (`GET api/play/setup`): hidden when neither prep items nor a play window are set.
            // R7-PC-B1-20: MP shows 开局前准备 only to a viewer who has joined (`is_join == 1 && prep.show`).
            if value.isSignUp {
                // 开始游玩 hands over to the ticket wallet, where the joined pass starts play (server checks run there).
                PlayTopicPrepSection(topicID: id, onStart: prepStartAction)
            }
            // 节点介绍 (MP `det4`, owner 2026-11-19): one card per chapter, endings excluded (port plan r1 C9).
            TopicChapterCardsSection(cards: TopicChapterCards.cards(chapters: value.chapters, routeCover: value.imageURL))
            // 活动内容 (MP `det3`, 2026-11-21): the story only. Practical lines from the same text, prices, what is
            // included, pause/resume and finishing rewards move to 出发前 below (port plan r1 C13).
            let story = TopicDepartNotes.split(value.introduction).story
            if !story.isEmpty {
                Section {
                    Text(verbatim: story).font(.body).textSelection(.enabled)
                        .accessibilityIdentifier("topic.story")
                } header: {
                    Text("topicXcx.section.contents")
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
                // mp-home r3 (MP topic/index.wxml:245 `sess__capacity`, `formatPerkCapacity`): 本期可售 N 张 above the sessions.
                if let capacity = Self.perkCapacity(value.perkSellableCapacity) {
                    Text("topic.source.perkCapacity \(capacity)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityIdentifier("topic.session.capacity")
                }
                if value.tickets.isEmpty { Text("topic.noTickets") }
                ForEach(Array(value.tickets.enumerated()), id: \.offset) { _, ticket in
                    // R7-PC-B1-13 (MP index.wxml:227 `bindtap="bmClick"`): a session row opens the in-page session picker.
                    Button {
                        guard !showingSessionSelection else { return }
                        sessionPreferName = ticket.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        showingSessionSelection = true
                    } label: {
                    // Mini-program `sess`: name / time / meeting point / refund on the left, price and seats left on the right.
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        // Grouped session card: one element. The visible rows stay in source order.
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: ticket.name).font(.headline).foregroundStyle(.primary)
                            if let session = TopicXcxFacts.sessionTime(start: ticket.startTime, end: ticket.endTime) { Text(verbatim: session).font(.subheadline).foregroundStyle(.secondary) }
                            else {
                                if let start = ticket.startTime { LabeledContent("topic.start", value: start) }
                                if let end = ticket.endTime { LabeledContent("topic.end", value: end) }
                            }
                            if let meeting = ticket.meetingPoint { Text("topic.source.meetingPoint \(meeting)").font(.footnote).foregroundStyle(.secondary) }
                            if let refund = ticket.refundRule { Text("topic.source.refundRule \(refund)").font(.footnote).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: CYSpacing.sm)
                        VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                            TopicPrice(value: ticket.price, label: "topic.price").font(.body).monospacedDigit()
                            if let remaining = ticket.remaining { Text("topic.source.seatsLeft \(remaining)").font(.footnote).monospacedDigit().foregroundStyle(.secondary) }
                            else { Text("topic.source.seatsUnknown").font(.footnote).foregroundStyle(.secondary) }
                        }
                    }.accessibilityElement(children: .combine)
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("topic.session.row")
                }
                if !value.tickets.isEmpty { Text("topic.source.sessionNote.mp").font(.footnote).foregroundStyle(.secondary) }
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
            let lineup = TopicXcxFacts.lineup(value)
            if !lineup.isEmpty { Section("topicXcx.section.lineup") { TopicXcxLineup(members: lineup, publicMerchant: publicMerchant) } }
            // RTEAMS-1: 组队 card under the brands (hidden unless this topic has teams near its first stop).
            TopicTeamsCard(topic: value)
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
                        Button { asSignedIn { showingSelfPlay = true } } label: { Text("contextSelfPlay.title") }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("contextSelfPlay.open")
                    }
                }
            }
            // C13: the empty state is said once (TopicReviewsContent), with no 0 total and no small print under the
            // reviews (MP `det6`: 还没有评价 card, else rating + 基于 N 条评论 + list).
            Section("topic.comments") {
                // mp-home r3 (MP topic/index.wxml:302-316): with no reviews the 还没有评价 card is the only write entry.
                if !(value.reviews.hasConfirmedNoReviews && value.reviews.preview.isEmpty) {
                    Button("context.review.title") { asSignedIn { showsReview = true } }
                        .buttonStyle(.bordered).accessibilityIdentifier("topic.openReview")
                }
                // R8-PC-B1-2 (MP `det6`): the 还没有评价 card itself is the write entry; the content view stays read-only.
                // R9-PC-BN-4: a real Button (system traits and highlight) instead of onTapGesture + a manual trait.
                if value.reviews.hasConfirmedNoReviews && value.reviews.preview.isEmpty {
                    Button { asSignedIn { showsReview = true } } label: { TopicReviewsContent(reviews: value.reviews) }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("context.review.title"))
                } else {
                    TopicReviewsContent(reviews: value.reviews)
                }
            }
            .environment(\.ugcSafetySubjectID, value.id)
            // mp-home r3 — 故事 (MP topic/index.wxml:343-372): 人物 row first, then 章节 / 护照, then 主要角色.
            if let cast = value.castConfig, !cast.cast.isEmpty {
                Section("topic.cast") { TopicCastRow(config: cast) }
            }
            Section {
                if value.chapters.isEmpty {
                    Text("topic.noChapters").foregroundStyle(.secondary)
                }
                // Index identity preserves source order even when backend IDs are absent/duplicated.
                ForEach(Array(value.chapters.enumerated()), id: \.offset) { _, chapter in
                    if chapter.locked {
                        // A locked chapter does not open. When self-play purchase is offered, the row is the paywall.
                        Button {
                            if value.selfPlay == 1 && value.canOfferPurchase && !saleClosed(value) { asSignedIn { showingSelfPlay = true } }
                        } label: {
                            chapterSummary(chapter, locked: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("topic.chapter.\(chapter.id).locked")
                    } else {
                        NavigationLink {
                            TopicChapterView(chapter: chapter, reader: reader, scope: key.scope, publicMerchant: publicMerchant, makeExternalMaps: makeExternalMaps)
                        } label: {
                            chapterSummary(chapter, locked: false)
                        }.accessibilityIdentifier("topic.chapter.\(chapter.id)")
                    }
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
                        Text(verbatim: LocaleDisplay.money(price, locale: locale))  // owner decision 9: ¥12.50
                            .cyText(.numericTitle)
                            .accessibilityIdentifier("topic.paywall.price")
                    }
                    if value.selfPlay == 1 && value.canOfferPurchase && !saleClosed(value) {
                        Button { asSignedIn { showingSelfPlay = true } } label: { Text("topicXcx.paywall.unlock").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .accessibilityIdentifier("topic.paywall.unlock")
                    }
                    // PC-B-1-15: a buyer whose purchase has not synced yet has a way out (MP 已购？去票夹).
                    if ticketWalletDestination != nil {
                        Button { showingTickets = true } label: { Text("topicXcx.paywall.purchased") }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("topic.paywall.tickets")
                    }
                }
            }
            TopicStoryParticipationLink(topicID: id, chapters: value.chapters)
            G6TopicCharactersSection(chapters: value.chapters)
            TopicXcxRouteSection(topic: value).id(TopicXcxTab.route.anchor)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        // An overlay, not a safe-area inset: an inset would shift the list and flip the pin back and forth.
        .overlay(alignment: .top) {
            if tabsPinned {
                TopicXcxTabs(proxy: proxy, productType: value.productType).selection($tab)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .background(.bar)
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
                              openSelfPlay: { asSignedIn { barSheetOrigin = .selfPlay; showingSelfPlay = true } },
                              openPricing: pricingDestination == nil ? nil : { barSheetOrigin = .pricing; showsPricing = true },
                              openEditor: editorDestination == nil ? nil : { showsEditor = true },
                              preferSession: preferSession,
                              openTickets: ticketWalletDestination == nil ? nil : { barSheetOrigin = .tickets; showingTickets = true },
                              heroNamespace: barHero)
        }
        .cySheet(isPresented: $showingSessionSelection, onDismiss: { sessionPreferName = nil; loads.start { await load() } }) {
            TopicSessionSelectionView(detail: value, scope: key.scope, activityDestination: activityDestination,
                                      preferredTicketName: sessionPreferName)
                .modifier(TopicBarHeroDestination(sheet: .sessions, origin: .sessions, namespace: barHero)) // only the bar opens it
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
        }
        // mp-nav-b r3: MP 编辑 is navigateTo pages/publish/fabu/index (a page): push with system back, the same
        // editor the template detail 用这个模板 already pushes; the editor autosaves, so popping keeps the draft.
        .navigationDestination(isPresented: $showsEditor) {
            if let editorDestination, case .editor(let scope) = TopicXcxFacts.ownerSaleRoute(value) {
                editorDestination(value.id, scope)
                    .cyPushedChrome()
            }
        }
        // mp-nav r3: MP 定价 is navigateTo pages/topic/pricing/index (a page): push; its confirm pops back (MP index.js:451).
        .navigationDestination(isPresented: $showsPricing) {
            if let pricingDestination {
                pricingDestination(value.id)
                    .environment(\.topicPricingScope, { () -> String? in if case .pricing(let scope) = TopicXcxFacts.ownerSaleRoute(value) { return scope }; return nil }())
                    .cyPushedChrome()
            }
        }
        .onChange(of: showsPricing) { _, shown in if !shown { barSheetOrigin = nil } }
        .accessibilityIdentifier("topic.detail.content")
        }
    }
    private var detail: TopicDetail? { phase.value }
    /// REV-B B-08: MP `metaTime` from seconds, else the games' minutes, else hidden. Then 节点 and 玩法 counts.
    @ViewBuilder private func chapterSummary(_ chapter: TopicChapter, locked: Bool) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            VStack(alignment: .leading) {
                Text(verbatim: chapter.title)
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
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel(Text("topic.lockedNotice"))
            }
        }
    }
    /// Source `topicSaleClosed`: the sale end (endDate) has passed. Mainland wall-clock source, as in the mini-program.
    /// A purchased topic keeps its 去票夹 path; an unparsable end never closes the topic.
    /// MP `formatPerkCapacity`: no value or the unlimited sentinel (Int32.max and above) → no line; negatives read 0.
    static func perkCapacity(_ value: Int?) -> Int? {
        guard let value, value < 2_147_483_647 else { return nil }
        return max(0, value)
    }

    private func saleClosed(_ value: TopicDetail) -> Bool {
        // PC-B-1-3: one rule with the bottom bar (MP `topicSaleClosed`: `saleEndAt`, else `endDate`).
        !value.isSignUp && TopicXcxFacts.saleClosed(value)
    }
    /// Guard: only an in-flight load falls back to idle; loaded/failed results are kept.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    /// MP `_loadFav`: one like_list read on entry; a tap made before it returns wins (the ledger drops the stale read).
    private func asSignedIn(_ action: () -> Void) {
        if let prompt = guestSignIn { prompt(); return }
        action()
    }
    private func seedFavorite() async {
        guard guestSignIn == nil else { favoriteHost = nil; favorited = nil; return }
        guard let host = favoriteHostFactory?() else { favoriteHost = nil; favorited = nil; return }
        favoriteHost = host; favorited = nil
        let topicID = id
        _ = try? await host.controller.performReadback(topicID: topicID, using: host.readLiked)
        guard topicID == id, !favoriteBusy else { return }
        if let liked = host.controller.confirmedLiked(topicID: topicID) { favorited = liked }
    }
    /// MP `toggleFav`: optimistic flip, `api/topic/like {id, type}`, roll back with a toast on failure.
    private func toggleFavorite(topicID: Int) {
        guard let host = favoriteHost, !favoriteBusy else { return }
        let next = !(favorited ?? false)
        favoriteBusy = true; favorited = next
        Task { @MainActor in
            let state = try? await host.controller.setLikeDirection(topicID: topicID, direction: TopicLikeDirection(liked: next))
            favoriteBusy = false
            switch state {
            case .awaitingReadback?, .confirmed?, .sending?:
                favoriteSentCount += 1
                topicToastMessage = next ? PlayCloseCopy.text("已收藏", "Saved", locale) : PlayCloseCopy.text("已取消收藏", "Removed from saved", locale)
            case .rejected(_, let message)?:
                favorited = !next
                favoriteFailedCount += 1
                topicToastMessage = message ?? PlayCloseCopy.text("收藏没有保存，请重试", "Not saved. Try again", locale)
            default:
                favorited = !next
                favoriteFailedCount += 1
                topicToastMessage = PlayCloseCopy.text("网络异常，收藏没有保存", "Network error. Not saved", locale)
                // An uncertain write is resolved by reading back, never by resending.
                _ = try? await host.controller.performReadback(topicID: topicID, using: host.readLiked)
                if let liked = host.controller.confirmedLiked(topicID: topicID) { favorited = liked }
            }
        }
    }
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
                asSignedIn { showingSelfPlay = true }
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
    var wallet: AnyView? = nil
    var retry: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        switch issue {
        case .unavailable:
            // R10-PC-B-N2: the refused state is a plain ContentUnavailableView; 返回 is its `.bordered` action.
            ContentUnavailableView {
                Label { Text("mpfresh.topic.refused.title", tableName: "MpFresh") } icon: { Image(systemName: "eye.slash") }
            } description: {
                if wallet != nil { Text("mpfresh.topic.refused.ticketValid", tableName: "MpFresh") }
            } actions: {
                if let wallet {
                    NavigationLink { wallet } label: { Text("topicXcx.bar.toTickets") }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("topic.error.tickets")
                }
                Button { dismiss() } label: { Text("mpfresh.topic.back", tableName: "MpFresh") }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("topic.error.back")
            }
                .accessibilityIdentifier("topic.error")
        case .failed:
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text("mpfresh.topic.failed.title", tableName: "MpFresh").font(.title3.weight(.semibold))
                TopicIssueView(issue: issue, retry: retry)
            }
            .padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .notConfigured, .unauthorized:
            TopicIssueView(issue: issue, retry: retry)
        }
    }
}

/// 收藏 toggle feedback, split out of the topic body so it type-checks in time (coordinator 03:50 rule):
/// success when the write was sent, warning when it rolled back. The seed read-back plays nothing.
private struct TopicFavoriteHaptics: ViewModifier {
    let sent: Int
    let failed: Int
    func body(content: Content) -> some View {
        content
            .cyHaptic(.success, trigger: sent)
            .cyHaptic(.warning, trigger: failed)
    }
}
