import CoreLocation
import SwiftUI
import UIKit

/// Mode-2 pass/card-pack/store choice. Only these two free-exploration hosts reuse
/// this surface; city orientation retains its own route/task interface.
@MainActor struct FreeExplorationCardBrowser: View {
    let snapshot: PlaySnapshot
    @Binding var packOpen: Bool
    /// 切换章节 (mini-program mode 2): nil shows every chapter's stores.
    var chapterFilter: Int? = nil
    /// `productType` other than 2 skips the pack (mini-program `skipPack`).
    var skipsPack = false
    let onSelect: (Int) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tearing = false
    @State private var dealt = 0
    @State private var dealing = false
    @State private var packStartedAt: Date?
    @State private var packTask: Task<Void, Never>?
    var body: some View {
        if let presentation = FreeExplorationPresentation(snapshot: snapshot) {
            let stores = presentation.stores.filter { chapterFilter == nil || $0.chapterID == chapterFilter }
            VStack(alignment: .leading, spacing: 20) {
                // mp-journey r3 (MP pages/play/index.wxml `fx`, mode 2): before the pack opens the screen holds only the
                // pack; the pass head (claim · sub · ring or 已解锁 · meta) and 探索节点 arrive with the first card.
                if packOpen || skipsPack || presentation.stores.isEmpty || snapshot.availability == .registrationRequired {
                    passHead(presentation)
                }
                if snapshot.availability == .registrationRequired { Text("playFree.registrationRequired") }
                else if !packOpen && !skipsPack && !presentation.stores.isEmpty {
                    // Foil pack printed with the topic name (x-fix7 P-6). Tap tears it open: a short shake and
                    // burst, then the store cards are dealt one by one. Reduce Motion: opens at once.
                    Button { openPack(count: presentation.stores.count) } label: {
                        // MP `.fx-pack__foil` (pages/play/assets/pack-foil.png) is the pack body; the topic name is printed in black.
                        VStack(spacing: 18) {
                            // MP x-fix7 P-6: the pack carries the topic name only; no chapter subtitle, no "tap to open".
                            Text(verbatim: snapshot.result.topicName ?? "").cyText(.sectionTitle).cyLookTitle()
                                .foregroundStyle(Color.black).multilineTextAlignment(.center).lineLimit(2)
                        }.frame(maxWidth: .infinity, minHeight: 200)
                            .padding(CYSpacing.xl)
                            .background {
                                MPAsset.Other.packFoil.resizable()
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
                                    .accessibilityHidden(true)
                            }
                            .rotationEffect(.degrees(tearing && !reduceMotion ? -2.5 : 0))
                            .scaleEffect(tearing && !reduceMotion ? 1.06 : 1)
                            .opacity(tearing ? 0 : 1)
                    }.buttonStyle(.plain)
                    .accessibilityLabel(Text("playFree.pack.open"))
                    .accessibilityIdentifier("playFree.pack.open")
                    .sensoryFeedback(.impact(weight: .heavy), trigger: tearing)
                } else {
                    // MP `fx-lhd__t` 探索节点 (hidden for a perk-only topic).
                    if !FreeExplorationStoryFacts(snapshot: snapshot).isPerkOnly { CYSectionHeader("playFree.nodes.header") }
                    if stores.isEmpty { CYEmptyState(systemImage: "storefront", "playFree.stores.empty") }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(Array(stores.enumerated()), id: \.element.id) { index, node in
                            Button { onSelect(node.id) } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: "storefront.fill").font(.title).foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
                                    // mp-journey r3 (MP `fx-tile__chap`): one chapter per shop; the chapter is the card's identity.
                                    if let label = Self.chapterLabel(for: node, in: snapshot) {
                                        label.font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                                    }
                                    FreeExplorationStoreName(name: node.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                    if let title = node.gameTitle, !title.isEmpty { Text(verbatim: title).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                                    if let open = node.openStatus, !open.isEmpty { Text(verbatim: open).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary) }
                                    CYStatusChip(LocalizedStringKey(FreeExplorationPresentation.state(of: node, in: snapshot).titleKey), tone: .neutral)
                                    Group {
                                        if snapshot.isStoryLocked(node) {
                                            CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                                                .accessibilityLabel(Text("playFree.story.locked.a11y"))
                                                .accessibilityIdentifier("playFree.story.locked.\(node.id)")
                                        } else if node.visitedByTeam == true {
                                            CYStatusChip("playFree.story.visitedByTeam", tone: .info, systemImage: "person.2")
                                        }
                                    }
                                    .animation(reduceMotion ? nil : CYMotion.reduced, value: snapshot.isStoryLocked(node))
                                }.frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                                    .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                            }.buttonStyle(.plain).accessibilityIdentifier("playFree.store.\(node.id)")
                            .opacity(!dealing || index < dealt ? 1 : 0)
                            .offset(y: !dealing || index < dealt ? 0 : 40)
                            .rotationEffect(.degrees(!dealing || index < dealt ? 0 : (index.isMultiple(of: 2) ? -6 : 6)))
                        }
                    }
                }
            }
            .onDisappear { packTask?.cancel(); packTask = nil; packStartedAt = nil }
        }
    }
}
extension FreeExplorationExperienceView {
    /// `utils/motion-preference.js`: the same stored preference the city run's 游玩工具 writes.
    /// MP `gpsOk` (when-in-use or always) for the 自动记录足迹 row.
    fileprivate static var freeLocationAuthorized: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    /// MP `onLocationRowTap` with location off: this app's location setting.
    fileprivate static func openFreeLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    /// MP 我的权益: shops on this pass and how many are redeemed.
    fileprivate var freeRights: PlayToolsRights? {
        guard let snapshot = model.snapshot, let presentation = FreeExplorationPresentation(snapshot: snapshot) else { return nil }
        return PlayToolsRights(total: presentation.stores.count, redeemed: presentation.redeemed ?? 0)
    }
    fileprivate var freeReducedMotionBinding: Binding<Bool> {
        Binding(get: { _ = playReducedMotion; return PlayReducedMotionPreference.isEnabled(in: .standard) },
                set: { on in PlayReducedMotionPreference.set(on, in: .standard); playReducedMotion = on })
    }
}

