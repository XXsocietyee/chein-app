import SwiftUI

/// Integration entry for migrated runtime. Factories are scope-specific, optional, and
/// never create provider/network permissions as a side effect of opening the screen.
@MainActor struct PlayExperienceView: View {
    @Bindable var model: PlayExperienceCoordinator
    var deviceModel: ((Int) -> PlayDeviceCaptureCoordinator)? = nil
    var advancedModel: ((Int) -> PlayAdvancedCoordinator?)? = nil
    var motionModel: ((Int, PlayStillnessConfiguration) -> PlayStillnessCoordinator?)? = nil
    var preferenceModel: ((Int) -> PlayPreferenceCoordinator?)? = nil
    var summaryModel: ((Int) -> PlayOperatingSummaryCoordinator?)? = nil
    var playerModel: PlayPlayerGameCoordinator? = nil
    var circleModel: PlayCircleCoordinator? = nil
    var openingModel: PlayOpeningCompletionCoordinator? = nil
    var finishRouteModel: PlayFinishRouteRecommendationCoordinator? = nil
    var finishRouteDestination: ((Int) -> AnyView)? = nil
    var themeRecordsModel: PlayThemeRecordsCoordinator? = nil
    var backpackModel: PlayThemeBackpackCoordinator? = nil
    var entryCode: PlayEntryCodeContext? = nil
    /// W20 city business game. Nil (production until a reviewed endpoint and `cityActions` exist) hides the board.
    var cityGameModel: CityGameCoordinator? = nil
    var prefabModel: PlayPrefabRuntimeCoordinator? = nil
    var journeyModel: ((Int) -> JourneyCheckCoordinator?)? = nil
    var ambientModel: JourneyAmbientCoordinator? = nil
    var narrativeModel: ((JourneyNarrativeQuery) -> JourneyNarrativeCoordinator?)? = nil
    var narrativeImageReader: (any RetainedPublicImageReading)? = nil
    var shopNPCModel: ((Int) -> ShopNPCNodeHost?)? = nil
    var invalidateShopNPC: (() -> Void)? = nil
    var storeDayModel: ((Int) -> PlayStoreDayCoordinator?)? = nil
    var mediaScope: UUID = UUID()
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    var rewardCollectionDestination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    /// Session attachment. Nil leaves the map on the ids this view already holds.
    var routeActionRead: RouteActionPageReadRequest? = nil
    @State private var selectedNode: Int?
    @State private var showRouteMap = false
    @State private var confirmEnd = false
    @State private var presentedMode: PlayGameplayMode?
    @State private var presentationMount = PlayExperiencePresentationMount()
    /// Run-complete medal screen (mini-program medal-screen); shown once per session when the run completes.
    @State private var finishScreen = false
    @State private var finishShownFor: String?
    @Environment(\.locale) private var locale
    /// 切换章节: nil shows every chapter's places.
    @State private var chapterFilter: Int?
    @State private var showChapterPicker = false
    @State private var showEmergencyHelp = false
    @State private var titleCardTopic: Int?
    @Environment(\.playThemePresentationReader) private var themeReader
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mpParity) private var mpParity
    private func journeyRunScope(_ topicID: Int?, _ topicName: String?) -> JourneyRunScope {
        var scope = JourneyRunScope(topicID: topicID.map(String.init), topicName: topicName)
        if case .activity(let id) = model.scope { scope.activityID = String(id) }
        return scope
    }
    var body: some View {
        Group {
            if model.gameplayMode == .freeExploration || (model.snapshot == nil && presentedMode == .freeExploration) {
                FreeExplorationExperienceView(model: model, storeDestination: { AnyView(freeStoreDestination($0)) }, rewardCollectionDestination: rewardCollectionDestination)
            } else if model.gameplayMode == .cityOrientation {
                orientationContent.cyThemeLook(themeFacts?.look)
            } else if model.snapshot == nil {
                if model.phase == .loading {
                    CYSkeleton().padding(CYSpacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .accessibilityIdentifier("playMode.loading")
                } else {
                    VStack(spacing: CYSpacing.md) {
                        if model.available {
                            CYEmptyState(systemImage: "exclamationmark.triangle", "playx.error.title", actionTitle: "playx.refresh") {
                                if model.phase != .submitting { Task { await model.load() } }
                            }
                            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                        } else {
                            CYEmptyState(systemImage: "gamecontroller", "playx.disabled.title")
                            Text("playx.disabled").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("playx.disabled")
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else { CYEmptyState(systemImage: "questionmark.circle", "playMode.unavailable") }
        }
        .privacySensitive().appNavigationTitle(key: model.gameplayMode == .freeExploration ? "playFree.title" : "playx.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedNode) { id in nodeDestination(id) }
        .navigationDestination(isPresented: $showRouteMap) {
            PlayRouteMapView(
                model: model,
                nodeDestination: { AnyView(nodeDestination($0)) },
                actionRead: routeActionRead ?? heldRouteActionRead)
        }
        .confirmationDialog("playx.run.end", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("playx.run.end", role: .destructive) { Task { await model.endRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) } }
        } message: { Text("playx.run.end.detail") }
        .sheet(isPresented: $showEmergencyHelp) { PlayEmergencyHelpSheet() }
        .sheet(isPresented: $showChapterPicker) {
            if let snapshot = model.snapshot {
                PlayChapterPickerSheet(rows: PlayChapterPickRow.rows(snapshot), current: chapterFilter) { picked in
                    withAnimation(CYMotion.standard) { chapterFilter = picked }
                }
            }
        }
        .overlay { titleCardOverlay }
        .onChange(of: model.snapshot?.result.topicID) { _, topicID in
            chapterFilter = nil
            presentTitleCardIfNeeded(topicID)
        }
        .onChange(of: model.chapterStories.count) { _, _ in presentTitleCardIfNeeded(model.snapshot?.result.topicID) }
        .task(id: PlayExperiencePresentationKey(model: model)) {
            // This task also restarts when returning from a pushed store. Preserve
            // the same owner's mode host through refresh so its open card pack survives.
            if presentationMount.enter(model) { selectedNode = nil; presentedMode = nil }
            await model.load()
        }
        .onChange(of: model.gameplayMode) { _, mode in
            let previous = presentedMode
            if let mode { presentedMode = mode }
            if mode == .cityOrientation, previous != .cityOrientation {
                Task { await model.restoreRun(); projectAmbient() }
            }
            if let mode, mode != .cityOrientation { selectedNode = nil; confirmEnd = false }
        }
        .onChange(of: model.gameplayMode) { _, mode in
            if let mode, mode != .cityOrientation { showRouteMap = false }
        }
        .onChange(of: PlayExperiencePresentationKey(model: model)) { _, _ in showRouteMap = false; showChapterPicker = false; showEmergencyHelp = false }
        .onChange(of: model.snapshot?.result) { _, _ in if model.gameplayMode == .cityOrientation { projectAmbient() } }
        .onChange(of: model.snapshot) { _, _ in invalidateShopNPC?() }
        .onChange(of: model.snapshot?.availability) { old, new in
            // Present only on the live transition into completed, never for a run that was already complete on open.
            guard model.gameplayMode == .cityOrientation, old == .active, new == .completed,
                  model.hasCurrentMediaSnapshot, finishShownFor != model.identity else { return }
            finishShownFor = model.identity; finishScreen = true
        }
        .fullScreenCover(isPresented: $finishScreen) { finishMedalScreen }
        .onChange(of: model.hasCurrentMediaSnapshot) { _, current in if !current { invalidateShopNPC?() } }
        .onChange(of: scenePhase) { _, next in
            if model.gameplayMode == .cityOrientation, next != .active, model.clock.phase == .running {
                Task { await model.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) }
            }
        }
    }
    private var themeFacts: PlayThemePresentationFacts? {
        model.snapshot?.result.topicID.flatMap { themeReader?.facts(topicID: $0) }
    }
    /// 主题开场标题卡: once per topic on this device, only for a story route (chapters carry story blocks)
    /// or a product that skips the card pack.
    private func presentTitleCardIfNeeded(_ topicID: Int?) {
        guard let topicID, topicID > 0, !PlayThemeTitleCardMemory.seen(topicID), model.hasCurrentMediaSnapshot,
              let snapshot = model.snapshot, (snapshot.result.topicName ?? "").isEmpty == false else { return }
        let story = !model.chapterStories.isEmpty
        let freeWithoutPack = model.gameplayMode == .freeExploration && themeFacts?.skipsCardPack == true
        guard story || freeWithoutPack else { return }
        titleCardTopic = topicID
    }
    @ViewBuilder private var titleCardOverlay: some View {
        if let topicID = titleCardTopic, let snapshot = model.snapshot, snapshot.result.topicID == topicID {
            PlayThemeTitleCard(title: snapshot.result.topicName ?? "", line: PlayThemeIntro.line(snapshot.result.topicDescription),
                               modeKey: model.gameplayMode == .freeExploration ? "playFree.title" : "mpd.mode.cityOrientation",
                               aiGenerated: themeFacts?.aiGenerated == true, coverURL: themeFacts?.coverURL) {
                PlayThemeTitleCardMemory.markSeen(topicID)
                withAnimation(CYMotion.standard) { titleCardTopic = nil }
            }
            .cyThemeLook(themeFacts?.look)
            .transition(.opacity)
            .zIndex(10)
        }
    }
    /// Action id and route session id already on the completion journal or receipt.
    /// Absent ids leave this read closed. Does not mint either id and does not set an approval.
    private var heldRouteActionRead: RouteActionPageReadRequest? {
        guard let held = model.heldRouteActionIdentity else { return nil }
        return RouteActionPageReadRequest(sessionID: held.routeSessionID, actionID: held.actionID)
    }
    private var orientationList: some View {
        List {
            // Game header: topic and progress, the run clock, and the run / map controls in one card
            // (mini-program top bar + bottom run stack).
            Section {
                if let snapshot = model.snapshot {
                    PlayTaskSummaryView(snapshot: snapshot, phase: model.phase.rawValue)
                    if let note = snapshot.result.timeNote { Text(verbatim: note).foregroundStyle(.secondary) }
                }
                if !model.available { Text("playx.disabled").accessibilityIdentifier("playx.disabled") }
                if model.phase == .loading { CYSkeleton().accessibilityIdentifier("playx.loading") }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                if PlayContentCompatibility.isUnsupportedRejection(model.issue) {
                    // The server refused to open this run for this build; nothing was skipped or started.
                    Text("playCompat.refused.next", tableName: "PlayFullStory").font(CYTypography.caption)
                        .foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("playCompat.refused")
                }
                PlayResyncAction(model: model)
                if model.hasCurrentMediaSnapshot, let notice = model.routeNotice { PlayRouteNoticeRow(notice: notice) }
                if model.remoteRunSaveFailed { Label("playx.run.saveFailed", systemImage: "exclamationmark.triangle.fill").font(CYTypography.caption).foregroundStyle(CYColor.warningText) }
            }
            if let compatibility = model.compatibility, model.hasCurrentMediaSnapshot {
                PlayCompatibilitySection(compatibility: compatibility)
            }
            if let openingModel { PlayOpeningCompletionSection(model: openingModel) }
            if let entryCode { PlayEntryCodeSection(context: entryCode) }
            if let cityGameModel {
                Section { CityGamePanel(model: cityGameModel, read: cityGameModel.read, boardLayout: true) }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if model.hasCurrentMediaSnapshot, !model.unresolved, let snapshot = model.snapshot,
               let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
               let node = snapshot.visibleNodes.first(where: { $0.id == id }) {
                Section("referenceTask.current") {
                    PlayNodeTitle(name: node.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: snapshot.result.mode, node: node).rawValue))
                    PlayTaskStatusBadge(node: node, snapshot: snapshot)
                    Button("referenceTask.open") { selectedNode = id }
                        .buttonStyle(.questifyPrimary).accessibilityIdentifier("referenceTask.open")
                }
            }
            if model.unresolved {
                Section("playx.unknown.title") {
                    Text(LocalizedStringKey(model.hasModeRecoveryBlock ? "playMode.recoveryBlocked" : "playx.unknown.body"))
                    // U05-03: what the original receipt says; checking again re-reads it, never resubmits.
                    if let state = model.submitRecovery { PlaySubmitRecoveryRow(state: state) }
                    Button("playx.reconcile") { Task { await model.load() } }.accessibilityIdentifier("playx.reconcile")
                    if model.canRetryExactBranch {
                        Button("playx.retryExact") { Task { await model.retryExactBranchAfterReadback() } }
                            .accessibilityIdentifier("playx.retryExact")
                    }
                }
            }
            if model.hasCurrentMediaSnapshot, model.available {
                // U05-04: download for this run; the page states what is (not) usable offline.
                Section {
                    NavigationLink {
                        PlayOfflinePackHost(make: {
                            PlayOfflinePackEnvironment.store().flatMap {
                                model.makeOfflinePackModel(store: $0, fetch: PlayOfflinePackEnvironment.fetch(approvedHosts: approvedArtworkHosts))
                            }
                        })
                    } label: {
                        Label { Text("pack.entry", tableName: "PlayRecovery") } icon: { Image(systemName: "arrow.down.circle") }
                    }.accessibilityIdentifier("playRecovery.pack.open")
                }
            }
            if let ambientModel { PlayAmbientView(model: ambientModel) }
            if model.snapshot != nil {
                if let snapshot = model.snapshot, model.hasCurrentMediaSnapshot {
                    Section("journey.record.title") {
                        narrativeLink(.casebook); narrativeLink(.backpack)
                        ForEach(snapshot.result.chapters) { chapter in
                            let nodes = snapshot.visibleNodes.filter { $0.chapterID == chapter.id }
                            if !nodes.isEmpty, nodes.allSatisfy({ snapshot.isDone($0) && !snapshot.isLocked($0) }) {
                                narrativeLink(.stage(chapterID: chapter.id), subtitle: chapter.name)
                            }
                        }
                        if snapshot.availability == .completed { narrativeLink(.ending) }
                    }
                }
                if let snapshot = model.snapshot, model.hasCurrentMediaSnapshot {
                    Section("chapterStory.title") {
                        ForEach(snapshot.result.chapters) { chapter in
                            if let node = snapshot.visibleNodes.first(where: { $0.chapterID == chapter.id && !snapshot.isLocked($0) }),
                               model.chapterStories[chapter.id] != nil {
                                NavigationLink {
                                    ChapterStoryView(chapterID: chapter.id, nodeID: node.id, model: model,
                                        advancedModel: advancedModel, journeyModel: journeyModel, deviceModel: deviceModel, mediaScope: mediaScope,
                                        makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval, nodeDestination: { AnyView(nodeDestination($0)) })
                                } label: {
                                    if let title = chapter.name { Label { Text(verbatim: title) } icon: { Image(systemName: "book") } }
                                    else { Label("chapterStory.title", systemImage: "book") }
                                }.accessibilityIdentifier("chapterStory.open.\(chapter.id)")
                            }
                        }
                    }
                }
                Section {
                    ForEach((model.snapshot?.visibleNodes ?? []).filter { chapterFilter == nil || $0.chapterID == chapterFilter }) { node in
                        Button { selectedNode = node.id } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                PlayNodeTitle(name: node.name).font(.headline)
                                Text(LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node).rawValue))
                                    .foregroundStyle(.secondary)
                                if let snapshot = model.snapshot { PlayTaskStatusBadge(node: node, snapshot: snapshot) }
                                if let reason = model.snapshot?.lockReason(node) { Text(verbatim: reason).font(.footnote) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }.accessibilityIdentifier("playx.node.\(node.id)")
                    }
                } header: {
                    HStack {
                        Text("playx.nodes")
                        if let chapterFilter, let chapter = model.snapshot?.result.chapters.first(where: { $0.id == chapterFilter }) {
                            Text(verbatim: "· " + (chapter.name ?? "")).lineLimit(1)
                            Spacer()
                            Button("mpd.chapters.all") { withAnimation(CYMotion.standard) { self.chapterFilter = nil } }
                                .font(CYTypography.meta).textCase(nil)
                                .accessibilityIdentifier("play.chapterPick.clear")
                        }
                    }
                }
                Section("playx.results") {
                    if model.snapshot?.availability == .completed, model.hasCurrentMediaSnapshot {
                        Button { finishScreen = true } label: { Label("medalScreen.open", systemImage: "rosette") }
                            .accessibilityIdentifier("medalScreen.open")
                    }
                    Button("playx.results.load") { Task { await model.loadEndingAndLeaderboard() } }.accessibilityIdentifier("playx.results.load")
                    NavigationLink("playx.stopwatch") { PlayStopwatchView() }
                    if let topicID = model.snapshot?.result.topicID, let factory = summaryModel, let summary = factory(topicID),
                       let source = PlayOperatingSummarySource(runtime: model, summary: summary) {
                        NavigationLink("playx.os.title") {
                            PlayOperatingSummaryView(model: summary,
                                sourceIsCurrent: { source.accepts(model, summary: summary, currentSummary: { factory(topicID) }) })
                        }.accessibilityIdentifier("playx.os.open")
                    }
                    if PrefabPreviewState.isPrefabTopic(name: model.snapshot?.result.topicName), let prefabModel {
                        NavigationLink("playx.prefab.title") { PlayPrefabRuntimeView(model: prefabModel) }
                    }
                    if let playerModel { NavigationLink("playx.player.title") { PlayPlayerSessionView(model: playerModel, deviceModel: deviceModel) } }
                    if case .activity(let activityID) = model.scope, model.hasCurrentMediaSnapshot {
                        NavigationLink("共同方案") {
                            PlaySharedPlanLifecycleEntry(activityID: activityID,
                                sourceCurrent: { model.available && model.hasCurrentMediaSnapshot })
                        }
                    }
                    if let circleModel { NavigationLink("playx.circle.title") { PlayCircleView(model: circleModel) } }
                    if let card = finishRouteModel?.card { PlayFinishRouteCardView(card: card, destination: finishRouteDestination) }
                    if mpParity.journeyReport != nil, let snapshot = model.snapshot, snapshot.availability == .completed {
                        // Mini-program report/settle open at the end of a run; hidden until the journey binding exists.
                        NavigationLink { MPParityDestination(route: .journeyReport(journeyRunScope(snapshot.result.topicID, snapshot.result.topicName))) } label: {
                            Label("mp.entry.journeyReport", systemImage: "flag.checkered")
                        }
                        .accessibilityIdentifier("journeyReport.entry")
                    }
                    if let themeRecordsModel, themeRecordsModel.isAvailable {
                        NavigationLink("playx.themeRecords.title") { PlayThemeRecordsView(model: themeRecordsModel, title: model.snapshot?.result.topicName) }
                            .accessibilityIdentifier("playx.themeRecords.open")
                    }
                    if let backpackModel {
                        NavigationLink("playx.backpack.title") { PlayThemeBackpackView(model: backpackModel) }
                            .accessibilityIdentifier("playx.backpack.open")
                    }
                }
                if let reward = model.reward { PlayRewardSection(reward: reward, collectionDestination: rewardCollectionDestination) }
                if let ending = model.ending {
                    Section("playx.ending") {
                        if ending.hasStory {
                            if !ending.opener.isEmpty { Text(verbatim: ending.opener) }
                            ForEach(Array(ending.fragments.enumerated()), id: \.offset) { _, fragment in
                                VStack(alignment: .leading) { Text(verbatim: fragment.name).font(.headline); if let text = fragment.text, !text.isEmpty { Text(verbatim: text) } }
                            }
                        } else { Text("playx.ending.empty").accessibilityIdentifier("playx.ending.empty") }
                    }
                }
                if let board = model.leaderboard {
                    Section("playx.leaderboard") {
                        ForEach(board.entries) { row in
                            LabeledContent { Text(verbatim: String(row.score)).monospacedDigit() } label: {
                                HStack(spacing: 10) {
                                    Text(verbatim: row.rank.map(String.init) ?? "—").font(.headline.monospacedDigit()).frame(minWidth: 28, alignment: .leading)
                                    if let name = row.name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.player.unnamed") }
                                }
                            }
                        }
                        LabeledContent("playx.leaderboard.me") { Text(verbatim: "\(board.me.rank.map(String.init) ?? "—") · \(board.me.score)") }
                    }
                }
                if case .activity = model.scope { PlayLeadSection(model: model) }
            }
        }
        .refreshable { if model.available && model.phase != .submitting { await model.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load() } } label: { Label("playx.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.phase == .submitting || !model.available).accessibilityIdentifier("playx.refresh")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // 游玩工具: 切换章节 when the route has more than one chapter (also after the run is done), 紧急求助 always.
                PlayToolsMenu(showsChapters: (model.snapshot?.result.chapters.count ?? 0) > 1, showsEmergency: model.snapshot != nil,
                              openChapters: { showChapterPicker = true }, openEmergency: { showEmergencyHelp = true })
            }
        }
        .accessibilityIdentifier("playx.overview")
    }
    /// Map-first play screen: static map ground, glass clock / route map / end on top, the one primary
    /// (pause / resume) above the panel, and the unchanged task list in a three-detent panel.
    private var orientationContent: some View {
        CYMapScaffold(detent: .medium, map: { CYMapPlaceholder() }, controls: { runHeader }, floating: { runPrimary },
                      panel: { orientationList })
    }
    /// Elapsed clock plus route map and end as glass controls (max three with the toolbar refresh).
    @ViewBuilder private var runHeader: some View {
        if model.snapshot != nil {
            let seconds = model.clock.elapsedSeconds
            HStack(spacing: CYSpacing.sm) {
                CYGlassCapsule {
                    HStack(spacing: CYSpacing.sm) {
                        Image(systemName: "timer").accessibilityHidden(true)
                        Text(verbatim: String(format: "%02ld:%02ld", seconds / 60, seconds % 60))
                            .font(CYTypography.dataXL).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                            .accessibilityIdentifier("playx.run.clock")
                    }.foregroundStyle(.white)
                }
                Spacer(minLength: CYSpacing.sm)
                if !model.unresolved, model.interactionContext != nil, let snapshot = model.snapshot,
                   PlayRouteMapPresentation(snapshot: snapshot) != nil {
                    CYGlassButton(systemImage: "map", label: "playRoute.open") { showRouteMap = true }
                        .accessibilityIdentifier("playRoute.open")
                }
                if model.clock.phase != .ended {
                    CYGlassButton(systemImage: "flag.checkered", label: "playx.run.end") { confirmEnd = true }
                        .disabled(!model.canManageRun)
                        .accessibilityIdentifier("playx.run.end")
                }
            }
        }
    }
    @ViewBuilder private var runPrimary: some View {
        if model.snapshot != nil {
            let seconds = model.clock.elapsedSeconds
            Group {
                if model.clock.phase == .running {
                    Button { Task { await model.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) } } label: {
                        Label("playx.run.pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cyPrimary).disabled(!model.canManageRun)
                    .accessibilityIdentifier("playx.run.pause")
                } else if model.clock.phase != .ended {
                    Button { model.startRun(now: ProcessInfo.processInfo.systemUptime) } label: {
                        Label(seconds == 0 ? "playx.run.start" : "playx.run.resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cyPrimary).disabled(!model.canManageRun)
                    .accessibilityIdentifier("playx.run.resume")
                }
            }
            .controlSize(.large).frame(maxWidth: 280).padding(.horizontal, CYSpacing.lg)
        }
    }
    @ViewBuilder private func freeStoreDestination(_ id: Int) -> some View {
        if model.gameplayMode == .freeExploration {
            FreeExplorationStoreView(nodeID: id, model: model, device: deviceModel?(id), shopNPC: shopNPCModel?(id), mediaScope: mediaScope,
                makeExternalMaps: makeExternalMaps, storyDestination: { node in
                    guard model.hasCurrentMediaSnapshot, let chapterID = node.chapterID,
                          model.chapterStories[chapterID] != nil else { return nil }
                    return AnyView(ChapterStoryView(chapterID: chapterID, nodeID: node.id, model: model,
                        mediaScope: mediaScope, makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts,
                        nodeDestination: { AnyView(freeStoreDestination($0)) }))
                }, storeDayModel: storeDayModel)
        } else { Text("playMode.unavailable") }
    }
    @ViewBuilder private func narrativeLink(_ query: JourneyNarrativeQuery, subtitle: String? = nil) -> some View {
        if let narrative = narrativeModel?(query) {
            NavigationLink {
                JourneyNarrativeView(model: narrative, imageReader: narrativeImageReader, makeAudio: makeAudio, mediaScope: mediaScope)
            } label: {
                VStack(alignment: .leading) { Text(LocalizedStringKey(query.titleKey)); if let subtitle { Text(verbatim: subtitle).font(.caption) } }
            }.accessibilityIdentifier("journey.record.open." + query.key)
        }
    }
    @ViewBuilder private func nodeDestination(_ id: Int) -> some View {
        if model.gameplayMode == .cityOrientation {
        let configuration = try? PlayStillnessConfiguration(raw: model.extras[id]?.sensorConfig ?? .null)
        PlayExperienceNodeView(nodeID: id, model: model, device: deviceModel?(id), advanced: advancedModel.flatMap { $0(id) },
            stillness: configuration.flatMap { configuration in motionModel.flatMap { $0(id, configuration) } },
            preference: preferenceModel.flatMap { $0(id) }, journey: journeyModel.flatMap { $0(id) }, narrative: narrativeModel?(.questions(nodeID: id)), shopNPC: shopNPCModel?(id),
            mediaScope: mediaScope, makeAudio: makeAudio, makeExternalMaps: makeExternalMaps, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
            openNode: { selectedNode = $0 })
        } else { Text("playMode.unavailable") }
    }
    @ViewBuilder private var finishMedalScreen: some View {
        let snapshot = model.snapshot
        let nodes = snapshot?.visibleNodes ?? []
        let done = snapshot.map { snapshot in nodes.filter { snapshot.isDone($0) }.count }
        let medals = model.reward.map { PlayRewardSection.medals(in: $0, locale: locale) } ?? []
        let topic = snapshot?.result.topicName.flatMap { $0.isEmpty ? nil : $0 }
        // Mini-program v13 medal screen: 主题通关 over `{topic} · 获得 N 枚勋章`; only stats it can read
        // (用时 h:mm:ss, 节点 done/total) — a missing one is left out rather than shown as a guess.
        let title = appLocalized("medalScreen.themeComplete", locale: locale)
        let subtitle = (topic.map { $0 + " · " } ?? "") + appLocalized("medalScreen.earned \(max(medals.count, 1))", locale: locale)
        let stats = [
            CYStoryStat(key: "medalScreen.stat.time", value: Self.finishClockText(model.clock.elapsedSeconds), systemImage: "stopwatch"),
            CYStoryStat(key: "medalScreen.stat.nodes", value: done.flatMap { nodes.isEmpty ? nil : "\($0)/\(nodes.count)" }, systemImage: "book"),
        ].filter { $0.value != nil }
        CYMedalScreen(items: medals, title: title, subtitle: subtitle, stats: stats,
                      shareText: appLocalized("medalScreen.shareText \(topic ?? title)", locale: locale),
                      secondaryTitle: "medalScreen.records",
                      onClose: { finishScreen = false })
    }
    private static func finishClockText(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
    private func projectAmbient() {
        guard let result = model.snapshot?.result else { return }
        ambientModel?.project(eggs: result.eggs, topicID: result.topicID)
    }
    private static var milliseconds: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}

@MainActor private struct PlayExperienceNodeView: View {
    let nodeID: Int
    @Bindable var model: PlayExperienceCoordinator
    let device: PlayDeviceCaptureCoordinator?
    let advanced: PlayAdvancedCoordinator?
    let stillness: PlayStillnessCoordinator?
    let preference: PlayPreferenceCoordinator?
    let journey: JourneyCheckCoordinator?
    let narrative: JourneyNarrativeCoordinator?
    let shopNPC: ShopNPCNodeHost?
    let mediaScope: UUID
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    /// Opens another stop from the outcome card ("Next stop"); nil hides that shortcut.
    var openNode: ((Int) -> Void)? = nil
    @State private var answer = ""
    /// Shared full-screen verdict (mini-program play-verdict) after this stop's own submission settles.
    @State private var verdict: CYPlayVerdict?
    @State private var review: PlayCompletionReview?
    @State private var showReview = false
    @State private var showHint = false
    @State private var hintContext: PlayInteractionContext?
    @State private var hintLevel: Int?
    @State private var localIssue: PlayExperienceError?
    /// UG-05…UG-09 ladder for this stop. When the server enables it, the legacy hint and reveal entries step aside.
    @State private var help: PlayHelpLadderModel?
    @State private var showHelpPanel = false
    @State private var skippedHere = false
    private var node: PlayNode? { model.snapshot?.visibleNodes.first { $0.id == nodeID } }
    private var helpEnabled: Bool { help?.enabled == true && help?.identity.nodeID == nodeID }
    var body: some View {
        let context = model.interactionContext
        List {
            PlayTaskOutcomeSection(model: model, nodeID: nodeID, openNode: openNode)
            if let state = model.submitRecovery, state.nodeID == nodeID {
                Section { PlaySubmitRecoveryRow(state: state, onCheck: model.unresolved ? { Task { await model.load() } } : nil) }
            }
            if let failure = model.arrivalFailure, failure.nodeID == nodeID, node.map({ model.snapshot?.isDone($0) != true }) ?? false {
                PlayArrivalFailureSection(failure: failure,
                    onRelocate: device.map { device -> () -> Void in
                        // A new reading is a new input with a new action id; the settled one is never replayed.
                        { _ = Task { await device.capture(.location, interaction: .init(context: context, current: { model.interactionContext })) } }
                    },
                    onRefresh: { Task { await model.load() } },
                    onOpenNode: openNode)
            }
            if let reading = model.arrivalReading, model.reward?["nodeId"].tolerantInteger == nodeID {
                PlayArrivalReadingSection(reading: reading)
            }
            if let node {
                if let journey { PlayJourneyCheckView(model: journey, nodeDone: node.done == true) }
                if let narrative, model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false {
                    NavigationLink("journey.record.questions") {
                        JourneyNarrativeView(model: narrative, onChanged: { await model.load() })
                    }.accessibilityIdentifier("journey.record.open.questions.\(nodeID)")
                }
                Section {
                    PlayNodeTitle(name: node.name).font(.title2.bold())
                    if let body = node.storyText ?? node.description { Text(verbatim: body) }
                    if let instructions = node.ruleInstructions { Text(verbatim: instructions) }
                    if let question = node.question { Text(verbatim: question).font(.headline) }
                    // Mini-program question card: the question image sits under the question.
                    if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false, let image = node.questionImage, !image.isEmpty {
                        PlayKitArtwork(source: image, approvedHosts: approvedArtworkHosts)
                            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                            .accessibilityIdentifier("playx.question.image")
                    }
                    if node.validationMethod == 2, let requirement = node.photoRequirement, !requirement.isEmpty {
                        Text(verbatim: requirement).font(.headline).accessibilityIdentifier("playx.photo.requirement")
                    }
                    if node.validationMethod == 4 {
                        Text("playx.scan.prompt").font(.headline).accessibilityIdentifier("playx.scan.prompt")
                    }
                    PlatformChapterAudioHost(selection: PlatformChapterAudioSelection.resolve(snapshot: model.snapshot, nodeID: nodeID, extras: model.extras, currentRead: model.hasCurrentMediaSnapshot), scope: mediaScope, makeModel: makeAudio)
                    if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false {
                        if let audio = node.questionAudio, !audio.isEmpty { PlatformAudioHost(rawURL: audio, scope: mediaScope, makeModel: makeAudio) }
                        PlatformExternalMapHost(destination: .init(name: node.name ?? "#\(node.id)", address: node.address, latitude: node.latitude, longitude: node.longitude), scope: mediaScope, makeModel: makeExternalMaps)
                    }
                    if let snapshot = model.snapshot { PlayTaskStatusBadge(node: node, snapshot: snapshot) }
                }
                if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false, node.npc != nil, let shopNPC {
                    Section {
                        ShopNPCNodeEntrance(name: shopNPC.name, makeCoordinator: shopNPC.makeCoordinator, greeting: shopNPC.greeting,
                            makeScriptedGuide: { scope in ShopNPCScriptedGuideSource(runtime: model, nodeID: nodeID, conversation: scope) })
                            .id(shopNPC.identity)
                    }
                }
                if model.snapshot?.result.mode == 2 {
                    FreeExplorationVisitSteps(node: node)
                }
                if PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node) == .answer {
                    Section("playx.answer") {
                        if let options = node.options, node.validationMethod == 3 {
                            // Keyed option cards (A / B / C) as in the mini-program; the picked one is filled.
                            VStack(spacing: CYSpacing.sm) {
                                ForEach(options.keys.sorted(), id: \.self) { key in
                                    let on = answer == key
                                    Button { answer = key } label: {
                                        HStack(spacing: CYSpacing.md) {
                                            Text(verbatim: key).font(CYTypography.cardTitle).foregroundStyle(on ? CYColor.bgSurface : Color.secondary)
                                            Text(verbatim: options[key] ?? key).font(CYTypography.body).foregroundStyle(on ? CYColor.bgSurface : Color.primary)
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 52)
                                        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(on ? Color.primary : CYColor.bgSurfaceSubtle))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                    .accessibilityIdentifier("playx.answer.option." + key)
                                }
                            }
                            .accessibilityIdentifier("playx.answer.options")
                        } else { TextField("playx.answer.placeholder", text: $answer, axis: .vertical).accessibilityIdentifier("playx.answer.field") }
                        Button("playx.review") { prepare(.answer(answer), context: context) }.disabled(!model.canWrite || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("playx.answer.review")
                    }
                }
                if helpEnabled || skippedHere {
                    Section("playHelp.title") {
                        if skippedHere {
                            Label("playHelp.skipped", systemImage: "forward.end").foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("playHelp.skipped")
                        } else {
                            Button("playHelp.open") { showHelpPanel = true }
                                .disabled(!model.hasCurrentMediaSnapshot)
                                .accessibilityIdentifier("playHelp.open")
                        }
                    }
                }
                if !helpEnabled, !skippedHere, let extra = model.extras[nodeID], extra.hintLocked == true || extra.puzzleScoring == true {
                    Section("playx.hints") {
                        if let cost = extra.hintCost { LabeledContent("playx.hints.cost") { Text(verbatim: String(cost)) } }
                        ForEach(Array(extra.usedHints.enumerated()), id: \.offset) { _, text in Text(verbatim: text).font(CYTypography.meta).foregroundStyle(.secondary) }
                        if let cap = extra.puzzleScoreCap {
                            Text("playx.hints.capLine \(cap)").font(CYTypography.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                                .accessibilityIdentifier("playx.hints.cap")
                        }
                        Button {
                            hintContext = context
                            hintLevel = extra.puzzleScoring == true ? min(2, (extra.puzzleHintLevel ?? 0) + 1) : nil
                            showHint = true
                        } label: {
                            if extra.puzzleScoring == true { Text("playx.hints.requestLevel \(min(2, (extra.puzzleHintLevel ?? 0) + 1))") }
                            else { Text("playx.hints.request") }
                        }
                            .disabled(!model.canWrite || (extra.puzzleScoring != true && extra.hintCost == nil))
                            .accessibilityIdentifier("playx.hints.request")
                    }
                }
                if !helpEnabled, let hint = model.hint { Section("playx.hints") { ForEach(Array(hint.hints.enumerated()), id: \.offset) { _, text in Text(verbatim: text) } } }
                if let preference, node.validationMethod == 6 {
                    NavigationLink("playx.preference.title") { PlayPreferenceView(model: preference) { Task { await model.load() } } }
                        .accessibilityIdentifier("playx.preference.open")
                }
                if let stillness, node.sensorType == "still" {
                    NavigationLink("playx.stillness") {
                        PlayInteractionBoundContent(context: model.interactionContext) { issuedContext in
                            PlayStillnessStreamView(model: stillness) { prepare(.sensor(type: "still", payload: $0), context: issuedContext) }
                        }
                    }
                }
                if let advanced, node.hasAdvancedPrerequisite {
                    NavigationLink("playx.advanced") {
                        PlayInteractionBoundContent(context: model.interactionContext) { advancedContext in
                            PlayAdvancedView(model: advanced, device: device, mediaScope: mediaScope, makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval) { state in
                                try? model.acceptAdvanced(state, context: advancedContext)
                            }
                        }
                    }
                }
                if let device { PlayDeviceTaskSection(model: device, task: PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node),
                    photoFilter: node.sensorType == "filter_shot" ? PlayPhotoFilter(rawValue: model.extras[nodeID]?.sensorConfig["filterStyle"].text ?? "") : nil,
                    unsupportedPhotoSubtype: node.validationMethod == 2 && node.sensorType?.isEmpty == false && (node.sensorType != "filter_shot" || PlayPhotoFilter(rawValue: model.extras[nodeID]?.sensorConfig["filterStyle"].text ?? "") == nil), interaction: .init(context: context, current: { model.interactionContext }), onEvidence: { prepare($0, context: $1) }) }
                else if PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node) != .answer { Text("playx.device.disabled") }
            } else { Text("playx.node.unavailable") }
            if let localIssue { PlayExperienceIssueView(issue: localIssue) }
        }
        .privacySensitive().navigationTitle("playx.task.title")
        .onChange(of: outcomeState) { old, new in
            // Only this screen's own submission produces a verdict; a later read never replays one.
            guard old == .submitting else { return }
            if new == .completed { verdict = .init(kind: .win) }
            else if new == .pending || new == .failed, case .rejected(_, let message)? = model.issue {
                verdict = .init(kind: .fail, text: message)
            }
        }
        .cyPlayVerdict($verdict)
        .modifier(JourneyCheckReviewPresentation(model: journey))
        // The optional check initially renders no rows, so its probe belongs to this stable host.
        .task(id: [model.identity, node.map { String($0.id) }, (model.snapshot?.route?.sessionID).map(String.init), (model.snapshot?.route?.version).map(String.init)]) {
            if let node {
                await loadHelp(node: node)
                await journey?.probe(nodeDone: node.done == true)
                guard !Task.isCancelled, self.node?.id == node.id, model.hasCurrentMediaSnapshot else { journey?.roleContent.close(); return }
                await journey?.roleContent.load(expectedRunID: model.snapshot?.route?.sessionID, minimumStateVersion: model.snapshot?.route?.version)
            } else { journey?.roleContent.close() }
        }
        .onChange(of: node?.done) { _, _ in
            if let node { journey?.updateNodeDone(node.done == true) }
        }
        .confirmationDialog("playx.review", isPresented: $showReview, titleVisibility: .visible) {
            Button("playx.submit") {
                guard let review else { return }
                self.review = nil // Consume before adaptive dismissal, which otherwise means cancellation.
                Task { await model.submit(review) }
            }.accessibilityIdentifier("playx.confirm")
            Button("playx.cancel", role: .cancel) { model.cancelReview(); review = nil }
        } message: { Text("playx.review.detail") }
        .onChange(of: showReview) { _, visible in
            // A popover's outside-tap dismissal has no visible Cancel button.
            if !visible, review != nil { model.cancelReview(); review = nil }
        }
        .confirmationDialog("playx.hints.request", isPresented: $showHint, titleVisibility: .visible) {
            Button("playx.hints.confirm") {
                let context = hintContext, level = hintLevel
                hintContext = nil
                Task { await model.requestHint(nodeID: nodeID, level: level, context: context) }
            }
        } message: { Text("playx.hints.consequence") }
        .overlay {
            if showHelpPanel, let help, helpEnabled {
                PlayHelpLadderPanel(model: help, approvedArtworkHosts: approvedArtworkHosts, close: { showHelpPanel = false })
            }
        }
        .onChange(of: help?.skipped) { _, skipped in
            // The server settled the skip (0 points, assisted). No success verdict; progress is re-read by the model.
            if skipped == true { skippedHere = true; showHelpPanel = false }
        }
        .onDisappear { journey?.roleContent.close(); device?.cancel(); model.cancelReview(); review = nil; hintContext = nil; answer = ""; showHelpPanel = false }
    }
    /// One read when an unfinished stop opens. A failed read keeps the legacy hint entries.
    private func loadHelp(node: PlayNode) async {
        guard node.done != true, model.snapshot?.isLocked(node) == false, let client = model.helpClient(nodeID: node.id) else {
            if help?.identity.nodeID != node.id || node.done == true { help = nil; showHelpPanel = false }
            return
        }
        if let help, help.identity == client.identity, help.loaded { return }
        let next = PlayHelpLadderModel(client: client, store: PlayHelpDefaultsRequestStore.shared)
        help = next
        await next.load()
    }
    private var outcomeState: PlayTaskOutcomePresentation.State {
        PlayTaskOutcomePresentation(snapshot: model.snapshot, nodeID: nodeID, phase: model.phase.rawValue,
                                    isCurrentRead: model.hasCurrentMediaSnapshot, unresolved: model.unresolved).state
    }
    private func stateRow(_ key: String, done: Bool) -> some View { Label(LocalizedStringKey(key), systemImage: done ? "checkmark.circle.fill" : "circle") }
    private func prepare(_ evidence: PlayCompletionEvidence, context: PlayInteractionContext?) {
        do { review = try model.review(nodeID: nodeID, evidence: evidence, context: context); showReview = true; localIssue = nil }
        catch { localIssue = error as? PlayExperienceError ?? .invalidAction }
    }
}

/// U04-03: the server's compatibility verdict before play. Unconfirmed (old/undeclared client) shows
/// nothing; a damaged declaration is "not confirmed", never "supported"; missing keys are listed as sent.
struct PlayCompatibilitySection: View {
    let compatibility: PlayContentCompatibility
    var body: some View {
        switch compatibility.verdict {
        case .supported: EmptyView()
        case .unconfirmed(let source):
            if source == "MALFORMED" || source == "DECLARED_MALFORMED" {
                Section {
                    Label { Text("playCompat.unconfirmed", tableName: "PlayFullStory") } icon: { Image(systemName: "questionmark.circle") }
                        .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playCompat.unconfirmed")
                }
            }
        case .unsupported(let missing):
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label { Text("playCompat.unsupported.title", tableName: "PlayFullStory").font(CYTypography.cardTitle) }
                        icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CYColor.warningText) }
                    Text("playCompat.unsupported.body", tableName: "PlayFullStory").font(CYTypography.body)
                        .foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if !missing.isEmpty {
                        DisclosureGroup {
                            ForEach(missing, id: \.key) { row in
                                Text(verbatim: row.key + " ≥ v" + String(row.minVersion)).font(CYTypography.meta).monospaced()
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                        } label: { Text("playCompat.unsupported.details", tableName: "PlayFullStory").font(CYTypography.caption) }
                        .accessibilityIdentifier("playCompat.missing")
                    }
                }.accessibilityIdentifier("playCompat.unsupported")
            }
        }
    }
}

