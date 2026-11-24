import SwiftUI

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
                Text("playFree.title").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("playFree.pass")
                if let title = snapshot.result.topicName { CYHeroHeader(verbatim: title, subtitle: snapshot.result.topicDescription) }
                else if let description = snapshot.result.topicDescription { Text(verbatim: description).cyText(.body).foregroundStyle(CYColor.textSecondary) }
                Text("playFree.choiceHint").cyText(.body).foregroundStyle(CYColor.textSecondary)
                let facts = FreeExplorationStoryFacts(snapshot: snapshot)
                if !facts.isPerkOnly, let unlocked = facts.storyUnlocked, let total = facts.storyTotal {
                    Text("playFree.story.unlocked.count \(unlocked) \(total)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .accessibilityIdentifier("playFree.story.unlocked.count")
                }
                if let done = presentation.redeemed, let total = presentation.total {
                    // Mini-program 已核销环: one ring that fills as stores are redeemed.
                    HStack(spacing: 14) {
                        Gauge(value: Double(done), in: 0...Double(max(total, 1))) { EmptyView() } currentValueLabel: {
                            Text(verbatim: "\(done)/\(total)").monospacedDigit()
                        }
                        .gaugeStyle(.accessoryCircularCapacity).tint(CYColor.textPrimary)
                        .accessibilityHidden(true)
                        Text("playFree.redeemed.count \(done) \(total)").monospacedDigit()
                            .cyText(.label).foregroundStyle(CYColor.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("playFree.redeemed.count")
                }
                if let expiry = snapshot.result.expiresAt { LabeledContent("play.expiresAt") { Text(verbatim: expiry) } }
                if let note = snapshot.result.timeNote { Text(verbatim: note).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                if snapshot.availability == .registrationRequired { Text("playFree.registrationRequired") }
                else if !packOpen && !skipsPack && !presentation.stores.isEmpty {
                    // Foil pack printed with the topic name (x-fix7 P-6). Tap tears it open: a short shake and
                    // burst, then the store cards are dealt one by one. Reduce Motion: opens at once.
                    Button { openPack(count: presentation.stores.count) } label: {
                        // MP `.fx-pack__foil` (pages/play/assets/pack-foil.png) is the pack body; the topic name is printed in black.
                        VStack(spacing: 18) {
                            Text(verbatim: snapshot.result.topicName ?? "").cyText(.sectionTitle).cyLookTitle()
                                .foregroundStyle(Color.black).multilineTextAlignment(.center).lineLimit(2)
                            Text("playFree.pack.open").cyText(.label).foregroundStyle(Color.black.opacity(0.6))
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
                    }.buttonStyle(.plain).accessibilityIdentifier("playFree.pack.open")
                    .sensoryFeedback(.impact(weight: .heavy), trigger: tearing)
                } else {
                    CYSectionHeader("playFree.stores")
                    if stores.isEmpty { CYEmptyState(systemImage: "storefront", "playFree.stores.empty") }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(Array(stores.enumerated()), id: \.element.id) { index, node in
                            Button { onSelect(node.id) } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: "storefront.fill").font(.title).foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
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
extension FreeExplorationCardBrowser {
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
                              openChapters: { showChapterPicker = true }, openEmergency: { showEmergencyHelp = true })
            }
        }
        .sheet(isPresented: $showEmergencyHelp) { PlayEmergencyHelpSheet() }
        .sheet(isPresented: $showChapterPicker) {
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
