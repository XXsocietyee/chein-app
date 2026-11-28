import SwiftUI
import MapKit
import CoreLocation

/// Integration entry for migrated runtime. Factories are scope-specific, optional, and
/// never create provider/network permissions as a side effect of opening the screen.
/// PLAY-r11-1: restart key for the theme music task.
struct PlayThemeMusicKey: Equatable {
    let url: String?
    let enabled: Bool
}

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
    var teamBackpackModel: PlayTeamBackpackCoordinator? = nil
    var entryCode: PlayEntryCodeContext? = nil
    /// W20 city business game on the real CITY read (`AppSession.playCityGame`). Nil (no CITY lease or no board) hides it.
    var cityGameModel: CityGameCoordinator? = nil
    var prefabModel: PlayPrefabRuntimeCoordinator? = nil
    var journeyModel: ((Int) -> JourneyCheckCoordinator?)? = nil
    var ambientModel: JourneyAmbientCoordinator? = nil
    var narrativeModel: ((JourneyNarrativeQuery) -> JourneyNarrativeCoordinator?)? = nil
    var narrativeImageReader: (any RetainedPublicImageReading)? = nil
    var shopNPCModel: ((Int) -> ShopNPCNodeHost?)? = nil
    var invalidateShopNPC: (() -> Void)? = nil
    var storeDayModel: ((Int) -> PlayStoreDayCoordinator?)? = nil
    /// Team run only: the shared hint pool for a stop (contract §4). Nil outside a team run.
    var teamPoolModel: ((Int) -> TeamPoolHintModel?)? = nil
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
    /// 提示 on the play HUD (401:4731): the stop opens with its hint ladder already up. Cleared once it is used.
    @State private var hintNode: Int?
    /// 背包 on the play HUD: the theme (or team) backpack pushed over the play map.
    @State private var showBackpack = false
    /// PLAY-1: MP 章节结算 half sheet (journey/stage-end) when a chapter's last place is done; 底部 = 继续.
    @State private var stageSettlement: PlayStageSettlementTarget?
    @State private var settledChapters: Set<Int>?
    @State private var showRouteMap = false
    @State private var confirmEnd = false
    /// fix/1128c: the play guide (游玩提示) sheet and its journal for this visit.
    @State private var guideShown = false
    @State private var guideJournal = AIGuideJournal()
    @State private var presentedMode: PlayGameplayMode?
    @State private var presentationMount = PlayExperiencePresentationMount()
    /// Run-complete medal screen (mini-program medal-screen); shown once per session when the run completes.
    @State private var finishScreen = false
    /// U08-01: the finish-screen result word comes from the server battle report, not local completion.
    @State private var finishReport: (any JourneyReportBinding)?
    @State private var finishShownFor: String?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    /// 切换章节: nil shows every chapter's places.
    @State private var chapterFilter: Int?
    @State private var showChapterPicker = false
    @State private var showEmergencyHelp = false
    /// PLAY-6a: MP 游玩工具 preferences sheet (pages/play/index.wxml 游玩工具).
    @State private var showPlayTools = false
    /// MP `playContact` (联系主办 / 联系商家) for the 游玩工具 row; nil hides it.
    @State private var playContact: PlayContact?
    @AppStorage(PlatformBGMPreference.storageKey) private var playBGMOn = PlatformBGMPreference.defaultValue
    @StateObject private var musicLifetime = PlayBackgroundMusicLifetime()
    @AppStorage(PlatformNarrationAutoplayPreference.storageKey) private var playNarrationOn = PlatformNarrationAutoplayPreference.defaultValue
    @AppStorage(PlayReducedMotionPreference.storageKey) private var playReducedMotion = false
    @State private var titleCardTopic: Int?
    /// Cast for this run. Nil until a nodes read carries cast. Capabilities stay empty.
    @State private var castModel: CastCoordinator?
    @State private var castPlaybillSeen = false
    @State private var castCover = false
    @State private var showingCastRoster = false
    @State private var runTeamPool: TeamPoolHintModel?
    /// Native r2 city orientation (`NativeR2Flags.cityOrientation`): foreground position, the run sheet,
    /// teams mirrored from `TeamTrailSection`, the punch sheet and the end dialog.
    @StateObject private var cityLocation = CityOrientationLocationObserver()
    @State private var cityRunSheet = false
    @State private var cityTeams: [TeamTrailTeam] = []
    @State private var cityPunchNode: CityOrientationPunchTarget?
    /// P-056: the stop whose hint ladder is open over the run map.
    @State private var cityHintNode: CityOrientationHintTarget?
    @State private var cityEndDialog = false
    /// Native r2 route page: the chapter whose reader is pushed (Continue or a chapter row).
    @State private var nr2ReaderChapter: Int?
    @Environment(\.playThemePresentationReader) private var themeReader
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mpParity) private var mpParity
    @Environment(\.externalGameSession) private var externalGameSession
    private func chapterTitle(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func journeyRunScope(_ topicID: Int?, _ topicName: String?) -> JourneyRunScope {
        var scope = JourneyRunScope(topicID: topicID.map(String.init), topicName: topicName)
        if case .activity(let id) = model.scope { scope.activityID = String(id) }
        // Contract §5 item 17: a team run carries its play_team id, which opens the in-team (队内) board on report/settle.
        scope.teamID = model.snapshot?.result.teamID.map(String.init)
        return scope
    }
    /// Split from body so the type checker handles the modifier chain in parts.
    private var navigationLayer: some View {
        Group {
            if model.gameplayMode != .freeExploration, let blocked = PlayEmptyKind.blocking(model.snapshot?.availability) {
                PlayEmptyStateCard(kind: blocked, topicID: model.snapshot?.result.topicID)
            } else if model.gameplayMode == .freeExploration || (model.snapshot == nil && presentedMode == .freeExploration) {
                if NativeR2Flags.freeExplore && NativeR2Flags.freeExploreMapHome {
                    NativeFreeExploreMapView(model: model, storeDestination: { AnyView(freeStoreDestination($0)) },
                                             rewardCollectionDestination: rewardCollectionDestination,
                                             castConfig: castModel?.config, castEnding: model.castPayload,
                                             makeExternalMaps: makeExternalMaps, mediaScope: mediaScope,
                                             arrivalLocation: RuntimeNativeLocationProvider(enabled: true))
                } else {
                    FreeExplorationExperienceView(model: model, storeDestination: { AnyView(freeStoreDestination($0)) }, rewardCollectionDestination: rewardCollectionDestination, castConfig: castModel?.config, castEnding: model.castPayload)
                }
            } else if model.gameplayMode == .cityOrientation {
                if NativeR2Flags.cityOrientation { cityOrientationNative } else { orientationContent.cyThemeLook(themeFacts?.look) }
            } else if model.snapshot == nil {
                if model.phase == .loading {
                    // design-r2-play P10: the first frame says what is happening, not a bare skeleton. The words sit
                    // beside the skeleton leaf, which keeps its own identifier.
                    VStack(alignment: .leading, spacing: 0) {
                        Label("designR2Play.run.loading", systemImage: "hourglass")
                            .font(.headline).foregroundStyle(.secondary)
                            .padding([.horizontal, .top], CYSpacing.lg)
                        CYSkeleton().padding(CYSpacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .accessibilityIdentifier("playMode.loading")
                    }
                } else {
                    VStack(spacing: CYSpacing.md) {
                        if model.available, let pass = PlayEmptyKind.failure(model.issue) {
                            PlayEmptyStateCard(kind: pass, topicID: { if case .topic(let id) = model.scope { return id }; return nil }())
                        } else if model.available {
                            CYEmptyState(systemImage: "exclamationmark.triangle", "playx.error.title", actionTitle: "playx.refresh") {
                                if model.phase != .submitting { Task { await model.load() } }
                            }
                            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                            PlayBackToDetailButton()
                        } else {
                            CYEmptyState(systemImage: "gamecontroller", "playx.disabled.title")
                            Text("playx.disabled").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("playx.disabled")
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else { CYEmptyState(systemImage: "questionmark.circle", "playMode.unavailable") }
        }
        .environment(\.questifyCast, castModel?.context)
        .privacySensitive()
        // N-PLAY-DARK: system Light/Dark and the system accent (player domain) for every play mode.
        .cyDomainScreen(screenDomain)
        .cyPushedChrome(domain: screenDomain)
        .tint(Color.accentColor)
        .appNavigationTitle(key: model.gameplayMode == .freeExploration ? "playFree.title" : "playx.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedNode) { id in
            nodeDestination(id, opensHelp: hintNode == id)
                .cyPushedChrome(domain: screenDomain)
        }
        .onChange(of: selectedNode) { _, id in if id == nil { hintNode = nil } }
        .navigationDestination(item: $nr2ReaderChapter) { chapterID in
            nr2ReaderDestination(chapterID)
        }
        .navigationDestination(isPresented: $showBackpack) {
            backpackDestination.cyPushedChrome(domain: screenDomain)
        }
        .navigationDestination(isPresented: $showRouteMap) {
            PlayRouteMapView(
                model: model,
                nodeDestination: { AnyView(nodeDestination($0)) },
                actionRead: routeActionRead ?? heldRouteActionRead)
                .cyPushedChrome(domain: screenDomain)
        }
    }
    private func openGuide() { guideShown = true }
    /// The stop the play guide talks about: the current task stop of the live snapshot.
    private var guideStop: PlayNode? {
        guard let snapshot = model.snapshot, let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID else { return nil }
        return snapshot.visibleNodes.first(where: { $0.id == id })
    }
    private var guideContext: AIGuideContext {
        AIGuideContext(surface: .play, place: nil, stop: guideStop?.name, nodeKind: guideStop?.npc == nil ? nil : "shop",
                       weather: AIGuideWeatherMapping.weather(nil))
    }
    private var presentationLayer: some View {
        navigationLayer
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AIGuideToolbarButton(surface: .play, journal: guideJournal, open: openGuide)
            }
            if castModel?.config != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    CastRosterButton { showingCastRoster = true }
                }
            }
            // The play HUD carries the channel as its 队伍 circle; elsewhere it stays in the bar.
            if let scope = playChannelScope, hudStop == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    InGameChannelToolbarButton(
                        scope: scope,
                        titleKey: playChannelTitleKey,
                        accessibilityID: "ingame.channel.play.entry",
                        reloadTrigger: model.snapshot?.result.teamID ?? 0
                    )
                }
            }
        }
        .modifier(PlaySystemConfirm(
            isPresented: confirmEnd,
            title: appLocalized("playx.run.end", locale: locale),
            message: appLocalized("playx.run.end.detail", locale: locale),
            cancelTitle: appLocalized("playx.cancel", locale: locale),
            confirmTitle: appLocalized("playx.run.end", locale: locale),
            isDestructive: true,
            onCancel: { confirmEnd = false },
            onConfirm: {
                confirmEnd = false
                Task { await model.endRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) }
            }
        ))
        .cySheet(isPresented: $showEmergencyHelp) {
            PlayEmergencyHelpSheet()
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
        }
        .sheet(isPresented: $showPlayTools) { playToolsSheet }
        .sheet(isPresented: $guideShown) { AIGuideSheet(context: guideContext, journal: guideJournal) }
        .modifier(PlayGuideJournalFeed(journal: guideJournal, stop: guideStop?.name, greeting: guideStop?.npc?.greeting))
        .modifier(PlayContactReader(
            currentNodeID: model.snapshot.flatMap { PlayTaskSummaryPresentation(snapshot: $0).currentNodeID },
            active: model.hasCurrentMediaSnapshot && model.snapshot != nil,
            finished: model.snapshot?.availability == .completed,
            contact: $playContact
        ))
        .cySheet(isPresented: $showChapterPicker) {
            if let snapshot = model.snapshot {
                PlayChapterPickerSheet(rows: PlayChapterPickRow.rows(snapshot), current: chapterFilter) { picked in
                    withAnimation(CYMotion.standard) { chapterFilter = picked }
                }
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
            }
        }
        .overlay { titleCardOverlay }
        .onChange(of: doneChapterIDs, initial: true) { _, done in
            // The first read only records what was already settled; a chapter finishing in this visit opens the sheet.
            guard let previous = settledChapters else { settledChapters = done; return }
            settledChapters = done
            // fix-1128b #20 (J-03/J-17): the stage-end sheet opens only when its read is switched on. Release keeps
            // journey reads off (story-flow theme paused), so a chapter finish no longer opens a sheet that can only fail.
            if let chapterID = done.subtracting(previous).sorted().first,
               narrativeModel?(.stage(chapterID: chapterID))?.available == true {
                stageSettlement = PlayStageSettlementTarget(chapterID: chapterID)
            }
        }
        .cySheet(item: $stageSettlement) { target in
            if let narrative = narrativeModel?(.stage(chapterID: target.chapterID)) {
                NavigationStack {
                    JourneyNarrativeView(model: narrative, imageReader: narrativeImageReader, makeAudio: makeAudio, mediaScope: mediaScope)
                        .safeAreaInset(edge: .bottom) {
                            Button { stageSettlement = nil } label: { Text("playx.stage.continue").frame(maxWidth: .infinity) }
                                .buttonStyle(.cyPrimary(fullWidth: true))
                                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md)
                                .background(.bar)
                                .accessibilityIdentifier("playx.stage.continue")
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    var body: some View {
        presentationLayer
        // fix/1128c-ai-weather: story weather (SURVIVAL look) or live weather + weather events over the play scene.
        .modifier(PlaySceneWeather(topicID: model.snapshot?.result.topicID, latitude: sceneWeatherPoint?.latitude,
                                   longitude: sceneWeatherPoint?.longitude, look: themeFacts?.look))
        .modifier(PlayNightHintOverlay(receipt: model.reward))
        .modifier(PlayFlyScoreOverlay(receipt: model.reward))
        .modifier(PlayCouponToastOverlay(receipt: model.reward, snapshot: model.snapshot))
        // mp-journey r3: MP loadData → loadTeamProgress after every nodes read, then the 4 s poll while a team exists.
        // One page-level host (the lead section used to own the poll, so it only ran while that row was on screen).
        .task(id: model.interactionContext) { await model.probeLead(context: model.interactionContext) }
        .modifier(PlayLeadProgressPollingModifier(model: model, context: model.interactionContext))
        .modifier(ActiveSessionPlayHostMarker())
        .onChange(of: model.snapshot?.result.topicID) { _, topicID in
            chapterFilter = nil
            presentTitleCardIfNeeded(topicID)
        }
        .onChange(of: model.chapterStories.count) { _, _ in presentTitleCardIfNeeded(model.snapshot?.result.topicID) }
        // PLAY-r11-1: theme music loops under the run and follows 背景音乐 (MP _startThemeBgm / toggleThemeBgm).
        .task(id: PlayThemeMusicKey(url: model.snapshot?.result.topicAudioURL, enabled: playBGMOn)) {
            PlayBackgroundMusic.shared.startTheme(rawURL: model.snapshot?.result.topicAudioURL, enabled: playBGMOn,
                                                  approvedHosts: approvedArtworkHosts, owner: musicLifetime.id)
        }
        .task(id: model.snapshot?.result.teamID ?? model.snapshot?.result.topicID) {
            if let next = teamPoolModel?(0) {
                next.onPoolUpdated = { _ in }
                await next.load()
                runTeamPool = next.isVisible ? next : nil
            } else {
                runTeamPool = nil
            }
        }
        .task(id: PlayExperiencePresentationKey(model: model)) {
            // This task also restarts when returning from a pushed store. Preserve
            // the same owner's mode host through refresh so its open card pack survives.
            if presentationMount.enter(model) { selectedNode = nil; presentedMode = nil }
            await model.load()
            // E2E-20261113b: the mode can switch to city orientation before the snapshot is ready, when restoreRun's
            // guard still fails, so the run record was never read and Start did nothing. Restore once the load is done.
            if model.gameplayMode == .cityOrientation { await model.restoreRun(); projectAmbient() }
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
        .cyFullScreenCover(isPresented: $finishScreen) {
            if NativeR2Flags.cityOrientation { cityFinishSummary } else { finishMedalScreen }
        }
        .onChange(of: finishScreen) { _, shown in
            guard shown, let make = mpParity.journeyReport, let snapshot = model.snapshot else { return }
            let report = make(journeyRunScope(snapshot.result.topicID, snapshot.result.topicName))
            finishReport = report
            report.load()
        }
        .onChange(of: model.hasCurrentMediaSnapshot) { _, current in if !current { invalidateShopNPC?() } }
        .modifier(PlayExperienceCastMounts(host: self))
        .modifier(PlaySessionLocationHold(identity: model.identity, running: model.clock.phase == .running,
                                          currentIdentity: { [model] in model.identity }))
        // BGPAUSE-r11-1 (D-68/D-77): going to the background no longer pauses the city-orientation run. The run clock
        // keeps going and in-run audio keeps playing; only the explicit pause control or a real exit stops it.
        // MP pages/play/index.js:1210-1217 (`keepsRunningInBackground`).
        // P-050: city orientation distance is run-scoped. It keeps reading over pushed pages and, while the run is
        // started and not ended, in the background; the run's end stops it.
        .onChange(of: model.clock.phase, initial: true) { _, phase in syncCityRunTracking(phase) }
    }
    private func syncCityRunTracking(_ phase: PlayRunClock.Phase) {
        guard NativeR2Flags.cityOrientation, model.gameplayMode == .cityOrientation else { return }
        cityLocation.setRunActive(phase == .running || phase == .paused)
        if phase == .ended { cityLocation.stop() }
    }
    private var sceneWeatherPoint: (latitude: Double, longitude: Double)? {
        PlaySceneWeather.point(model.snapshot?.result.nodes ?? [])
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
        // Native r2: the title card is the first section of the route page, not a full-screen overlay.
        if !NativeR2Flags.storyFlow, let topicID = titleCardTopic, let snapshot = model.snapshot, snapshot.result.topicID == topicID {
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
    /// Every stop the read makes visible (`PlayStationListPresentation`): done ones as completed,
    /// locked ones as locked, the rest openable. Nothing here filters to the current stop only.
    @ViewBuilder private func stationsSection(_ snapshot: PlaySnapshot) -> some View {
        Section {
            let rows = PlayStationListPresentation.rows(snapshot, chapterID: chapterFilter)
            ForEach(rows) { row in
                if let node = snapshot.visibleNodes.first(where: { $0.id == row.id }) {
                    Button { selectedNode = node.id } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            CYRouteNodeRow(
                                index: row.position,
                                title: node.name ?? "#\(node.id)",
                                distanceAndETA: [node.address, node.businessTime].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " · "),
                                requirement: PlayTaskStatusCardMapper.arrivalRequirement(for: node),
                                completion: PlayTaskStatusCardMapper.routeCompletion(row.state),
                                isFirst: row.position == 1,
                                isLast: row.position == rows.count
                            )
                            PlayTaskStatusBadge(node: node, snapshot: snapshot)
                            if let reason = snapshot.lockReason(node) {
                                Text(verbatim: reason).font(CYTypography.caption).foregroundStyle(palette.warning)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, CYSpacing.xs)
                    }.accessibilityIdentifier("playx.node.\(node.id)")
                }
            }
        } header: {
            HStack {
                Text("playx.nodes")
                if let chapterFilter, let chapter = snapshot.result.chapters.first(where: { $0.id == chapterFilter }) {
                    Text(verbatim: "· " + chapterTitle(chapter.name)).cyWrapText()
                    Spacer()
                    Button("mpd.chapters.all") { withAnimation(CYMotion.standard) { self.chapterFilter = nil } }
                        .font(CYTypography.meta).textCase(nil)
                        .accessibilityIdentifier("play.chapterPick.clear")
                }
            }
        }
    }
    private var orientationList: some View {
        List { orientationSections(native: false) }
        .refreshable { if model.available && model.phase != .submitting { await model.load() } }
        .toolbar { orientationToolbar }
        .accessibilityIdentifier("playx.overview")
    }
    /// The run panel sections. `native` (NativeR2Flags.cityOrientation) leaves out the current-goal card and the
    /// station rows, which the native run sheet replaces with its next-stop and legs sections.
    @ViewBuilder private func orientationSections(native: Bool) -> some View {
            if NativeR2Flags.storyFlow, model.hasCurrentMediaSnapshot, let snapshot = model.snapshot, !model.chapterStories.isEmpty {
                NR2StoryRouteSections(snapshot: snapshot, coverURL: themeFacts?.coverURL,
                                      aiGenerated: themeFacts?.aiGenerated == true,
                                      cast: castModel?.config?.cast ?? [],
                                      readableChapterIDs: nr2ReadableChapters(snapshot),
                                      openChapter: { nr2ReaderChapter = $0 },
                                      openCast: castModel?.config == nil ? nil : { showingCastRoster = true })
            }
            // Template 6 order: (1) Current goal + location/arrival + 6-state status + primary CTA FIRST,
            // (2) Progress & runtime header, (3) Ordered stops (`CYRouteNodeRow`) & recovery/records.
            if !native, model.hasCurrentMediaSnapshot, !model.unresolved, let snapshot = model.snapshot,
               let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
               let node = snapshot.visibleNodes.first(where: { $0.id == id }) {
                Section("referenceTask.current") {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        HStack(alignment: .center, spacing: CYSpacing.sm) {
                            CYStatusChip(
                                LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: snapshot.result.mode, node: node).rawValue),
                                tone: .info,
                                systemImage: "flag.fill"
                            )
                            CYStatusChip(
                                verbatim: node.arrived == true
                                    ? CoreLoopCopy(locale: locale).t("已到达", "Arrived")
                                    : (node.needGPS == true || node.needScan == true
                                        ? CoreLoopCopy(locale: locale).t("待到达", "Not arrived")
                                        : CoreLoopCopy(locale: locale).t("线上/现场均可", "Flexible")),
                                tone: node.arrived == true ? .success : .neutral,
                                systemImage: node.arrived == true ? "checkmark.circle.fill" : "location.fill"
                            )
                            Spacer(minLength: 0)
                            PlayTaskStatusBadge(node: node, snapshot: snapshot)
                        }
                        if let place = node.address, !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label {
                                Text(verbatim: place)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(palette.actionPrimaryBg)
                                    .accessibilityHidden(true)
                            }
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.textSecondary)
                        }
                        CYTaskStatusCard(
                            title: node.name ?? "#\(node.id)",
                            state: PlayTaskStatusCardMapper.state(
                                node: node,
                                snapshot: snapshot,
                                model: model,
                                locale: locale,
                                ctaTitle: appLocalized("referenceTask.open", locale: locale),
                                onOpen: { selectedNode = id },
                                onRefresh: { Task { await model.load() } }
                            )
                        )
                        Button("referenceTask.open") { selectedNode = id }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("referenceTask.open")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                }
            }
            Section {
                if let snapshot = model.snapshot {
                    PlayTaskSummaryView(snapshot: snapshot, phase: model.phase.rawValue)
                    if let note = snapshot.result.timeNote { Text(verbatim: note).foregroundStyle(palette.textSecondary) }
                }
                if !model.available { Text("playx.disabled").accessibilityIdentifier("playx.disabled") }
                if model.phase == .loading {
                    // design-r2-play P10: words before content; the skeleton leaf keeps its identifier.
                    Text("designR2Play.run.loading").foregroundStyle(.secondary)
                    CYSkeleton().accessibilityIdentifier("playx.loading")
                }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                if native, model.snapshot == nil, model.available, model.issue != nil, model.phase != .loading {
                    // All states: the city run's first-load failure gets the same 刷新 action as the legacy error card.
                    Button { Task { await model.load() } } label: {
                        Label("playx.refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.phase == .submitting)
                    .accessibilityIdentifier("playx.city.retry")
                }
                if PlayContentCompatibility.isUnsupportedRejection(model.issue) {
                    // The server refused to open this run for this build; nothing was skipped or started.
                    Text("playCompat.refused.next", tableName: "PlayFullStory").font(CYTypography.caption)
                        .foregroundStyle(palette.textSecondary).accessibilityIdentifier("playCompat.refused")
                }
                PlayResyncAction(model: model)
                if model.hasCurrentMediaSnapshot, let notice = model.routeNotice { PlayRouteNoticeRow(notice: notice) }
                if model.remoteRunSaveFailed { Label("playx.run.saveFailed", systemImage: "exclamationmark.triangle.fill").font(CYTypography.caption).foregroundStyle(palette.warning) }
            }
            // F-05: the ordered stops follow the progress header (Template 6), so every visible stop is
            // reachable in the half-height panel instead of sitting below records and downloads.
            if !native, let snapshot = model.snapshot { stationsSection(snapshot) }
            if let compatibility = model.compatibility, model.hasCurrentMediaSnapshot {
                PlayCompatibilitySection(compatibility: compatibility)
            }
            if let runTeamPool, runTeamPool.isVisible {
                TeamPoolRunStatusSection(model: runTeamPool)
            }
            if let openingModel { PlayOpeningCompletionSection(model: openingModel) }
            // MP D1: 入场码 opens only from the 游玩工具 row (`openTicketFromTools`), not from the page.
            if let cityGameModel {
                Section { CityGamePanel(model: cityGameModel, read: cityGameModel.read, boardLayout: true) }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section {
                NavigationLink { PlayGapMiscSurfaces() } label: {
                    Text("playGap.entry", tableName: "PlayGapMisc")
                }
                .accessibilityIdentifier("playGap.entry")
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
                if !NativeR2Flags.storyFlow, let snapshot = model.snapshot, model.hasCurrentMediaSnapshot {
                    Section("chapterStory.title") {
                        ForEach(snapshot.result.chapters) { chapter in
                            if let node = snapshot.visibleNodes.first(where: { $0.chapterID == chapter.id && !snapshot.isLocked($0) }),
                               model.chapterStories[chapter.id] != nil {
                                NavigationLink {
                                    ChapterStoryView(chapterID: chapter.id, nodeID: node.id, model: model,
                                        advancedModel: advancedModel, journeyModel: journeyModel, deviceModel: deviceModel, mediaScope: mediaScope,
                                        makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                                        castModel: castModel, nodeDestination: { AnyView(nodeDestination($0)) })
                                } label: {
                                    if let title = chapter.name { Label { Text(verbatim: title) } icon: { Image(systemName: "book") } }
                                    else { Label("chapterStory.title", systemImage: "book") }
                                }.accessibilityIdentifier("chapterStory.open.\(chapter.id)")
                            }
                        }
                    }
                }
                Section("playx.results") {
                    if let mode = model.snapshot?.result.runStartMode {
                        LabeledContent("playx.completion.start") {
                            Text(LocalizedStringKey(mode == .desk ? "playx.completion.desk" : "playx.completion.alternate"))
                        }
                        .accessibilityIdentifier("playx.runStartMode")
                    }
                    if let snapshot = model.snapshot {
                        let cards = PlayRunKeepsakes.evidence(in: snapshot)
                        if !cards.isEmpty {
                            Text("playx.evidence.title").cyText(.cardTitle)
                            ForEach(cards) { card in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let title = card.title { Text(verbatim: title).cyText(.cardTitle) }
                                    Text(verbatim: card.text).cyText(.body)
                                }
                                .accessibilityIdentifier("playx.evidence.\(card.id)")
                            }
                        }
                        let photos = PlayRunKeepsakes.photos(in: snapshot)
                        if !photos.isEmpty {
                            Text("playx.photos.title").cyText(.cardTitle)
                            ForEach(photos) { photo in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let title = photo.title { Text(verbatim: title).cyText(.bodyCompact) }
                                    PlayStationArtwork(image: PlayStationImage(source: photo.url, tier: .station), title: photo.title ?? "")
                                }
                                .accessibilityIdentifier("playx.photos.\(photo.id)")
                            }
                        }
                    }
                    if let snapshot = model.snapshot, snapshot.availability == .completed, model.hasCurrentMediaSnapshot {
                        // mp-journey r3 (MP pages/play/index.wxml 通关 banner): N 处旧址已点亮 over 领取你的城市足迹卡.
                        let lit = snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
                        Button { finishScreen = true } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("playx.finish.banner.lit \(lit)").font(.footnote).foregroundStyle(.secondary)
                                    Text("playx.finish.banner.claim").font(.headline)
                                }
                            } icon: { Image(systemName: "rosette") }
                        }
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
                    if circleModel != nil, let topicID = model.snapshot?.result.topicID, topicID > 0 { CircleThemeHostSection(topicID: topicID) }
                    if let card = finishRouteModel?.card {
                        PlayFinishRouteCardView(card: card, destination: finishRouteDestination)
                            .modifier(FinishRouteAnalyticsModifier(card: card, activityID: { if case .activity(let id) = model.scope { return id }; return nil }(),
                                topicID: model.snapshot?.result.topicID, runID: model.snapshot?.result.routeState?.sessionID, mode: model.snapshot?.result.mode))
                    }
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
                        NavigationLink("playx.backpack.title") {
                            PlayThemeBackpackView(model: backpackModel, externalGamesEnabled: ExternalGameSessionRead.externalGamesOpen(baseURL: externalGameSession?.baseURL))
                        }
                            .accessibilityIdentifier("playx.backpack.open")
                    }
                    if let teamBackpackModel {
                        NavigationLink("play.teamBackpack.title") { PlayTeamBackpackView(model: teamBackpackModel) }
                            .accessibilityIdentifier("play.teamBackpack.open")
                    }
                }
                // 联系主办 / 联系商家 is the MP 游玩工具 row (read by `PlayContactReader` on this page).
                if model.hasCurrentMediaSnapshot, let snapshot = model.snapshot {
                    // 已完成章节 from `GET api/play/history` that the live route no longer lists.
                    PlayCompletedHistorySection(routeSessionID: snapshot.route?.sessionID,
                                                liveChapterIDs: Set(snapshot.result.chapters.map(\.id)))
                }
                if let reward = model.reward { PlayRewardSection(reward: reward, collectionDestination: rewardCollectionDestination) }
                if let ending = model.ending {
                    Section("playx.ending") {
                        if ending.hasStory {
                            if !ending.opener.isEmpty { Text(verbatim: ending.opener) }
                            ForEach(Array(ending.fragments.enumerated()), id: \.offset) { _, fragment in
                                VStack(alignment: .leading) { Text(verbatim: fragment.name).cyText(.cardTitle); if let text = fragment.text, !text.isEmpty { Text(verbatim: text) } }
                            }
                        } else { ContentUnavailableView("playx.ending.empty", systemImage: "book.closed").accessibilityIdentifier("playx.ending.empty") }
                    }
                    if let config = castModel?.config {
                        CastEndingSection(config: config, result: CastEndingResult(raw: model.castPayload))
                    }
                }
                if let board = model.leaderboard {
                    Section("playx.leaderboard") {
                        ForEach(board.entries) { row in
                            LabeledContent { Text(verbatim: String(row.score)).monospacedDigit() } label: {
                                HStack(spacing: 10) {
                                    Text(verbatim: row.rank.map(String.init) ?? "—").cyText(.cardTitle, monospacedDigit: true).frame(minWidth: 28, alignment: .leading)
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
    @ToolbarContentBuilder private var orientationToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load() } } label: { Label("playx.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.phase == .submitting || !model.available).accessibilityIdentifier("playx.refresh")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // 游玩工具: 切换章节 when the route has more than one chapter (also after the run is done), 紧急求助 always.
                PlayToolsMenu(showsChapters: (model.snapshot?.result.chapters.count ?? 0) > 1, showsEmergency: model.snapshot != nil,
                              openChapters: { showChapterPicker = true }, openEmergency: { showEmergencyHelp = true },
                              openScanArrival: hudStop == nil ? nil : { if let id = hudStop?.node.id { selectedNode = id } },
                              openPreferences: openPlayTools)
            }
    }
    private func openPlayTools() { showPlayTools = true }
    /// PLAY-6a: lead actions already sit in `PlayLeadSection` on the page, so the sheet carries stats + preferences.
    private var playToolsSheet: some View {
        PlayToolsAndLeadSheetView(
            chapterCount: model.snapshot?.result.chapters.count ?? 0,
            completedCount: doneChapterIDs.count,
            bgmEnabled: $playBGMOn,
            narrationAutoplay: $playNarrationOn,
            reduceMotionOverride: playReducedMotionBinding,
            onClose: { showPlayTools = false },
            showsContentRows: false,
            evidenceCards: model.snapshot.map(PlayRunKeepsakes.passTextEvidence(in:)) ?? [],
            locationOn: Self.locationAuthorized,
            onLocationRow: Self.openLocationSettings,
            teamLead: model.lead,
            journalRows: model.snapshot.map(PlayJournal.rows(in:)),
            journalAttributes: model.snapshot.map(PlayJournal.attributes(in:)) ?? [],
            boardDestination: model.snapshot == nil ? nil : { [model] in AnyView(PlayCompanionBoardView(model: model)) },
            scoreDestination: orientScoreDestination,
            entryCodeRegistrationID: entryCode?.registrationID,
            contact: playContact
        )
    }
    /// mp-journey r3: MP `_orientSessionId` (mode 1 and `routeState.sessionId`) opens 本局成绩; natively that is the
    /// member orient-score page at this session.
    private var orientScoreDestination: (() -> AnyView)? {
        guard let result = model.snapshot?.result, result.mode == 1,
              let sessionID = result.routeState?.sessionID, sessionID > 0,
              let topicID = result.topicID, topicID > 0 else { return nil }
        var query = ["topicId": String(topicID), "sessionId": String(sessionID)]
        if case .activity(let activityID) = model.scope { query["activityId"] = String(activityID) }
        let route = MPParityRoute.screen(page: "subpackageMember/orient-score/index", query: query)
        return { AnyView(MPParityDestination(route: route)) }
    }
    /// mp-journey r3: MP `gpsOk` for the 游玩工具 location rows (when-in-use or always).
    private static var locationAuthorized: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    /// MP `onLocationRowTap` with location off: send the player to this app's location setting.
    private static func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    /// `utils/motion-preference.js`: writes the primary and the legacy key.
    private var playReducedMotionBinding: Binding<Bool> {
        Binding(get: { _ = playReducedMotion; return PlayReducedMotionPreference.isEnabled(in: .standard) },
                set: { on in PlayReducedMotionPreference.set(on, in: .standard); playReducedMotion = on })
    }
    private var playChannelScope: InGameChannelScope? {
        if let teamID = model.snapshot?.result.teamID, teamID > 0 {
            return .team(id: teamID)
        }
        switch model.scope {
        case .activity(let id):
            return .activity(id: id)
        case .topic(let id):
            return .topic(id: id)
        }
    }
    private var playChannelTitleKey: LocalizedStringKey {
        if let teamID = model.snapshot?.result.teamID, teamID > 0 {
            return "ingame.channel.team"
        }
        return "ingame.channel.activity"
    }
    /// Map-first play screen: static map ground, glass clock / route map / end on top, the one primary
    /// (pause / resume) above the panel, and the unchanged task list in a three-detent panel.
    // MARK: native r2 city orientation (NativeR2Flags.cityOrientation)

    /// N-PLAY-DARK (MP pages/play/index.wxml is a normal light page): the runtime shell, backpack, route map and node
    /// pages follow the system Light/Dark setting under the player domain. Only the focused kit stage stays dark.
    private var screenDomain: ThemeDomain { .player }

    /// Any other presentation of this screen hides the run sheet first; it comes back when that one closes.
    private var cityRunSheetBlocked: Bool {
        finishScreen || stageSettlement != nil || showEmergencyHelp || showChapterPicker || showRouteMap || showBackpack
            || selectedNode != nil || titleCardTopic != nil || castCover || showingCastRoster
    }
    private var cityRunSheetBinding: Binding<Bool> {
        Binding(get: { cityRunSheet && !cityRunSheetBlocked }, set: { shown in if shown { cityRunSheet = true } })
    }
    @ViewBuilder private var cityOrientationNative: some View {
        let routeOpen = !model.unresolved && model.interactionContext != nil
            && model.snapshot.flatMap { PlayRouteMapPresentation(snapshot: $0) } != nil
        CityOrientationRunView(
            model: model, location: cityLocation, teammates: cityTeams, sheetShown: cityRunSheetBinding,
            onOpenRoute: routeOpen ? { showRouteMap = true } : nil,
            onEnd: model.snapshot == nil ? nil : { cityEndDialog = true },
            onPunch: { cityPunchNode = CityOrientationPunchTarget(id: $0) },
            channel: {
                // The nav bar carries the channel while there is no current stop; otherwise it sits on the map.
                if let scope = playChannelScope, hudStop != nil {
                    InGameChannelToolbarButton(scope: scope, titleKey: playChannelTitleKey,
                                               accessibilityID: "ingame.channel.play.entry",
                                               reloadTrigger: model.snapshot?.result.teamID ?? 0)
                }
            },
            panel: { cityRunPanel })
        .onAppear { cityRunSheet = true }
        .onDisappear { cityRunSheet = false; cityPunchNode = nil; cityHintNode = nil }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                PlayRunNoticeBanner(snapshot: model.snapshot)
                PlayLeadBar(model: model)
            }
        }
        .modifier(PlayNavBubbleOverlay(model: ambientModel, nodeID: hudStop?.node.id, meters: cityNextStopMeters))
    }
    @ViewBuilder private var cityRunPanel: some View {
        VStack(spacing: 0) {
            CityOrientationRunMetricsRow(model: model, walkedMeters: cityLocation.walkedMeters, nextStopMeters: cityNextStopMeters) {
                // Next round (motion): start / resume taps land with a medium impact, pause with a light one; a restored
                // paused record (idle → paused) stays silent.
                cityRunPrimary
                    .modifier(PlayClockHaptics(running: model.clock.phase == .running, paused: model.clock.phase == .paused))
            }
            NavigationStack {
                List {
                    if model.hasCurrentMediaSnapshot, !model.unresolved, let snapshot = model.snapshot,
                       let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
                       let node = snapshot.visibleNodes.first(where: { $0.id == id }) {
                        CityOrientationNextStopSection(
                            node: node, snapshot: snapshot,
                            distance: cityLocation.distance(toLatitude: node.latitude, longitude: node.longitude),
                            onPunch: { cityPunchNode = CityOrientationPunchTarget(id: id) },
                            onHint: { openCityHint(id) })
                    }
                    if let snapshot = model.snapshot, let route = PlayRouteMapPresentation(snapshot: snapshot) {
                        CityOrientationStepChecklistSection(route: route) { cityPunchNode = CityOrientationPunchTarget(id: $0) } // R-steps
                        CityOrientationLegsSection(route: route, onOpen: { cityPunchNode = CityOrientationPunchTarget(id: $0) })
                    } else if let snapshot = model.snapshot {
                        stationsSection(snapshot)
                    }
                    if case .activity = model.scope {
                        CityOrientationTeammatesSection(teams: cityTeams, total: model.snapshot?.visibleNodes.count ?? 0)
                    }
                    orientationSections(native: true)
                }
                .refreshable { if model.available && model.phase != .submitting { await model.load() } }
                .toolbar { orientationToolbar }
                // design-r2-play: the run screen's nav bar already reads 城市定向; the panel does not repeat it.
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("playx.overview")
            }
        }
        .environment(\.cityOrientationTeamsSink, { teams in cityTeams = teams })
        .cySheet(item: $cityPunchNode) { target in
            CityOrientationPunchSheet(
                model: model, nodeID: target.id, location: cityLocation,
                onOpenTask: { id in cityPunchNode = nil; selectedNode = id },
                onNext: { id in cityPunchNode = CityOrientationPunchTarget(id: id) })
            .nativeR2SheetBackdropSource()
        }
        .nativeR2SheetBackdrop(isPresented: cityPunchNode != nil)
        // P-056: the hint ladder opens in place; the stop page is only for stops without a server ladder.
        .cySheet(item: $cityHintNode) { target in
            CityOrientationHintSheet(
                model: model, nodeID: target.id, makeTeamPool: teamPoolModel, approvedArtworkHosts: approvedArtworkHosts,
                onOpenStop: { id in cityHintNode = nil; hintNode = id; selectedNode = id })
        }
        .confirmationDialog(Text("playx.run.end"), isPresented: $cityEndDialog, titleVisibility: .visible) {
            Button("playx.run.end", role: .destructive) {
                Task { await model.endRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) }
            }
            Button("playx.cancel", role: .cancel) {}
        } message: {
            Text("playx.run.end.detail")
        }
    }
    /// design-r2-play P1: metres to the current stop, so the paused peek leads with a real value instead of "—".
    private var cityNextStopMeters: Double? {
        guard model.hasCurrentMediaSnapshot, !model.unresolved, let snapshot = model.snapshot,
              let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
              let node = snapshot.visibleNodes.first(where: { $0.id == id }) else { return nil }
        return cityLocation.distance(toLatitude: node.latitude, longitude: node.longitude)
    }
    /// P-056: a server hint ladder opens as a sheet over the map; without one, the stop page keeps its legacy hint rows.
    private func openCityHint(_ id: Int) {
        if model.helpClient(nodeID: id) != nil {
            cityHintNode = CityOrientationHintTarget(id: id)
        } else {
            hintNode = id; selectedNode = id
        }
    }
    /// Same actions and identifiers as `runPrimary`, drawn with system button styles.
    @ViewBuilder private var cityRunPrimary: some View {
        if model.snapshot != nil {
            if model.clock.phase == .running {
                Button { Task { await model.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) } } label: {
                    Label("playx.run.pause", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(!model.canManageRun)
                .accessibilityIdentifier("playx.run.pause")
            } else if model.clock.phase != .ended {
                Button { model.startRun(now: ProcessInfo.processInfo.systemUptime) } label: {
                    Label(model.clock.elapsedSeconds == 0 ? "playx.run.start" : "playx.run.resume", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!model.canManageRun)
                .accessibilityIdentifier("playx.run.resume")
            }
        }
    }
    @ViewBuilder private var cityFinishSummary: some View {
        let snapshot = model.snapshot
        let medals = model.reward.map { PlayRewardSection.medals(in: $0, locale: locale) } ?? []
        let topic = snapshot?.result.topicName.flatMap { $0.isEmpty ? nil : $0 }
        let key = finishResultKey(snapshot)
        let title = appLocalized(String.LocalizationValue(key), locale: locale)
        let earned = medals.isEmpty ? nil : appLocalized("medalScreen.earned \(medals.count)", locale: locale)
        CityOrientationFinishSummaryView(
            model: model, titleKey: key, subtitle: [topic, earned].compactMap { $0 }.joined(separator: " · "),
            medals: medals, shareText: appLocalized("medalScreen.shareText \(topic ?? title)", locale: locale),
            walkedMeters: cityLocation.walkedMeters, reportDestination: cityReportDestination,
            scoreDestination: (snapshot?.result.allDone ?? false) ? nil : orientScoreDestination?(),
            collectionDestination: cityCollectionDestination,
            onClose: { finishScreen = false })
    }
    /// Design pass roam (P8): the badge collection for the first badge this run awarded, through the same
    /// `rewardCollectionDestination` the reward rows use.
    private var cityCollectionDestination: AnyView? {
        guard let reward = model.reward, let target = PlayRewardBadgeTarget.targets(in: reward).first else { return nil }
        return rewardCollectionDestination?(target)
    }
    private var cityReportDestination: AnyView? {
        guard mpParity.journeyReport != nil, let snapshot = model.snapshot else { return nil }
        return AnyView(MPParityDestination(route: .journeyReport(journeyRunScope(snapshot.result.topicID, snapshot.result.topicName))))
    }
    private var orientationContent: some View {
        CYMapScaffold(detent: .medium, map: { PlayStoryMapGround(snapshot: model.snapshot) }, controls: { runHeader }, floating: { runFloating },
                      panel: { orientationList })
    }
    /// The one current stop of a live run, for the play HUD (401:4731). nil while branches are a choice, before the
    /// read is current, after the run ends, or when the run is unresolved: then the floating area is the run primary.
    private var hudStop: (node: PlayNode, snapshot: PlaySnapshot)? {
        guard model.gameplayMode == .cityOrientation, model.hasCurrentMediaSnapshot, !model.unresolved,
              model.clock.phase != .ended, let snapshot = model.snapshot,
              let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
              let node = snapshot.visibleNodes.first(where: { $0.id == id }) else { return nil }
        return (node, snapshot)
    }
    @ViewBuilder private var runFloating: some View {
        if let hud = hudStop {
            PlayHUDView(node: hud.node, snapshot: hud.snapshot, elapsedSeconds: model.clock.elapsedSeconds,
                        onOpenStop: { selectedNode = hud.node.id },
                        onHint: { hintNode = hud.node.id; selectedNode = hud.node.id },
                        onBackpack: (backpackModel != nil || teamBackpackModel != nil) ? { showBackpack = true } : nil,
                        primary: { runPrimary },
                        team: {
                            if let scope = playChannelScope {
                                InGameChannelToolbarButton(scope: scope, titleKey: playChannelTitleKey,
                                                           accessibilityID: "ingame.channel.play.entry",
                                                           reloadTrigger: model.snapshot?.result.teamID ?? 0)
                            }
                        })
        } else {
            runPrimary
        }
    }
    @ViewBuilder private var backpackDestination: some View {
        if let teamBackpackModel, model.snapshot?.result.teamID ?? 0 > 0 {
            PlayTeamBackpackView(model: teamBackpackModel)
        } else if let backpackModel {
            PlayThemeBackpackView(model: backpackModel, externalGamesEnabled: ExternalGameSessionRead.externalGamesOpen(baseURL: externalGameSession?.baseURL))
        } else if let teamBackpackModel {
            PlayTeamBackpackView(model: teamBackpackModel)
        }
    }
    /// Elapsed clock plus route map and end as glass controls (max three with the toolbar refresh).
    @ViewBuilder private var runHeader: some View {
        if model.snapshot != nil {
            let seconds = model.clock.elapsedSeconds
            HStack(spacing: CYSpacing.sm) {
                // N-PLAY-MAP (r10): system clock label on a regular material capsule (MP pages/play/index.wxml run timer).
                Label {
                    Text(verbatim: PlayRunElapsedText.format(seconds))
                        .font(.title3.weight(.semibold)).monospacedDigit()
                        .accessibilityAddTraits(.updatesFrequently)
                        .accessibilityIdentifier("playx.run.clock")
                } icon: { Image(systemName: "timer").accessibilityHidden(true) }
                .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
                .background(.regularMaterial, in: Capsule())
                Spacer(minLength: CYSpacing.sm)
                if !model.unresolved, model.interactionContext != nil, let snapshot = model.snapshot,
                   PlayRouteMapPresentation(snapshot: snapshot) != nil {
                    Button { showRouteMap = true } label: { Label("playRoute.open", systemImage: "map").labelStyle(.iconOnly) }
                        .buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.large)
                        .accessibilityIdentifier("playRoute.open")
                }
                if model.clock.phase != .ended {
                    Button { confirmEnd = true } label: { Label("playx.run.end", systemImage: "flag.checkered").labelStyle(.iconOnly) }
                        .buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.large)
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
                    .pageTemplateControl(label: Text("playx.run.pause"), traits: .isButton)
                    .accessibilityIdentifier("playx.run.pause")
                } else if model.clock.phase != .ended {
                    Button { model.startRun(now: ProcessInfo.processInfo.systemUptime) } label: {
                        Label(seconds == 0 ? "playx.run.start" : "playx.run.resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cyPrimary).disabled(!model.canManageRun)
                    .pageTemplateControl(label: Text(seconds == 0 ? "playx.run.start" : "playx.run.resume"), traits: .isButton)
                    .accessibilityIdentifier("playx.run.resume")
                }
            }
            .controlSize(.large).frame(maxWidth: 280).padding(.horizontal, CYSpacing.lg)
        }
    }
    /// Chapters the native route page can open: a story document and a stop that is not locked (same rule as r1's list).
    private func nr2ReadableChapters(_ snapshot: PlaySnapshot) -> Set<Int> {
        Set(snapshot.result.chapters.compactMap { chapter in
            guard model.chapterStories[chapter.id] != nil,
                  snapshot.visibleNodes.contains(where: { $0.chapterID == chapter.id && !snapshot.isLocked($0) }) else { return nil }
            return chapter.id
        })
    }
    /// The same `ChapterStoryView` the r1 chapter link pushed, for the chapter's first unlocked stop.
    @ViewBuilder private func nr2ReaderDestination(_ chapterID: Int) -> some View {
        if let snapshot = model.snapshot,
           let node = snapshot.visibleNodes.first(where: { $0.chapterID == chapterID && !snapshot.isLocked($0) }) {
            ChapterStoryView(chapterID: chapterID, nodeID: node.id, model: model,
                advancedModel: advancedModel, journeyModel: journeyModel, deviceModel: deviceModel, mediaScope: mediaScope,
                makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                castModel: castModel, nodeDestination: { AnyView(nodeDestination($0)) })
        } else {
            ContentUnavailableView("play.nr2.reader.locked", systemImage: "lock",
                                   description: Text("play.nr2.reader.locked.detail"))
                .accessibilityIdentifier("chapterStory.lockedStop")
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
                        castModel: castModel,
                        nodeDestination: { AnyView(freeStoreDestination($0)) }))
                }, storeDayModel: storeDayModel,
                arrivalLocation: RuntimeNativeLocationProvider(enabled: true))
        } else { Text("playMode.unavailable") }
    }
    /// Chapters whose visible places are all done and unlocked (the same rule as the 旅程记录 stage rows).
    private var doneChapterIDs: Set<Int> {
        guard let snapshot = model.snapshot, model.hasCurrentMediaSnapshot else { return [] }
        return Set(snapshot.result.chapters.compactMap { chapter in
            let nodes = snapshot.visibleNodes.filter { $0.chapterID == chapter.id }
            return !nodes.isEmpty && nodes.allSatisfy({ snapshot.isDone($0) && !snapshot.isLocked($0) }) ? chapter.id : nil
        })
    }
    @ViewBuilder private func narrativeLink(_ query: JourneyNarrativeQuery, subtitle: String? = nil) -> some View {
        if let narrative = narrativeModel?(query) {
            NavigationLink {
                JourneyNarrativeView(model: narrative, imageReader: narrativeImageReader, makeAudio: makeAudio, mediaScope: mediaScope)
            } label: {
                VStack(alignment: .leading) { Text(LocalizedStringKey(query.titleKey)); if let subtitle { Text(verbatim: subtitle).cyText(.meta) } }
            }.accessibilityIdentifier("journey.record.open." + query.key)
        }
    }
    @ViewBuilder private func nodeDestination(_ id: Int, opensHelp: Bool = false) -> some View {
        if model.gameplayMode == .cityOrientation {
        let configuration = try? PlayStillnessConfiguration(raw: model.extras[id]?.sensorConfig ?? .null)
        PlayExperienceNodeView(nodeID: id, model: model, device: deviceModel?(id), advanced: advancedModel.flatMap { $0(id) },
            stillness: configuration.flatMap { configuration in motionModel.flatMap { $0(id, configuration) } },
            preference: preferenceModel.flatMap { $0(id) }, journey: journeyModel.flatMap { $0(id) }, narrative: narrativeModel?(.questions(nodeID: id)), shopNPC: shopNPCModel?(id),
            mediaScope: mediaScope, makeAudio: makeAudio, makeExternalMaps: makeExternalMaps, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
            makeTeamPool: teamPoolModel, openNode: { selectedNode = $0 }, opensHelp: opensHelp)
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
        let title = appLocalized(String.LocalizationValue(finishResultKey(snapshot)), locale: locale)
        // Only medals the reward read actually returned; none means no medal line, never "1".
        let earned = medals.isEmpty ? nil : appLocalized("medalScreen.earned \(medals.count)", locale: locale)
        let subtitle = [topic, earned].compactMap { $0 }.joined(separator: " · ")
        let stats = [
            CYStoryStat(key: "medalScreen.stat.time", value: Self.finishClockText(model.clock.elapsedSeconds), systemImage: "stopwatch"),
            CYStoryStat(key: "medalScreen.stat.nodes", value: done.flatMap { nodes.isEmpty ? nil : "\($0)/\(nodes.count)" }, systemImage: "book"),
        ].filter { $0.value != nil }
        CYMedalScreen(items: medals, title: title, subtitle: subtitle, stats: stats,
                      shareText: appLocalized("medalScreen.shareText \(topic ?? title)", locale: locale),
                      secondaryTitle: "medalScreen.records",
                      onClose: { finishScreen = false })
    }
    /// `finish-result.js`: cleared only from the report's legitimate completion or the server route's own COMPLETED status;
    /// every stop done while the report is pending or unreadable has no result word.
    private func finishResultKey(_ snapshot: PlaySnapshot?) -> String {
        let state: PostGameFinishResult.ReportState
        switch finishReport?.phase {
        case .ready(let report)?: state = .loaded(report.result.flatMap { PostGameCompletion(rawValue: $0.rawValue) })
        case .loading?: state = .pending
        default: state = .failed
        }
        let result = PostGameFinishResult.resolve(report: state, topicCompleted: snapshot?.route?.status == "COMPLETED",
                                                  allDone: snapshot?.result.allDone ?? false, chapterDone: false)
        switch result {
        case .cleared: return "medalScreen.themeComplete"
        case .assisted: return "mp.report.result.assisted"
        case .ended: return "mp.report.result.ended"
        case .chapterDone, .unknown: return "medalScreen.allDone"
        }
    }
    private static func finishClockText(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        return PlayRunElapsedText.format(seconds)
    }
    private func projectAmbient() {
        guard let result = model.snapshot?.result else { return }
        ambientModel?.project(eggs: result.eggs, topicID: result.topicID)
    }
    private static var milliseconds: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    /// Naming, then the playbill, only at the start of an active run that has not finished a station.
    private var castOpeningStep: CastOpeningFlow.Step? {
        guard let config = castModel?.config, model.snapshot?.availability == .active, let snapshot = model.snapshot else { return nil }
        let anyDone = snapshot.visibleNodes.contains { snapshot.isDone($0) }
        return CastOpeningFlow.step(config: config, profile: castModel?.profile, anyStationDone: anyDone, playbillSeen: castPlaybillSeen)
    }
    private func adoptCast() {
        let payload = model.castPayload
        guard payload != .null else {
            castModel?.invalidate()
            castModel = nil
            castCover = false
            return
        }
        let next = castModel ?? model.makeCastCoordinator()
        next.adopt(raw: payload, topicID: model.snapshot?.result.topicID, runID: model.snapshot?.route?.sessionID)
        if castModel !== next { castModel = next }
        if castOpeningStep != nil { castCover = true }
    }
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
    var makeTeamPool: ((Int) -> TeamPoolHintModel?)? = nil
    /// Opens another stop from the outcome card ("Next stop"); nil hides that shortcut.
    var openNode: ((Int) -> Void)? = nil
    /// Opened from 提示 on the play HUD: the hint ladder sheet comes up once the ladder has loaded (no ladder: the
    /// stop's own hint rows are on the page).
    var opensHelp = false
    @State private var helpOpenedOnce = false
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var answer = ""
    /// Shared full-screen verdict (mini-program play-verdict) after this stop's own submission settles.
    @State private var verdict: CYPlayVerdict?
    @State private var review: PlayCompletionReview?
    @State private var showReview = false
    @State private var showHint = false
    @State private var hintContext: PlayInteractionContext?
    @State private var hintLevel: Int?
    /// F-05: why the last submit tap was refused. Shown beside the button and as a toast, never silently dropped.
    @State private var refusal: PlayReviewRefusal?
    /// UG-05…UG-09 ladder for this stop. When the server enables it, the legacy hint and reveal entries step aside.
    @State private var help: PlayHelpLadderModel?
    /// The team's shared pool for this stop, shown inside the hint dialog when the server enables it.
    @State private var teamPool: TeamPoolHintModel?
    @State private var showHelpPanel = false
    @State private var skippedHere = false
    @State private var showUnsavedDiscard = false
    @State private var nodeToastMessage: String?
    /// This screen's own submission settled as done (the button shows 已完成 in place).
    @State private var justSubmitted = false
    /// Native r2: the stage result shown in place as a medium sheet after this screen's own submission.
    @State private var nr2Result: NR2StageResultTarget?
    /// The server's reason when this screen's answer was not accepted, shown above the button.
    @State private var rejectionText: String?
    /// 「我已到达」 on the existing completion channel. One when-in-use fix; no continuous roam.
    @State private var arrival: PlayArrivalService?
    @State private var continuedWithoutPhoto = false
    private var answerPhase: CYResultPhase {
        if outcomeState == .submitting { return .loading }
        if justSubmitted && (outcomeState == .completed || nodeDone) { return .done }
        return .idle
    }
    private var node: PlayNode? { model.snapshot?.visibleNodes.first { $0.id == nodeID } }
    /// The server's done flag for this stop: node `done`, or a `COMPLETED` node or route state.
    private var nodeDone: Bool { node.map { model.snapshot?.isDone($0) == true } ?? false }
    private var activeDispatchedTask: PlayRandomDispatchedTask? {
        if let reward = model.reward, reward["nodeId"].tolerantInteger == nodeID,
           let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
            return dispatched
        }
        return model.extras[nodeID]?.dispatchedTask
    }
    private var helpEnabled: Bool { help?.enabled == true && help?.identity.nodeID == nodeID }
    private var gameStage: PlayGameStage? {
        guard let result = model.snapshot?.result else { return nil }
        guard PlayKitPilotGate.allows(eventID: result.topicID) else { return nil }
        return PlayGameStage.resolve(nodeID: nodeID, nodes: result.nodes, chapters: result.chapters)
    }
    var body: some View {
        let context = model.interactionContext
        nodeWithConfirms(context: context)
            .environment(\.playGameStage, gameStage)
            // Native r2 games: the kit shell shows the same ladder from its toolbar hint button.
            .environment(\.nativeGameHelp, helpEnabled ? help.map { NativeGameHelpContext(model: $0, teamPool: teamPool, approvedArtworkHosts: approvedArtworkHosts,
                onPoolTrimmed: { Task { await advanced?.refreshAuthoritative() } }) } : nil)
            // Design hand-off r1 PL-15: the hint ladder is a resizable sheet over the play screen.
            .cySheet(isPresented: Binding(get: { showHelpPanel && helpEnabled }, set: { if !$0 { showHelpPanel = false } })) {
                if let help {
                    PlayHelpLadderPanel(model: help, teamPool: teamPool, approvedArtworkHosts: approvedArtworkHosts,
                                         onPoolTrimmed: { Task { await advanced?.refreshAuthoritative() } },
                                         close: { showHelpPanel = false })
                }
            }
            .cyModalOverlay(isPresented: showUnsavedDiscard) {
                PlayUnsavedEditModal(
                    onKeepEditing: { showUnsavedDiscard = false },
                    onDiscard: { showUnsavedDiscard = false; answer = "" }
                )
            }
            .cyToast(verbatimMessage: $nodeToastMessage)
            // Native r2 M4: a revealed hint (story or game stop) also shows as a hint island; "下一条提示" reopens the ladder.
            .islandHints(helpEnabled ? help : nil) { showHelpPanel = true }
            .onChange(of: answer) { _, _ in refusal = nil }
            // A new read (advanced step accepted, stop done, run resynced) replaces the reason from the last tap.
            .onChange(of: model.reviewRefusal(nodeID: nodeID)) { _, _ in refusal = nil }
            .onChange(of: help?.skipped) { _, skipped in
                // The server settled the skip (0 points, assisted). No success verdict; progress is re-read by the model.
                if skipped == true { skippedHere = true; showHelpPanel = false }
            }
            .onChange(of: teamPool?.skipResult) { _, skipped in
                if skipped != nil {
                    skippedHere = true
                    showHelpPanel = false
                    Task { await model.load() }
                }
            }
            .onAppear { if arrival == nil { arrival = PlayArrivalService(runtime: model, location: RuntimeNativeLocationProvider(enabled: true)) } }
            .onDisappear { journey?.roleContent.close(); device?.cancel(); arrival?.cancel(); model.cancelReview(); review = nil; hintContext = nil; answer = ""; showHelpPanel = false }
    }

    @ViewBuilder
    private func nodeList(context: PlayInteractionContext?) -> some View {
        List {
            PlayTaskOutcomeSection(model: model, nodeID: nodeID, openNode: openNode)
            // mp-journey r3 (MP p03 `gp2__right`, P-11): after this screen's own accepted answer, the author's
            // feedback (or 对了) and the stop's 碎片, read before moving on.
            if justSubmitted, nodeDone, let node {
                PlayTaskRightSection(passText: node.passText, fragment: node.fragmentText)
            }
            // Also shown at the top: the answer row can sit under the keyboard.
            if let refusal { Section { PlayReviewRefusalRow(refusal: refusal, identifier: "playx.review.refusal") } }
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
            // WP-02: the original-run guard appeal for this stop (kept across visits by owner and session).
            PlayGuardAppealSection(scope: model.scope, nodeID: nodeID,
                                   reference: model.arrivalFailure?.nodeID == nodeID ? model.arrivalFailure?.guardReference : nil)
            if let reading = model.arrivalReading, model.reward?["nodeId"].tolerantInteger == nodeID {
                PlayArrivalReadingSection(reading: reading)
            }
            if let dispatched = activeDispatchedTask {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYStatusChip(
                            verbatim: CoreLoopCopy(locale: locale).t("今日盲盒任务", "Today's Mystery Task"),
                            tone: .info,
                            systemImage: "shippingbox.fill"
                        )
                        Text(verbatim: dispatched.displayName)
                            .cyText(.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                        if let rule = dispatched.playerRuleInstructions {
                            Text(verbatim: rule)
                                .font(CYTypography.bodyCompact)
                                .foregroundStyle(palette.textSecondary)
                        }
                        if dispatched.nodeID != nodeID, let openNode {
                            Button(CoreLoopCopy(locale: locale).t("前往盲盒任务", "Open Mystery Task")) {
                                openNode(dispatched.nodeID)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("playx.random.openDispatched")
                        }
                    }
                    .accessibilityIdentifier("playx.random.dispatchedTask")
                }
            }
            if let node {
                nodeSections(node: node, context: context)
            } else {
                Text("playx.node.unavailable")
            }
        }
    }

    private func nodeWithConfirms(context: PlayInteractionContext?) -> some View {
        nodeWithOutcomes(context: context)
            .modifier(PlaySystemConfirm(
                isPresented: showReview,
                title: appLocalized("playx.review", locale: .current),
                message: appLocalized("playx.review.detail", locale: .current),
                cancelTitle: appLocalized("playx.cancel", locale: .current),
                confirmTitle: appLocalized("playx.submit", locale: .current),
                confirmIdentifier: "playx.confirm",
                onCancel: { showReview = false; model.cancelReview(); review = nil },
                onConfirm: {
                    showReview = false
                    guard let review else { return }
                    self.review = nil // Consume before adaptive dismissal
                    Task { await model.submit(review) }
                }
            ))
            .onChange(of: showReview) { _, visible in
                // A popover's outside-tap dismissal has no visible Cancel button.
                if !visible, review != nil { model.cancelReview(); review = nil }
            }
            .modifier(PlaySystemConfirm(
                isPresented: showHint,
                title: appLocalized("playx.hints.request", locale: .current),
                message: appLocalized("playx.hints.consequence", locale: .current),
                cancelTitle: appLocalized("playx.cancel", locale: .current),
                confirmTitle: appLocalized("playx.hints.confirm", locale: .current),
                confirmIdentifier: "playx.hints.confirm",
                onCancel: { showHint = false },
                onConfirm: {
                    showHint = false
                    let context = hintContext, level = hintLevel
                    hintContext = nil
                    Task { await model.requestHint(nodeID: nodeID, level: level, context: context) }
                }
            ))
    }

    private func nodeWithOutcomes(context: PlayInteractionContext?) -> some View {
        nodeList(context: context)
            .privacySensitive()
            .navigationTitle("playx.task.title")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: outcomeState) { old, new in
                // Only this screen's own submission produces a verdict; a later read never replays one.
                guard old == .submitting else { return }
                if new == .completed {
                    if let node {
                        let task = PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node)
                        if task == .arrive || task == .scan {
                            UIKitHapticsDriver.ensureInstalled()
                            HapticsService.shared.play(.checkInSuccess)
                        }
                    }
                    // In place (xrefs-1 C2 / owner continuity pass): the submit button morphs to Done and the task card
                    // above updates where it is; no full-screen verdict for an ordinary stop.
                    justSubmitted = true
                    if NativeR2Flags.storyFlow { nr2Result = NR2StageResultTarget(nodeID: nodeID) }
                } else if new == .pending || new == .failed, case .rejected(_, let message)? = model.issue {
                    UIKitHapticsDriver.ensureInstalled()
                    HapticsService.shared.play(.wrongAnswer)
                    // The answer was not accepted: the button returns to its label and the reason stays beside it.
                    rejectionText = message
                }
            }
            .onChange(of: model.reward) { _, reward in
                guard let reward, reward["nodeId"].tolerantInteger == nodeID else { return }
                if let drop = PlayRewardDrop.fromReward(reward) {
                    nodeToastMessage = drop.toastMessage(locale: locale)
                } else if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                    nodeToastMessage = dispatched.revealTitle(locale: locale)
                }
            }
            .cyPlayVerdict($verdict)
            .cySheet(item: $nr2Result) { target in
                NR2StageResultSheet(model: model, nodeID: target.nodeID, openNode: openNode)
                    .nativeR2SheetBackdropSource()
            }
            .nativeR2SheetBackdrop(isPresented: nr2Result != nil)
            .modifier(JourneyCheckReviewPresentation(model: journey))
            // The optional check initially renders no rows, so its probe belongs to this stable host.
            .task(id: [model.identity, node.map { String($0.id) }, (model.snapshot?.route?.sessionID).map(String.init), (model.snapshot?.route?.version).map(String.init)]) {
                if let node {
                    await loadHelp(node: node)
                    if opensHelp, !helpOpenedOnce, helpEnabled { helpOpenedOnce = true; showHelpPanel = true }
                    await journey?.probe(nodeDone: model.snapshot?.isDone(node) == true)
                    guard !Task.isCancelled, self.node?.id == node.id, model.hasCurrentMediaSnapshot else { journey?.roleContent.close(); return }
                    await journey?.roleContent.load(expectedRunID: model.snapshot?.route?.sessionID, minimumStateVersion: model.snapshot?.route?.version)
                } else { journey?.roleContent.close() }
            }
            .onChange(of: nodeDone) { _, done in
                if node != nil { journey?.updateNodeDone(done) }
            }
    }

    @ViewBuilder
    private func nodeSections(node: PlayNode, context: PlayInteractionContext?) -> some View {
        if let journey {
            if NativeR2Flags.games { ChanceJourneyCheckView(model: journey, nodeDone: nodeDone) }
            else { PlayJourneyCheckView(model: journey, nodeDone: nodeDone) }
        }
        else { PlayCheckRuntimeSection(nodeID: node.id, routeSessionID: model.snapshot?.route?.sessionID, nodeDone: nodeDone) }
        if let narrative, model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false {
            NavigationLink("journey.record.questions") {
                JourneyNarrativeView(model: narrative, onChanged: { await model.load() })
            }.accessibilityIdentifier("journey.record.open.questions.\(nodeID)")
        }
        nodeBriefSection(node: node, context: context)
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
        nodeAnswerSection(node: node, context: context)
        nodeHelpAndHintSections(node: node, context: context)
        nodeSensorAndDeviceSections(node: node, context: context)
        if let arrival, arrival.offer(for: node.id) != nil {
            Section { PlayArrivalControl(arrival: arrival, nodeID: node.id, context: context) }
        }
        if let card = model.aiScores[node.id] { PlayAIScoreSection(card: card) }
    }

    @ViewBuilder
    private func nodeAnswerSection(node: PlayNode, context: PlayInteractionContext?) -> some View {
        if PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node) == .answer {
            Section("playx.answer") {
                if let options = node.options, node.validationMethod == 3 {
                    // N-PLAY-MAP (r10): keyed options (A / B / C) as plain List rows with a checkmark
                    // (MP pages/play/index.wxml answer options); one row per option inside the Section.
                    ForEach(options.keys.sorted(), id: \.self) { key in
                        let on = answer == key
                        Button { answer = key } label: {
                            HStack(spacing: CYSpacing.md) {
                                Text(verbatim: key).font(.headline).foregroundStyle(.secondary)
                                Text(verbatim: options[key] ?? key)
                                    .foregroundStyle(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                if on {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor).accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("playx.answer.option." + key)
                    }
                } else {
                    TextField("playx.answer.placeholder", text: $answer, axis: .vertical)
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("playx.answer.field")
                }
                // F-05: a done, locked or not-yet-ready stop says why and keeps its submit disabled.
                let blocker = model.reviewRefusal(nodeID: nodeID)
                if answerPhase == .idle, let shown = refusal ?? blocker, shown != .busy { PlayReviewRefusalRow(refusal: shown) }
                if answerPhase == .idle, let rejectionText {
                    Label { Text(verbatim: rejectionText).fixedSize(horizontal: false, vertical: true) } icon: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(palette.danger).accessibilityHidden(true)
                    }
                    .font(CYTypography.bodyCompact).foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("playx.answer.rejected")
                }
                // In place: 提交 → 正在提交 → 已完成 in the same capsule (`CYResultButton`).
                CYResultButton("playx.review", loading: "playx.phase.submitting", done: "playx.completed",
                               systemImage: "checkmark.circle.fill", phase: answerPhase) {
                    rejectionText = nil
                    prepare(.answer(answer), context: context)
                }
                .identifier("playx.answer.review")
                .disabled(answerPhase == .idle && (!model.canWrite || (blocker != nil && blocker != .busy) || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
    }

    @ViewBuilder
    private func nodeHelpAndHintSections(node: PlayNode, context: PlayInteractionContext?) -> some View {
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
            legacyHintSection(extra: extra, context: context)
        }
        if !helpEnabled, let hint = model.hint {
            Section("playx.hints") {
                ForEach(Array(hint.hints.enumerated()), id: \.offset) { _, text in
                    Text(verbatim: text)
                }
            }
        }
    }

    @ViewBuilder
    private func nodeSensorAndDeviceSections(node: PlayNode, context: PlayInteractionContext?) -> some View {
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
        if node.sensorType == "audio_clip",
           let audioConfig = try? PlayAudioClipConfiguration(raw: model.extras[nodeID]?.sensorConfig ?? .null) {
            NavigationLink("playx.audioClip.title") {
                PlayInteractionBoundContent(context: model.interactionContext) { issuedContext in
                    PlayAudioClipStreamView(
                        configuration: audioConfig,
                        canWrite: model.canWrite,
                        uploadAudio: { bytes, mime in
                            try await model.uploadAudio(bytes, mimeType: mime)
                        },
                        onSubmit: { payload in
                            prepare(.sensor(type: "audio_clip", payload: payload), context: issuedContext)
                        }
                    )
                }
            }
            .accessibilityIdentifier("playx.audioClip.open")
        }
        if let advanced, node.hasAdvancedPrerequisite {
            NavigationLink("playx.advanced") {
                PlayInteractionBoundContent(context: model.interactionContext) { advancedContext in
                    PlayAdvancedView(model: advanced, device: device, mediaScope: mediaScope, makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                                      stationQuestion: node.question, stationName: node.name, stationPassText: node.passText) { state in
                        try? model.acceptAdvanced(state, context: advancedContext)
                    }
                }
            }
        }
        let resolvedTask = PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node)
        let arrivalReplacesDevice = arrival?.offer(for: node.id) != nil && (resolvedTask == .arrive || resolvedTask == .merchantScan)
        if let device, !arrivalReplacesDevice { PlayDeviceTaskSection(model: device, task: resolvedTask,
            photoFilter: node.sensorType == "filter_shot" ? PlayPhotoFilter(rawValue: model.extras[nodeID]?.sensorConfig["filterStyle"].text ?? "") : nil,
            unsupportedPhotoSubtype: node.validationMethod == 2 && node.sensorType?.isEmpty == false && (node.sensorType != "filter_shot" || PlayPhotoFilter(rawValue: model.extras[nodeID]?.sensorConfig["filterStyle"].text ?? "") == nil), interaction: .init(context: context, current: { model.interactionContext }), onEvidence: { prepare($0, context: $1) }) }
        else if !arrivalReplacesDevice, resolvedTask != .answer { Text("playx.device.disabled") }
    }
    @ViewBuilder
    private func nodeBriefCard(node: PlayNode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.sm) {
                if let snapshot = model.snapshot {
                    CYStatusChip(
                        LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: snapshot.result.mode, node: node).rawValue),
                        tone: .info,
                        systemImage: "flag.fill"
                    )
                }
                CYStatusChip(
                    verbatim: node.arrived == true
                        ? CoreLoopCopy(locale: locale).t("已到达", "Arrived")
                        : (node.needGPS == true || node.needScan == true
                            ? CoreLoopCopy(locale: locale).t("待到达", "Arrival required")
                            : CoreLoopCopy(locale: locale).t("自由打卡", "Open check-in")),
                    tone: node.arrived == true ? .success : .neutral,
                    systemImage: node.arrived == true ? "checkmark.circle.fill" : "location.fill"
                )
            }
            if let result = model.snapshot?.result {
                PlayStationArtwork(image: PlayStationImageResolver.station(for: node, in: result), title: node.name ?? "")
                    .accessibilityIdentifier("playx.station.artwork")
            }
            PlayNodeTitle(name: node.name)
                .cyText(.pageTitle)
                .foregroundStyle(palette.textPrimary)
            if model.snapshot?.isStoryLocked(node) == true {
                CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                    .accessibilityLabel(Text("playFree.story.locked.a11y"))
            } else if let body = node.storyText ?? node.description {
                Text(verbatim: body)
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let instructions = node.playerRuleInstructions {
                Text(verbatim: instructions)
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let question = node.question {
                Text(verbatim: question)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false, let image = node.questionImage, !image.isEmpty {
                PlayKitArtwork(source: image, approvedHosts: approvedArtworkHosts)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityIdentifier("playx.question.image")
            }
            if let perk = node.perk {
                if perk.included == true { Text("playx.perk.included").cyText(.bodyCompact) }
                if let spend = perk.extraSpendText, !spend.isEmpty { Text(verbatim: spend).cyText(.bodyCompact) }
                if perk.reserveRequired == true { Text("playx.perk.reserve").cyText(.bodyCompact) }
            }
            if let mode = PlayCompletionModePresentation(raw: node.completionMode) {
                Text(LocalizedStringKey(mode.titleKey)).cyText(.bodyCompact).accessibilityIdentifier("playx.completion.mode")
            }
            if model.extras[node.id]?.photoCheckMode == "RECORD" {
                Button("playkit.photo.continueWithout") {
                    if case .success(let submission) = PlayPhotoRecordSubmission.validate(mode: "RECORD", imageURL: nil, textConfirmed: true, submitPhotoCheck: false) {
                        continuedWithoutPhoto = true
                        if let advanced { Task { await PlayKitInputContract.postRecord(submission, through: advanced) } }
                    }
                }
                .cyText(.body)
                .disabled(continuedWithoutPhoto)
                .accessibilityIdentifier("playkit.photo.continueWithout")
            }
            if node.validationMethod == 2, let requirement = node.photoRequirement, !requirement.isEmpty {
                Text(verbatim: requirement)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("playx.photo.requirement")
            }
            if node.validationMethod == 4 {
                Text("playx.scan.prompt")
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("playx.scan.prompt")
            }
            if let address = node.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label {
                    Text(verbatim: address).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(palette.actionPrimaryBg).accessibilityHidden(true)
                }
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
    }

    @ViewBuilder
    private func nodeBriefSection(node: PlayNode, context: PlayInteractionContext?) -> some View {
        Section {
            nodeBriefCard(node: node)
            PlatformChapterAudioHost(selection: PlatformChapterAudioSelection.resolve(snapshot: model.snapshot, nodeID: nodeID, extras: model.extras, currentRead: model.hasCurrentMediaSnapshot), scope: mediaScope, makeModel: makeAudio)
            if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false {
                if let audio = node.questionAudio, !audio.isEmpty { PlatformAudioHost(rawURL: audio, scope: mediaScope, makeModel: makeAudio) }
                PlatformExternalMapHost(destination: .init(name: node.name ?? "#\(node.id)", address: node.address, latitude: node.latitude, longitude: node.longitude), scope: mediaScope, makeModel: makeExternalMaps)
            }
            if let snapshot = model.snapshot {
                CYTaskStatusCard(
                    title: node.name ?? "#\(node.id)",
                    state: PlayTaskStatusCardMapper.state(
                        node: node,
                        snapshot: snapshot,
                        model: model,
                        locale: locale,
                        ctaTitle: appLocalized("playx.review", locale: locale),
                        onOpen: {
                            // An empty or refused answer surfaces its reason through prepare.
                            if PlayNodeTask.resolve(mode: snapshot.result.mode, node: node) == .answer {
                                prepare(.answer(answer), context: context)
                            }
                        },
                        onRefresh: { Task { await model.load() } }
                    )
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                PlayTaskStatusBadge(node: node, snapshot: snapshot)
            }
        }
    }

    @ViewBuilder
    private func legacyHintSection(extra: PlayNodeExtras, context: PlayInteractionContext?) -> some View {
        let nextLevel = min(2, (extra.puzzleHintLevel ?? 0) + 1)
        Section("playx.hints") {
            if let cost = extra.hintCost { LabeledContent("playx.hints.cost") { Text(verbatim: String(cost)) } }
            ForEach(Array(extra.usedHints.enumerated()), id: \.offset) { _, text in Text(verbatim: text).font(CYTypography.meta).foregroundStyle(.secondary) }
            if let cap = extra.puzzleScoreCap {
                Text("playx.hints.capLine \(cap)").font(CYTypography.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("playx.hints.cap")
            }
            Button {
                hintContext = context
                hintLevel = extra.puzzleScoring == true ? nextLevel : nil
                showHint = true
            } label: {
                if extra.puzzleScoring == true { Text("playx.hints.requestLevel \(nextLevel)") }
                else { Text("playx.hints.request") }
            }
            .disabled(!model.canWrite || (extra.puzzleScoring != true && extra.hintCost == nil))
            .accessibilityIdentifier("playx.hints.request")
        }
    }

    /// One read when an unfinished stop opens. A failed read keeps the legacy hint entries.
    private func loadHelp(node: PlayNode) async {
        let done = model.snapshot?.isDone(node) == true
        guard !done, model.snapshot?.isLocked(node) == false, let client = model.helpClient(nodeID: node.id) else {
            if help?.identity.nodeID != node.id || done { help = nil; showHelpPanel = false }
            return
        }
        if teamPool?.nodeID != Int64(node.id) {
            teamPool = makeTeamPool?(node.id)
            teamPool?.onPoolUpdated = { updated in
                if updated.solvedNodeIds?.contains(Int64(node.id)) == true {
                    Task { await model.load() }
                }
            }
        }
        if let help, help.identity == client.identity, help.loaded { await teamPool?.load(); return }
        let next = PlayHelpLadderModel(client: client, store: PlayHelpDefaultsRequestStore.shared)
        help = next
        await next.load()
        await teamPool?.load()
    }
    private var outcomeState: PlayTaskOutcomePresentation.State {
        PlayTaskOutcomePresentation(snapshot: model.snapshot, nodeID: nodeID, phase: model.phase.rawValue,
                                    isCurrentRead: model.hasCurrentMediaSnapshot, unresolved: model.unresolved).state
    }
    private func stateRow(_ key: String, done: Bool) -> some View { Label(LocalizedStringKey(key), systemImage: done ? "checkmark.circle.fill" : "circle") }
    private func prepare(_ evidence: PlayCompletionEvidence, context: PlayInteractionContext?) {
        do { review = try model.review(nodeID: nodeID, evidence: evidence, context: context); showReview = true; refusal = nil }
        catch {
            // F-05: a refused review always shows its reason (inline and as a toast); nothing was sent.
            let reason = model.reviewRefusal(nodeID: nodeID, evidence: evidence) ?? PlayReviewRefusal(error: error)
            refusal = reason
            nodeToastMessage = PlayReviewRefusalRow.text(reason, locale: locale)
        }
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
                    Label { Text("playCompat.unsupported.title", tableName: "PlayFullStory").cyText(.cardTitle) }
                        icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CYColor.warningText) }
                    Text("playCompat.unsupported.body", tableName: "PlayFullStory").cyText(.body)
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

/// F-05: the reason a stop's submit was refused or is unavailable, beside the submit button.
struct PlayReviewRefusalRow: View {
    let refusal: PlayReviewRefusal
    var identifier = "playx.answer.refusal"
    var body: some View {
        Label {
            Text(LocalizedStringKey(refusal.messageKey), tableName: PlayReviewRefusal.table)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: refusal == .completed ? "checkmark.circle.fill" : "exclamationmark.circle")
        }
        .font(CYTypography.bodyCompact)
        .foregroundStyle(refusal == .completed ? CYColor.successText : CYColor.warningText)
        .accessibilityIdentifier(identifier)
    }
    static func text(_ refusal: PlayReviewRefusal, locale: Locale) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: refusal.messageKey),
                                                  table: PlayReviewRefusal.table, locale: locale))
    }
}
struct PlayExperienceIssueView: View {
    let issue: PlayExperienceError
    static func showsReference(_ issue: PlayExperienceError) -> Bool {
        switch issue {
        case .unknownResult, .malformed, .rejected: return true
        default: return false
        }
    }
    var body: some View {
        VStack(alignment: .leading) {
            if case .rejected(let code, let message) = issue {
                Label("playx.rejected", systemImage: "exclamationmark.circle").cyText(.cardTitle)
                Text(verbatim: message ?? String(code)).fixedSize(horizontal: false, vertical: true)
            } else { Text(LocalizedStringKey(issue == .disabled ? "playx.disabled" : issue == .staleSession ? "playx.session.changed" : issue == .unsupported ? "playx.unsupported" : "playx.error")) }
            // OWN-OPT-072: unknown result or server error carries the server request reference for support.
            if Self.showsReference(issue), let row = RequestReferenceRow(pathFragment: "/api/play/") { row }
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
            if let mode = PlayCompletionModePresentation(raw: reward["completionMode"].text) {
                LabeledContent("play.completionMode") { Text(LocalizedStringKey(mode.titleKey)) }
            }
            if let drop = PlayRewardDrop.fromReward(reward) {
                LabeledContent {
                    Text(verbatim: drop.detailText(locale: locale))
                } label: {
                    CYStatusChip(
                        verbatim: CoreLoopCopy(locale: locale).t("随机掉落", "Bonus Drop"),
                        tone: .success,
                        systemImage: "sparkles"
                    )
                }
                .accessibilityIdentifier("playx.reward.drop")
            }
            if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                LabeledContent {
                    Text(verbatim: dispatched.displayName)
                } label: {
                    CYStatusChip(
                        verbatim: CoreLoopCopy(locale: locale).t("今日盲盒任务", "Mystery Task"),
                        tone: .info,
                        systemImage: "shippingbox.fill"
                    )
                }
                .accessibilityIdentifier("playx.reward.dispatchedTask")
            }
            if let medal = reward["medalName"].text { Text(verbatim: medal) }
            PlayRewardBadgeRows(targets: PlayRewardBadgeTarget.targets(in: reward), destination: collectionDestination)
                .id(PlayRewardBadgeTarget.targets(in: reward))
        }.accessibilityIdentifier("playx.reward")
    }
    /// Medals carried by the reward receipt: the topic medal name plus each new badge. Nothing is invented.
    static func medals(in reward: PlayWireValue, locale: Locale) -> [CYMedalItem] {
        var items: [CYMedalItem] = []
        if let medal = reward["medalName"].text, !medal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(.init(id: "topic-medal", name: medal, imageURL: reward["medalImg"].text ?? reward["medalImage"].text, systemImage: "rosette", mpDefault: .trophy))
        }
        for target in PlayRewardBadgeTarget.targets(in: reward) {
            items.append(.init(id: "badge-" + target.code, name: target.name ?? appLocalized("medalDeck.unnamed", locale: locale), systemImage: "seal.fill", mpDefault: .glassBadge))
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
    @Environment(\.playerGapService) private var gapService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let context = model.interactionContext
        Section("playx.lead.title") {
            Button("playx.lead.load") { Task { await model.loadLead(context: context) } }.accessibilityIdentifier("playx.lead.load")
            if let lead = model.lead {
                if !lead.exists { Text("playx.lead.notStarted") }
                if let broadcast = lead.broadcast { Text(verbatim: broadcast) }
                if let chapter = lead.chapterName { Text(verbatim: chapter) }
                // mp-journey r3 (MP pages/play/index.wxml P1 集合屏, `lead.status == 1`): 队伍集合中, the arrived count as
                // the one number (P1), 已到集合点, then 已签到 for me and 等队长开始行程… for members.
                let gathering = lead.exists && lead.status == 1
                if gathering {
                    VStack(spacing: CYSpacing.xs) {
                        // MP P-13 `lg-wait`: three dots breathing in turn while the team gathers; still under Reduce Motion.
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                            .accessibilityHidden(true)
                        Text("playx.lead.gathering").font(.subheadline).foregroundStyle(.secondary)
                        (Text(verbatim: "\(lead.arrived ?? 0)").cyText(.dataXL)
                            + Text(verbatim: "/\(lead.members.count)").font(.title3).foregroundStyle(.secondary))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("playerGap.lead.arrived").font(.footnote).foregroundStyle(.secondary)
                        if lead.meArrived {
                            Label("playx.lead.checkedIn", systemImage: "checkmark").font(.subheadline.weight(.semibold))
                                .foregroundStyle(CYColor.successText)
                        }
                        if !lead.isLeader { Text("playx.lead.waitLeader").font(.footnote).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CYSpacing.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("playx.lead.gather")
                }
                if !gathering, let arrived = lead.arrived, !lead.members.isEmpty { LabeledContent("playx.lead.arrived") { Text(verbatim: "\(arrived) / \(lead.members.count)").accessibilityLabel(Text("a11y.value.ofTotal \(Int(arrived)) \(Int(lead.members.count))")) } }
                ForEach(lead.members) { member in
                    Label { if let name = member.name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.player.unnamed") } }
                        icon: { Image(systemName: member.arrived ? "checkmark.circle.fill" : "circle").foregroundStyle(member.arrived ? CYColor.successText : CYColor.textTertiary) }
                }
                if gapService != nil, case .activity(let activityID) = model.scope, lead.exists, !lead.isLeader {
                    // leadArrive (one approved GCJ-02 fix) and the member broadcast; leader tools stay hidden.
                    LeadMemberActionsSection(activityID: activityID, meArrived: lead.meArrived,
                                             reload: { Task { await model.loadLead(context: context) } })
                } else if lead.exists && !lead.meArrived { actionButton(context: context, .arrive) }
                if lead.isLeader {
                    if lead.exists, case .activity(let activityID) = model.scope {
                        LeadMemberTicketScanButton(activityID: activityID)
                        // PLAY-8: MP 展示整团码 (`leadShowGroupCode` → scene qr-group-code for this activity). The club
                        // group-code page issues and shows it; its own access check covers a leader without club rights.
                        NavigationLink {
                            MPReviewedPageScreen(page: "pages/club/group-code/index", query: ["activityId": String(activityID)])
                                .cyPushedChrome()
                        } label: {
                            Label("playTools.lead.showGroupCode", systemImage: "qrcode")
                        }
                        .accessibilityIdentifier("playx.lead.showGroupCode")
                    }
                    TextField("playx.lead.text", text: $text, axis: .vertical).accessibilityIdentifier("playx.lead.text")
                    if !lead.exists { actionButton(context: context, .start) }
                    else {
                        actionButton(context: context, .broadcast)
                        PlayLeadChapterTools(model: model, lead: lead, context: context)
                        actionButton(context: context, .settle)
                    }
                }
                if model.leaderOutcomeUnknown { Text("playx.lead.unknown") }
                if model.leadReadFailed { PlayRuntimePhaseText(phase: "failed") }
            }
            if case .activity(let activityID) = model.scope {
                TeamTrailSection(activityID: activityID, done: { [model] in
                    guard let snapshot = model.snapshot else { return 0 }
                    return snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
                })
            }
        }
        .modifier(PlaySystemConfirm(
            isPresented: review,
            title: appLocalized("playx.review", locale: .current),
            message: appLocalized(String.LocalizationValue(stringLiteral: action == .settle ? "playx.lead.settle.consequence" : "playx.lead.review"), locale: .current),
            cancelTitle: appLocalized("playx.cancel", locale: .current),
            confirmTitle: appLocalized("playx.submit", locale: .current),
            onCancel: { review = false; actionContext = nil },
            onConfirm: {
                review = false
                if let action {
                    let context = actionContext, message = action == .broadcast ? text : nil
                    actionContext = nil
                    Task { await model.performLead(action, text: message, context: context) }
                }
            }
        ))
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

struct PlayStageSettlementTarget: Identifiable, Equatable {
    let chapterID: Int
    var id: Int { chapterID }
}

/// Cast mounts (W1) split out of `PlayExperienceView.body` so the modifier chain type-checks in time.
private struct PlayExperienceCastMounts: ViewModifier {
    let host: PlayExperienceView
    func body(content: Content) -> some View {
        host.castMounts(content)
    }
}

extension PlayExperienceView {
    @ViewBuilder fileprivate func castMounts<C: View>(_ content: C) -> some View {
        content
            .onAppear { adoptCast() }
            .onChange(of: model.castPayload) { _, _ in adoptCast() }
            .onChange(of: model.snapshot?.route?.sessionID) { old, new in
                if old != new { castPlaybillSeen = false }
                adoptCast()
            }
            .onChange(of: castOpeningStep) { _, step in castCover = step != nil }
            .cyFullScreenCover(isPresented: $castCover) {
                if let config = castModel?.config {
                    CastOpeningFlow(config: config, profile: castModel?.profile, routeName: model.snapshot?.result.topicName,
                                    suggestedName: castModel?.profile?.name ?? "", initial: castOpeningStep ?? .playbill,
                                    save: { name, identity in Task { await castModel?.saveProfile(name: name, identityKey: identity) } },
                                    finish: { castPlaybillSeen = true; castCover = false })
                }
            }
            .cySheet(isPresented: $showingCastRoster) {
                if let config = castModel?.config {
                    NavigationStack {
                        CastPlaybillView(config: config, profile: castModel?.profile, routeName: model.snapshot?.result.topicName, start: { showingCastRoster = false })
                    }
                }
            }
    }
}

/// PLAY-2: MP pages/play story map (wxml:102, 145): the route's stops and dashed order line drawn as the play
/// screen's ground, with no chrome. Read-only and not interactive (the full route map stays one push away);
/// it shows only what PlayRouteMapPresentation already exposes (no story, answers or player position).
/// A route without coordinates keeps the placeholder ground.
@MainActor private struct PlayStoryMapGround: View {
    let snapshot: PlaySnapshot?
    var body: some View {
        if let snapshot, let presentation = PlayRouteMapPresentation(snapshot: snapshot), !presentation.mappedStops.isEmpty {
            let points = presentation.mappedStops.compactMap(\.coordinate).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            Map(initialPosition: .region(CYMapRegion.boundingRegion(coordinates: points)), interactionModes: []) {
                ForEach(presentation.segments) { segment in
                    MapPolyline(coordinates: [
                        CLLocationCoordinate2D(latitude: segment.start.latitude, longitude: segment.start.longitude),
                        CLLocationCoordinate2D(latitude: segment.end.latitude, longitude: segment.end.longitude),
                    ])
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                }
                ForEach(presentation.mappedStops) { stop in
                    if let location = stop.coordinate {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                            Image(systemName: stop.state.symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(stop.state == .current ? CYColor.textOnAccent : Color.primary)
                                .padding(6)
                                .background(stop.state == .current ? CYColor.actionPrimaryBg : Color(uiColor: .systemBackground), in: Circle())
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .background { CYMapPlaceholder(fog: false) }
            // Decorative ground: the stop list in the panel carries the same facts for VoiceOver.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .id(presentation.mappedStops.map(\.id))
        } else {
            CYMapPlaceholder()
        }
    }
}

/// N-r11-1: the system `.alert` in place of the custom overlay confirm (MP pages/play uses wx.showModal).
/// The alert closes only through its two buttons, and each callback clears the presenting flag itself.
private struct PlaySystemConfirm: ViewModifier {
    let isPresented: Bool
    let title: String
    var message: String = ""
    var cancelTitle: String = "取消"
    var confirmTitle: String = "确认"
    var isDestructive: Bool = false
    var confirmIdentifier: String? = nil
    let onCancel: () -> Void
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert(Text(verbatim: title), isPresented: Binding(get: { isPresented }, set: { _ in })) {
            Button(role: .cancel, action: onCancel) { Text(verbatim: cancelTitle) }
            Button(role: isDestructive ? .destructive : nil, action: onConfirm) { Text(verbatim: confirmTitle) }
                .accessibilityIdentifier(confirmIdentifier ?? "playx.alert.confirm")
        } message: {
            Text(verbatim: message)
        }
    }
}

/// mp-journey r3: MP `.nighthint` 夜深了，注意安全 — one quiet capsule at the result moment, never blocking, gone after
/// 4.6 s. VoiceOver hears it once.
private struct PlayNightHintOverlay: ViewModifier {
    let receipt: PlayWireValue?
    @State private var shown = false
    @State private var token = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if shown {
                    Text("playx.nightHint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: .capsule)
                        .padding(.top, 12)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("playx.nightHint")
                }
            }
            .onChange(of: receipt) { _, value in
                guard PlayNightWarning.isOn(value) else { return }
                token += 1
                let current = token
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { shown = true }
                AccessibilityNotification.Announcement(appLocalized("playx.nightHint", locale: .current)).post()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(PlayNightWarning.displaySeconds))
                    guard current == token else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { shown = false }
                }
            }
    }
}

/// mp-journey r3: MP `.flyscore` — `+N 探索值` rises once at the completion moment and is gone after the celebrate beat.
/// Never blocks; VoiceOver hears it once; Reduce Motion shows it in place.
private struct PlayFlyScoreOverlay: ViewModifier {
    let receipt: PlayWireValue?
    @State private var points: Int?
    @State private var token = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if let points {
                    Text("playx.flyScore \(points)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: .capsule)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("playx.flyScore")
                }
            }
            .onChange(of: receipt) { _, value in
                guard let gained = PlayFlyScore.points(value) else { return }
                token += 1
                let current = token
                withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { points = gained }
                AccessibilityNotification.Announcement(appLocalized("playx.flyScore \(gained)", locale: .current)).post()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(PlayFlyScore.displaySeconds))
                    guard current == token else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { points = nil }
                }
            }
    }
}

/// mp-journey r3: MP `coupontoast` — 已放入卡券包 · 到店出示核销 · 点击查看 at the top for 5 s when the node just completed
/// carries a coupon; a tap opens the coupon wallet (MP `goCouponWallet`). Heavy haptic, VoiceOver hears it once.
private struct PlayCouponToastOverlay: ViewModifier {
    let receipt: PlayWireValue?
    let snapshot: PlaySnapshot?
    @State private var shown = false
    @State private var token = 0
    @State private var openWallet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if shown {
                    Button {
                        shown = false
                        openWallet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "ticket.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("playx.coupon.title").font(.headline)
                                Text("playx.coupon.detail").font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("playx.coupon.toast")
                }
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: token)
            .navigationDestination(isPresented: $openWallet) {
                MPParityDestination(route: .screen(page: "subpackageMember/coupon-wallet/index", query: [:]))
            }
            .onChange(of: receipt) { _, value in
                guard PlayCouponToast.shows(receipt: value, snapshot: snapshot) else { return }
                token += 1
                let current = token
                withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { shown = true }
                AccessibilityNotification.Announcement(appLocalized("playx.coupon.title", locale: .current)).post()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(PlayCouponToast.displaySeconds))
                    guard current == token else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { shown = false }
                }
            }
    }
}