struct PlayExperienceIssueView: View {
    let issue: PlayExperienceError
    var body: some View {
        VStack(alignment: .leading) {
            if case .rejected(let code, let message) = issue {
                Label("playx.rejected", systemImage: "exclamationmark.circle").font(.headline)
                Text(verbatim: message ?? String(code)).fixedSize(horizontal: false, vertical: true)
            } else { Text(LocalizedStringKey(issue == .disabled ? "playx.disabled" : issue == .staleSession ? "playx.session.changed" : issue == .unsupported ? "playx.unsupported" : "playx.error")) }
        }.foregroundStyle(.secondary).accessibilityIdentifier("playx.issue")
    }
}
@MainActor struct PlayRewardSection: View {
    let reward: PlayWireValue
    var collectionDestination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    @Environment(\.locale) private var locale
    var body: some View {
        Section("playx.reward") {
            // Mini-program finish-medals: the earned medals stack first, the ledger rows follow.
            let medals = Self.medals(in: reward, locale: locale)
            if !medals.isEmpty {
                CYMedalDeck(items: medals).padding(.vertical, CYSpacing.sm)
                    .listRowBackground(Color.clear)
            }
            if let xp = reward["xp"].tolerantInteger ?? reward["score"].tolerantInteger { LabeledContent("playx.reward.xp") { Text(verbatim: String(xp)) } }
            if let score = reward["puzzleScore"].tolerantInteger { LabeledContent("playx.reward.puzzle") { Text(verbatim: String(score)) } }
            if let medal = reward["medalName"].text { Text(verbatim: medal) }
            PlayRewardBadgeRows(targets: PlayRewardBadgeTarget.targets(in: reward), destination: collectionDestination)
                .id(PlayRewardBadgeTarget.targets(in: reward))
        }.accessibilityIdentifier("playx.reward")
    }
    /// Medals carried by the reward receipt: the topic medal name plus each new badge. Nothing is invented.
    static func medals(in reward: PlayWireValue, locale: Locale) -> [CYMedalItem] {
        var items: [CYMedalItem] = []
        if let medal = reward["medalName"].text, !medal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(.init(id: "topic-medal", name: medal, imageURL: reward["medalImg"].text ?? reward["medalImage"].text, systemImage: "rosette"))
        }
        for target in PlayRewardBadgeTarget.targets(in: reward) {
            items.append(.init(id: "badge-" + target.code, name: target.name ?? appLocalized("medalDeck.unnamed", locale: locale), systemImage: "seal.fill"))
        }
        return items
    }
}
@MainActor private struct PlayLeadSection: View {
    @Bindable var model: PlayExperienceCoordinator
    @State private var text = ""
    @State private var action: PlayLeadAction?
    @State private var review = false
    @State private var actionContext: PlayInteractionContext?
    var body: some View {
        let context = model.interactionContext
        Section("playx.lead.title") {
            Button("playx.lead.load") { Task { await model.loadLead(context: context) } }.accessibilityIdentifier("playx.lead.load")
            if let lead = model.lead {
                if !lead.exists { Text("playx.lead.notStarted") }
                if let broadcast = lead.broadcast { Text(verbatim: broadcast) }
                if let chapter = lead.chapterName { Text(verbatim: chapter) }
                if let arrived = lead.arrived, !lead.members.isEmpty { LabeledContent("playx.lead.arrived") { Text(verbatim: "\(arrived) / \(lead.members.count)") } }
                ForEach(lead.members) { member in
                    Label { if let name = member.name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.player.unnamed") } }
                        icon: { Image(systemName: member.arrived ? "checkmark.circle.fill" : "circle").foregroundStyle(member.arrived ? CYColor.successText : CYColor.textTertiary) }
                }
                if lead.exists && !lead.meArrived { actionButton(context: context, .arrive) }
                if lead.isLeader {
                    TextField("playx.lead.text", text: $text, axis: .vertical).accessibilityIdentifier("playx.lead.text")
                    if !lead.exists { actionButton(context: context, .start) }
                    else { actionButton(context: context, .broadcast); actionButton(context: context, .unlockChapter); actionButton(context: context, .settle) }
                }
                if model.leaderOutcomeUnknown { Text("playx.lead.unknown") }
                if model.leadReadFailed { PlayRuntimePhaseText(phase: "failed") }
            }
        }
        .modifier(PlayLeadProgressPollingModifier(model: model, context: context))
        .confirmationDialog("playx.review", isPresented: $review, titleVisibility: .visible) {
            Button("playx.submit") {
                if let action {
                    let context = actionContext, message = action == .broadcast ? text : nil
                    actionContext = nil
                    Task { await model.performLead(action, text: message, context: context) }
                }
            }
        } message: { Text(LocalizedStringKey(action == .settle ? "playx.lead.settle.consequence" : "playx.lead.review")) }
    }
    private func actionButton(context: PlayInteractionContext?, _ value: PlayLeadAction) -> some View {
        Button(LocalizedStringKey("playx.lead." + value.rawValue)) { action = value; actionContext = context; review = true }
            .disabled(!model.canWrite || model.leaderOutcomeUnknown || (value == .unlockChapter && model.lead?.allArrived != true) || (value == .broadcast && text.isEmpty))
            .accessibilityIdentifier("playx.lead." + value.rawValue)
    }
}

/// A stop's name, or a neutral placeholder; never the raw id.
struct PlayNodeTitle: View {
    let name: String?
    var body: some View {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(verbatim: name) }
        else { Text("playx.node.untitled") }
    }
}