extension FreeExplorationCardBrowser {
    /// MP `fx-pass`: the topic name as the claim, the description under it, then the ring (已完成 done/total) or, for a
    /// story-gated topic, 已解锁 x / y 章, and the meta lines (自由探索中 · 有效期至 …, N 章 · M 家商家).
    /// MP `chapterLabel`: 第 N 章 · title, or the title alone when it already starts with 第…章. Nil without a chapter.
    static func chapterLabel(for node: PlayNode, in snapshot: PlaySnapshot) -> Text? {
        guard let chapterID = node.chapterID,
              let index = snapshot.result.chapters.firstIndex(where: { $0.id == chapterID }) else { return nil }
        let title = (snapshot.result.chapters[index].name ?? "").trimmingCharacters(in: .whitespaces)
        if title.isEmpty { return Text("playFree.tile.chapterNo \(index + 1)") }
        if title.range(of: "^第\\s*[0-9一二三四五六七八九十百]+\\s*章", options: .regularExpression) != nil {
            return Text(verbatim: title)
        }
        return Text("playFree.tile.chapter \(index + 1) \(title)")
    }

    @ViewBuilder fileprivate func passHead(_ presentation: FreeExplorationPresentation) -> some View {
        let facts = FreeExplorationStoryFacts(snapshot: snapshot)
        let claim = snapshot.result.topicName ?? snapshot.result.chapters.first?.name
        VStack(alignment: .leading, spacing: 12) {
            if let claim, !claim.isEmpty {
                Text(verbatim: claim).cyText(.pageTitle).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("playFree.pass")
            } else {
                Text("playFree.title").cyText(.pageTitle).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("playFree.pass")
            }
            if let description = snapshot.result.topicDescription ?? snapshot.result.chapters.first?.description, !description.isEmpty {
                Text(verbatim: description).cyText(.body).foregroundStyle(CYColor.textSecondary)
            }
            HStack(spacing: 14) {
                if !facts.isPerkOnly, let unlocked = facts.storyUnlocked, let total = facts.storyTotal {
                    Text("playFree.story.unlocked.count \(unlocked) \(total)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .accessibilityIdentifier("playFree.story.unlocked.count")
                } else if !facts.isPerkOnly, let done = presentation.redeemed, let total = presentation.total {
                    // Mini-program 已核销环: one ring that fills as stores are redeemed.
                    CYRing(progress: CYRingMath.fraction(done, of: total), tint: CYColor.textPrimary, diameter: 52, lineWidth: 5) {
                        Text(verbatim: "\(done)/\(total)")
                            .cyText(.micro, monospacedDigit: true)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText(value: Double(done)))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("playFree.redeemed.count \(done) \(total)"))
                    .accessibilityIdentifier("playFree.redeemed.count")
                }
                VStack(alignment: .leading, spacing: 4) {
                    if snapshot.result.selfPlay == true, let expiry = snapshot.result.expiresAt, !expiry.isEmpty {
                        Text("playFree.selfPlayBanner \(expiry)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    if facts.isPerkOnly {
                        Text("playFree.meta.stores \(presentation.stores.count)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    } else {
                        Text("playFree.meta.chaptersStores \(snapshot.result.chapters.count) \(presentation.stores.count)")
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
        }
    }

    private func openPack(count: Int) {
        if tearing || dealing {
            // D-26: tapping during opening/dealing after 300ms skips straight to settled open state.
            guard PlayPackSkipPolicy.canSkip(isPlaying: true, isOpen: packOpen, startedAt: packStartedAt) else { return }
            packTask?.cancel(); packTask = nil; packStartedAt = nil
            tearing = false; dealing = false; dealt = count; packOpen = true
            return
        }
        if reduceMotion { dealt = count; packOpen = true; return }
        packStartedAt = Date()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { tearing = true }
        packTask = Task { @MainActor in
            defer { packTask = nil; packStartedAt = nil }
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            dealt = 0; dealing = true
            withAnimation(CYMotion.standard) { packOpen = true }
            for index in 0..<count {
                try? await Task.sleep(for: .milliseconds(70))
                guard !Task.isCancelled else { return }
                withAnimation(CYMotion.entrance) { dealt = index + 1 }
            }
            tearing = false; dealing = false
        }
    }
}

struct FreeExplorationStoreName: View {
    let name: String?
    var body: some View {
        Group {
            if let name, !name.isEmpty { Text(verbatim: name) }
            else { Text("playFree.store.untitled") }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor struct FreeExplorationExperienceView: View {
    @Bindable var model: PlayExperienceCoordinator
    let storeDestination: (Int) -> AnyView
    var rewardCollectionDestination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    /// Cast ending for this run. Nil config draws nothing. The read gate is not this view's.
    var castConfig: CastConfig? = nil
    var castEnding: PlayWireValue = .null
    @State private var selectedStore: Int?
    @State private var packOpen = false
    @State private var chapterFilter: Int?
    @State private var showChapterPicker = false
    @State private var showEmergencyHelp = false
    /// mp-journey r3 (MP P-28): free exploration opens the same 游玩工具 sheet as city orientation (旅程手记, preferences).
    @State private var showPlayTools = false
    @AppStorage(PlatformBGMPreference.storageKey) private var playBGMOn = PlatformBGMPreference.defaultValue
    @AppStorage(PlatformNarrationAutoplayPreference.storageKey) private var playNarrationOn = PlatformNarrationAutoplayPreference.defaultValue
    @AppStorage(PlayReducedMotionPreference.storageKey) private var playReducedMotion = false
    @Environment(\.locale) private var locale
    @Environment(\.playThemePresentationReader) private var themeReader
    private var themeFacts: PlayThemePresentationFacts? {
        model.snapshot?.result.topicID.flatMap { themeReader?.facts(topicID: $0) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.phase == .loading { CYSkeleton().accessibilityLabel(Text("playx.loading")) }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                if model.snapshot == nil, model.storyArchive != nil { FreeExplorationArchiveCards(model: model) }
                if !model.available { CYEmptyState(systemImage: "nosign", "playx.disabled") }
                if model.hasCurrentMediaSnapshot, let snapshot = model.snapshot {
                    FreeExplorationCardBrowser(snapshot: snapshot, packOpen: $packOpen, chapterFilter: chapterFilter,
                                               skipsPack: themeFacts?.skipsCardPack == true) { id in
                        guard model.hasCurrentMediaSnapshot, model.snapshot == snapshot, model.gameplayMode == .freeExploration else { return }
                        selectedStore = id
                    }
                    if let reward = model.reward {
                        if let drop = PlayRewardDrop.fromReward(reward) {
                            Label(drop.toastMessage(locale: locale), systemImage: "sparkles")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.successText)
                                .accessibilityIdentifier("playFree.reward.drop")
                        }
                        if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                            Label(dispatched.revealTitle(locale: locale), systemImage: "shippingbox.fill")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textPrimary)
                                .accessibilityIdentifier("playFree.reward.dispatchedTask")
                        }
                        PlayRewardBadgeRows(targets: PlayRewardBadgeTarget.targets(in: reward), destination: rewardCollectionDestination)
                            .id(PlayRewardBadgeTarget.targets(in: reward))
                    }
                    if model.unresolved { Text(LocalizedStringKey(model.hasModeRecoveryBlock ? "playMode.recoveryBlocked" : "playFree.proof.pending")).font(.footnote) }
                    if model.storyArchive != nil { FreeExplorationArchiveCards(model: model) }
                    let perkOnly = FreeExplorationStoryFacts(snapshot: snapshot).isPerkOnly
                    if !perkOnly, FreeExplorationPresentation(snapshot: snapshot)?.isFullyRedeemed == true {
                        CYSectionHeader("playFree.redeemed.title")
                        ForEach(snapshot.visibleNodes.filter(snapshot.isDone)) { node in
                            Label { FreeExplorationStoreName(name: node.name) } icon: { Image(systemName: "checkmark.seal") }
                        }
                        CYPillButton("playFree.ending.read") { Task { await model.loadFreeExplorationEnding() } }
                        if let ending = model.ending {
                            if !ending.opener.isEmpty { Text(verbatim: ending.opener) }
                            ForEach(Array(ending.fragments.enumerated()), id: \.offset) { _, fragment in
                                VStack(alignment: .leading) {
                                    Text(verbatim: fragment.name).font(.headline)
                                    if let text = fragment.text, !text.isEmpty { Text(verbatim: text) }
                                }
                            }
                            if let castConfig {
                                CastEndingSection(config: castConfig, result: CastEndingResult(raw: castEnding))
                            }
                        }
                    }
                }
            }.padding(CYSpacing.pageHorizontal)
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .refreshable { if model.available && model.phase != .submitting { await model.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load() } } label: { Label("playx.refresh", systemImage: "arrow.clockwise") }
                    .disabled(!model.available || model.phase == .submitting || model.phase == .loading)
                    .accessibilityIdentifier("playFree.refresh")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Mini-program mode 2 keeps 切换章节 in the tools layer (the old bottom-bar left key).
                PlayToolsMenu(showsChapters: model.snapshot.map { !FreeExplorationStoryFacts(snapshot: $0).isPerkOnly && $0.result.chapters.count > 1 } == true, showsEmergency: model.snapshot != nil,
                              openChapters: { showChapterPicker = true }, openEmergency: { showEmergencyHelp = true },
                              openPreferences: model.snapshot == nil ? nil : { showPlayTools = true })
            }
        }
        .cySheet(isPresented: $showEmergencyHelp) { PlayEmergencyHelpSheet() }
        .sheet(isPresented: $showPlayTools) {
            PlayToolsAndLeadSheetView(
                bgmEnabled: $playBGMOn,
                narrationAutoplay: $playNarrationOn,
                reduceMotionOverride: freeReducedMotionBinding,
                onClose: { showPlayTools = false },
                showsContentRows: false,
                locationOn: Self.freeLocationAuthorized,
                onLocationRow: Self.openFreeLocationSettings,
                journalRows: model.snapshot.map(PlayJournal.rows(in:)),
                rights: freeRights,
                onRights: {
                    // MP openRightsFromTools (mode 2): the perks are the cards, so the sheet closes onto the grid.
                    showPlayTools = false
                    packOpen = true
                },
                freeTrackPerkOnly: model.snapshot.map { FreeExplorationStoryFacts(snapshot: $0).isPerkOnly } ?? false
            )
        }
        .cySheet(isPresented: $showChapterPicker) {
            if let snapshot = model.snapshot {
                PlayChapterPickerSheet(rows: PlayChapterPickRow.rows(snapshot), current: chapterFilter) { picked in
                    withAnimation(CYMotion.standard) { chapterFilter = picked; packOpen = true }
                }
            }
        }
        .cyThemeLook(themeFacts?.look)
        .accessibilityIdentifier("playFree.overview")
            .navigationDestination(item: $selectedStore) { id in storeDestination(id) }
            .onChange(of: model.identity) { _, _ in selectedStore = nil; packOpen = false; chapterFilter = nil }
            .onChange(of: model.gameplayMode) { _, mode in if mode != nil && mode != .freeExploration { selectedStore = nil; packOpen = false } }
    }
}

/// Store visit commands remain check-in/photo evidence, not route completion.
/// In-store games and scoped consent/redemption stay unavailable until migrated.
@MainActor struct FreeExplorationStoreView: View {
    let nodeID: Int
    @Bindable var model: PlayExperienceCoordinator
    let device: PlayDeviceCaptureCoordinator?
    let shopNPC: ShopNPCNodeHost?
    let mediaScope: UUID
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    let storyDestination: (PlayNode) -> AnyView?
    var storeDayModel: ((Int) -> PlayStoreDayCoordinator?)? = nil
    /// One-shot when-in-use location. The play host passes `RuntimeNativeLocationProvider`.
    var arrivalLocation: (any RoamDeviceLocationProviding)? = nil
    @State private var arrival: PlayArrivalService?
    @State private var review: PlayCompletionReview?
    @State private var showingReview = false
    @State private var issue: PlayExperienceError?
    @State private var storeToastMessage: String?
    @Environment(\.locale) private var locale
    private var node: PlayNode? {
        guard model.gameplayMode == .freeExploration else { return nil }
        return model.snapshot?.visibleNodes.first { $0.id == nodeID }
    }
    private var activeDispatchedTask: PlayRandomDispatchedTask? {
        if let reward = model.reward, reward["nodeId"].tolerantInteger == nodeID,
           let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
            return dispatched
        }
        return model.extras[nodeID]?.dispatchedTask
    }
    var body: some View {
        let context = model.interactionContext
        List {
            if let node, let snapshot = model.snapshot {
                Section {
                    FreeExplorationStoreName(name: node.name).cyText(.sheetTitle)
                    Text(LocalizedStringKey(FreeExplorationPresentation.state(of: node, in: snapshot).titleKey))
                    // mp-journey r3 (MP fx-hero order): 小瘾说 hook right under the name.
                    if let hook = node.hookText, !hook.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("playFree.hero.hook").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(verbatim: hook)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let dispatched = activeDispatchedTask {
                    Section {
                        CYStatusChip(
                            verbatim: CoreLoopCopy(locale: locale).t("今日盲盒任务", "Today's Mystery Task"),
                            tone: .info,
                            systemImage: "shippingbox.fill"
                        )
                        Text(verbatim: dispatched.displayName)
                            .cyText(.cardTitle)
                        if let rule = dispatched.ruleInstructions, !rule.isEmpty {
                            Text(verbatim: rule)
                                .cyText(.bodyCompact)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("playFree.random.dispatchedTask")
                }
                if snapshot.isStoryLocked(node) {
                    FreeExplorationLockCard(node: node, snapshot: snapshot, arrival: arrival, context: context)
                } else if !snapshot.isLocked(node) {
                    if let description = node.description { Section { Text(verbatim: description) } }
                    if let hours = node.businessTime { LabeledContent("play.businessTime") { Text(verbatim: hours) } }
                    if model.hasCurrentMediaSnapshot, node.npc != nil, let shopNPC {
                        Section {
                            ShopNPCNodeEntrance(name: shopNPC.name, makeCoordinator: shopNPC.makeCoordinator, greeting: shopNPC.greeting,
                                makeScriptedGuide: { scope in ShopNPCScriptedGuideSource(runtime: model, nodeID: nodeID, conversation: scope) }).id(shopNPC.identity)
                        }
                    }
                    if let story = storyDestination(node) { NavigationLink("playFree.story") { story } }
                    PlatformExternalMapHost(destination: .init(name: node.name ?? "", address: node.address,
                        latitude: node.latitude, longitude: node.longitude), scope: mediaScope, makeModel: makeExternalMaps)
                    FreeExplorationHeroPerkAndGame(node: node)
                    FreeExplorationVisitSteps(node: node)
                    if let storeDayModel { PlayStoreDayMerchantEntry(nodeID: nodeID, make: storeDayModel, makeExternalMaps: makeExternalMaps, mediaScope: mediaScope) }
                    // In-store games, redemption codes and missing evidence steps have no native flow yet;
                    // their placeholder notices are not shown.
                    if arrival?.offer(for: node.id) == nil, node.done != true, node.selfReported != true,
                       let task = FreeExplorationPresentation.evidenceTask(for: node, in: snapshot), let device {
                        PlayDeviceTaskSection(model: device, task: task, interaction: .init(context: context, current: { model.interactionContext }), onEvidence: { prepare($0, context: $1) })
                    }
                }
                if model.unresolved { Text(LocalizedStringKey(model.hasModeRecoveryBlock ? "playMode.recoveryBlocked" : "playFree.proof.pending")) }
                if let issue { PlayExperienceIssueView(issue: issue) }
            } else if model.phase == .loading || model.phase == .submitting { ProgressView("playx.loading") }
            else { CYEmptyState(systemImage: "storefront", "playFree.store.unavailable") }
        }.cyGroupedSurface()
        .refreshable { if model.phase != .loading && model.phase != .submitting { await model.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load() } } label: { Label("playx.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.phase == .loading || model.phase == .submitting)
            }
        }
        .privacySensitive().cyPageTitle("playFree.store.title").accessibilityIdentifier("playFree.store.detail")
            .cyModalConfirm(
                isPresented: showingReview,
                title: appLocalized("playx.review", locale: .current),
                message: appLocalized("playFree.evidence.notice", locale: .current),
                cancelTitle: appLocalized("playx.cancel", locale: .current),
                confirmTitle: appLocalized("playFree.evidence.submit", locale: .current),
                onCancel: { showingReview = false; review = nil; model.cancelReview() },
                onConfirm: {
                    showingReview = false
                    guard let review else { return }
                    self.review = nil
                    Task { await model.submit(review) }
                }
            )
            .onChange(of: model.reward) { _, reward in
                guard let reward, reward["nodeId"].tolerantInteger == nodeID else { return }
                if let drop = PlayRewardDrop.fromReward(reward) {
                    storeToastMessage = drop.toastMessage(locale: locale)
                } else if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                    storeToastMessage = dispatched.revealTitle(locale: locale)
                }
            }
            .cyToast(verbatimMessage: $storeToastMessage)
            .onAppear { if arrival == nil { arrival = PlayArrivalService(runtime: model, location: arrivalLocation) } }
            .onDisappear { device?.cancel(); arrival?.cancel(); review = nil; model.cancelReview() }
    }
    private func prepare(_ evidence: PlayCompletionEvidence, context: PlayInteractionContext?) {
        guard let node, let snapshot = model.snapshot, FreeExplorationPresentation.evidenceTask(for: node, in: snapshot) != nil else { return }
        do { review = try model.review(nodeID: nodeID, evidence: evidence, context: context); showingReview = true; issue = nil }
        catch { issue = error as? PlayExperienceError ?? .invalidAction }
    }
}
/// Lock card for a story the player has not visited. The grid above stays the store browser.
@MainActor struct FreeExplorationLockCard: View {
    let node: PlayNode
    let snapshot: PlaySnapshot
    let arrival: PlayArrivalService?
    let context: PlayInteractionContext?
    var body: some View {
        Section {
            CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                .accessibilityLabel(Text("playFree.story.locked.a11y"))
                .accessibilityIdentifier("playFree.story.locked.\(node.id)")
            Text("playFree.story.lockedCard").font(.subheadline)
            if let hook = node.cardHookLong, !hook.isEmpty { Text(verbatim: hook) }
            if node.addressHidden != true, let address = node.address, !address.isEmpty { Text(verbatim: address) }
            if let hours = node.businessTime, !hours.isEmpty { LabeledContent("play.businessTime") { Text(verbatim: hours) } }
            if node.visitCheck == .scan {
                Text("playFree.story.scanUnlock")
            } else if node.visitCheck == .online {
                Text("playFree.story.unlock.scan")
            } else {
                Text("playFree.story.unlock.gps \(node.visitRadius ?? PlayArrivalPolicy.visitDefaultRadiusMeters)")
            }
            if let arrival { PlayArrivalControl(arrival: arrival, nodeID: node.id, context: context) }
        }
    }
}

/// Offline or expired chapters, in the same card surface as the store browser.
@MainActor struct FreeExplorationArchiveCards: View {
    let model: PlayExperienceCoordinator
    var body: some View {
        if let archive = model.storyArchive {
            CYSectionHeader(model.storyArchiveSource == .expired ? "playFree.archive.expired" : "playFree.archive.offline")
            if let unlocked = archive.storyUnlocked, let total = archive.storyTotal {
                Text("playFree.story.unlocked.count \(unlocked) \(total)").font(.subheadline).monospacedDigit()
            }
            ForEach(archive.places) { place in
                VStack(alignment: .leading, spacing: 8) {
                    FreeExplorationStoreName(name: place.name).font(.headline)
                    if let time = place.visitTimeText {
                        Text("playFree.story.visitedOn \(time)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(Array(place.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(verbatim: paragraph).font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                .accessibilityIdentifier("playFree.archive.place.\(place.id)")
            }
            ForEach(archive.lockedPlaces) { place in
                HStack {
                    FreeExplorationStoreName(name: place.name).font(.headline)
                    Spacer()
                    CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                        .accessibilityLabel(Text("playFree.story.locked.a11y"))
                }
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
            }
        }
    }
}

/// 「我已到达」. One control. The device scan/arrive row is hidden while this offer is up.
@MainActor struct PlayArrivalControl: View {
    @Bindable var arrival: PlayArrivalService
    let nodeID: Int
    let context: PlayInteractionContext?
    var body: some View {
        if let kind = arrival.offer(for: nodeID) {
            VStack(alignment: .leading, spacing: 8) {
                switch kind {
                case .start: Text("playArrival.start.hint").font(.subheadline)
                case .stationTap: Text("playArrival.station.hint").font(.subheadline)
                case .freeVisit:
                    Text("playArrival.visit.hint \(PlayArrivalPolicy.visitDefaultRadiusMeters)").font(.subheadline)
                }
                switch arrival.phase {
                case .locating: ProgressView("playArrival.locating")
                case .submitting: ProgressView("playArrival.submitting")
                case .succeeded: Text("playArrival.succeeded").font(.body)
                case .rejected(let rejection):
                    if let message = rejection.message, !message.isEmpty { Text(verbatim: message).font(.body) }
                    else { Text(LocalizedStringKey(rejection.reason.localizationKey)).font(.body) }
                    if let distance = rejection.distanceMeters { Text("playArrival.distance \(distance)").font(.subheadline) }
                case .unknown:
                    Text("playArrival.unknown").font(.subheadline)
                    Button("playArrival.reread") { Task { await arrival.reread() } }
                case .unavailable: Text("playArrival.unavailable").font(.subheadline)
                case .locationUnavailable: Text("playArrival.location.unavailable").font(.subheadline)
                case .idle: EmptyView()
                }
                CYPillButton("playArrival.action", systemImage: "location.fill") {
                    Task { await arrival.arrive(nodeID: nodeID, context: context) }
                }
                .disabled(arrival.isBusy || arrival.phase == .unknown || arrival.phase == .succeeded)
                .accessibilityIdentifier("playArrival.action")
            }
        }
    }
}

struct FreeExplorationVisitSteps: View {
    let node: PlayNode
    var body: some View {
        Section("playx.merchant.steps") {
            VStack(alignment: .leading, spacing: 2) {
                Label("playx.merchant.scan", systemImage: node.arrived == true ? "checkmark.circle" : "circle")
                Text("playx.merchant.scan.detail").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Label("playx.merchant.photo", systemImage: node.selfReported == true ? "checkmark.circle" : "circle")
                if node.arrived == true {
                    if let requirement = node.photoRequirement, !requirement.isEmpty { Text(verbatim: requirement).font(.caption).foregroundStyle(.secondary) }
                    else { Text("playx.merchant.photo.default").font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("playx.merchant.photo.locked").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Label("playx.merchant.verify", systemImage: node.done == true ? "checkmark.circle" : "circle")
                Text("playx.merchant.verify.detail").font(.caption).foregroundStyle(.secondary)
            }
            Text("playx.merchant.notice").font(.footnote)
            if node.arrived == true, let rule = node.ruleInstructions, !rule.isEmpty { Text(verbatim: rule).font(.footnote) }
        }
        Section("playx.merchant.reference") {
            LabeledContent("playx.merchant.onsite") {
                Text(LocalizedStringKey(node.crowded == true ? "playx.merchant.crowd.queue" : (node.crowded == false ? "playx.merchant.crowd.go" : "playx.merchant.crowd.unknown")))
            }
            LabeledContent("playx.merchant.stat.load") { Text(verbatim: PlayNode.formatQueueCount(node.inStoreLoad)) }
            LabeledContent("playx.merchant.stat.perHour") { Text(verbatim: Self.formatStat(node.servicePerHour)) }
            LabeledContent("playx.merchant.stat.wait") { Text(verbatim: PlayNode.formatQueueCount(node.expectedWaitMinutes)) }
            if node.quantityUnavailable == true {
                Text("playx.merchant.degraded.quantity").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    static func formatStat(_ value: Double?) -> String {
        PlayNode.formatQueueRate(value)
    }
}

/// Ordinary Activity → Play uses a read-only reader when no runtime factory is granted.
@MainActor struct FreeExplorationReadStoreView: View {
    let nodeID: Int
    let model: PlayViewModel
    var body: some View {
        List {
            if let snapshot = model.visibleSnapshot, snapshot.result.mode == 2, snapshot.availability != .registrationRequired,
               let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }) {
                Section {
                    FreeExplorationStoreName(name: node.name).cyText(.sheetTitle)
                    Text(LocalizedStringKey(FreeExplorationPresentation.state(of: node, in: snapshot).titleKey))
                }
                if snapshot.isStoryLocked(node) {
                    Section {
                        CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                            .accessibilityLabel(Text("playFree.story.locked.a11y"))
                        Text("playFree.story.lockedCard")
                    }
                } else if !snapshot.isLocked(node) {
                    if node.addressHidden != true, let address = node.address { Text(verbatim: address) }
                    if let hours = node.businessTime { LabeledContent("play.businessTime") { Text(verbatim: hours) } }
                    if let story = node.storyText { Section("playFree.story") { Text(verbatim: story) } }
                    FreeExplorationVisitSteps(node: node)
                }
                Button("play.refresh") { Task { await model.load(keepingReceipt: true) } }
            } else if model.isLoading { ProgressView("play.loading") }
            else { Text("playFree.store.unavailable") }
        }.cyGroupedSurface().privacySensitive().cyPageTitle("playFree.store.title").accessibilityIdentifier("playFree.read.store")
    }
}

/// mp-journey r3: MP `fx-hero` ⑤ 本店权益 and ③ 本站游戏 (kind, title, duration / players, 怎么玩 steps, 需要准备).
/// Only fields the server sent; a section with nothing to say is not drawn (MP `_heroView`).
struct FreeExplorationHeroPerkAndGame: View {
    let node: PlayNode

    var body: some View {
        if let perkName = node.perk?.name, !perkName.isEmpty {
            Section("playFree.hero.perk") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: perkName).font(.headline)
                        if let rule = node.perk?.redeemRule, !rule.isEmpty {
                            Text(verbatim: rule).font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Text("playFree.hero.perk.defaultRule").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "gift")
                }
            }
        }
        if let title = node.gameTitle, !title.isEmpty {
            Section {
                Text(verbatim: title).font(.headline)
                if let minutes = node.durationMinutes, minutes > 0 {
                    Label { Text("playFree.hero.minutes \(minutes)") } icon: { Image(systemName: "clock") }
                        .font(.subheadline)
                }
                if let players = node.players, !players.isEmpty {
                    Label { Text(verbatim: players) } icon: { Image(systemName: "person.2") }
                        .font(.subheadline)
                }
                let steps = Self.steps(node.ruleInstructions)
                if !steps.isEmpty {
                    Text("playFree.hero.howTo").font(.subheadline.weight(.semibold))
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: "\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                            Text(verbatim: step)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let materials = node.requiredMaterials, !materials.isEmpty {
                    Text("playFree.hero.materials").font(.subheadline.weight(.semibold))
                    Text(verbatim: materials)
                }
            } header: {
                gameHeader
            }
        }
    }

    @ViewBuilder private var gameHeader: some View {
        switch node.validationMethod {
        case 2: Text("playFree.hero.game.photo")
        case 1, 3: Text("playFree.hero.game.quiz")
        case 4: Text("playFree.hero.game.checkIn")
        default: Text("playFree.hero.game")
        }
    }

    /// MP: the rule text split by line breaks, blank lines dropped.
    static func steps(_ text: String?) -> [String] {
        guard let text else { return [] }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