/// mp-journey r3: MP task page (p03) 答对 block — a check with the author's pass text (or 对了), then 碎片.
private struct PlayTaskRightSection: View {
    let passText: String?
    let fragment: String?

    var body: some View {
        Section {
            Label {
                if let passText, !passText.isEmpty { Text(verbatim: passText) } else { Text("playx.right.default") }
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .font(.headline)
            if let fragment, !fragment.isEmpty {
                LabeledContent {
                    Text(verbatim: fragment).multilineTextAlignment(.trailing)
                } label: {
                    Text("playx.right.fragment")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("playx.right")
    }
}


/// Start / resume taps land with a medium impact, pause with a light one; typed and split out so the play body
/// type-checks in time. A restored paused record (idle → paused) stays silent because `running` never rose.
private struct PlayClockHaptics: ViewModifier {
    let running: Bool
    let paused: Bool
    @State private var wasRunning = false
    func body(content: Content) -> some View {
        content
            .cyHaptic(.impactMedium, trigger: running, where: Self.rose)
            .cyHaptic(.impactLight, trigger: paused, where: pausedFromRun)
            .onChange(of: running) { _, now in if now { wasRunning = true } }
    }
    private static func rose(_ old: Bool, _ new: Bool) -> Bool { !old && new }
    private func pausedFromRun(_ old: Bool, _ new: Bool) -> Bool { !old && new && wasRunning }
}