struct PlayRuntimePhaseText: View {
    let phase: String
    var body: some View { Text(LocalizedStringKey("playx.phase." + phase)) }
}

/// Freeze authority when this interaction is mounted. A redraw must not bind
/// an old child operation to a newly loaded mode or request generation.
@MainActor struct PlayInteractionBoundContent<Content: View>: View {
    @State private var context: PlayInteractionContext?
    private let currentContext: PlayInteractionContext?
    private let content: (PlayInteractionContext?) -> Content
    init(context: PlayInteractionContext?, @ViewBuilder content: @escaping (PlayInteractionContext?) -> Content) {
        _context = State(initialValue: context); currentContext = context; self.content = content
    }
    @ViewBuilder var body: some View {
        if context != nil, context == currentContext { content(context) }
        else { Text("playMode.unavailable") }
    }
}

/// Session AND coordinator identity delimit one visible runtime. Retaining the previous
/// coordinator prevents pointer reuse from making a replacement look like the old owner.
struct PlayExperiencePresentationKey: Hashable {
    let coordinator: ObjectIdentifier
    let session: String?
    @MainActor init(model: PlayExperienceCoordinator) { coordinator = ObjectIdentifier(model); session = model.identity }
}
@MainActor final class PlayExperiencePresentationMount {
    private var model: PlayExperienceCoordinator?
    private var session: String?
    func enter(_ next: PlayExperienceCoordinator) -> Bool {
        guard model !== next || session != next.identity else { return false }
        model = next; session = next.identity; return true
    }
}
